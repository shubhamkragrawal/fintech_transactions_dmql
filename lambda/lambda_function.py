import boto3, json, os, subprocess, zipfile, glob

BUCKET             = os.environ['S3_BUCKET']
DATASET_OWNER      = os.environ['DATASET_OWNER']
DATASET_NAME       = os.environ['DATASET_NAME']
GLUE_JOB_NAME      = os.environ['GLUE_JOB_NAME']
GLUE_LOAD_JOB_NAME = os.environ['GLUE_LOAD_JOB_NAME']
RDS_HOST           = os.environ['RDS_HOST']
RDS_DB             = os.environ['RDS_DB']
RDS_USER           = os.environ['RDS_USER']
RDS_PASSWORD       = os.environ['RDS_PASSWORD']
REGION             = os.environ.get('AWS_REGION', 'us-east-2')
TMP_ZIP            = '/tmp/dataset.zip'
TMP_DIR            = '/tmp/extracted'

def get_kaggle_creds():
    client = boto3.client('secretsmanager', region_name=REGION)
    secret = client.get_secret_value(SecretId='kaggle/credentials')
    creds  = json.loads(secret['SecretString'])
    return creds['KAGGLE_USERNAME'], creds['KAGGLE_KEY']

def download_dataset(username, api_key):
    url = f"https://www.kaggle.com/api/v1/datasets/download/{DATASET_OWNER}/{DATASET_NAME}"
    result = subprocess.run([
        'curl', '--location', '--silent', '--show-error',
        '--user', f"{username}:{api_key}",
        '--output', TMP_ZIP, url
    ], capture_output=True, text=True)
    if result.returncode != 0:
        raise Exception(f"curl failed: {result.stderr}")
    print(f"Downloaded: {os.path.getsize(TMP_ZIP)} bytes")

def unzip_dataset():
    os.makedirs(TMP_DIR, exist_ok=True)
    with zipfile.ZipFile(TMP_ZIP, 'r') as z:
        z.extractall(TMP_DIR)
        print(f"Extracted: {z.namelist()}")

def upload_to_s3():
    s3 = boto3.client('s3')
    files = glob.glob(f"{TMP_DIR}/**/*.csv", recursive=True) + \
            glob.glob(f"{TMP_DIR}/**/*.txt", recursive=True)
    if not files:
        raise Exception("No files found after extraction")
    for filepath in files:
        filename = os.path.basename(filepath)
        s3_key   = f"raw/{DATASET_NAME}/{filename}"
        s3.upload_file(filepath, BUCKET, s3_key)
        print(f"Uploaded → s3://{BUCKET}/{s3_key}")

def trigger_transform_job():
    glue = boto3.client('glue', region_name=REGION)
    response = glue.start_job_run(
        JobName   = GLUE_JOB_NAME,
        Arguments = {
            '--SOURCE_BASE'        : f"s3://{BUCKET}/raw/{DATASET_NAME}/",
            '--TARGET_BASE'        : f"s3://{BUCKET}/cleaned/{DATASET_NAME}/",
            '--JOB_NAME'           : GLUE_JOB_NAME,
            '--GLUE_LOAD_JOB_NAME' : GLUE_LOAD_JOB_NAME,
            '--RDS_HOST'           : RDS_HOST,
            '--RDS_DB'             : RDS_DB,
            '--RDS_USER'           : RDS_USER,
            '--RDS_PASSWORD'       : RDS_PASSWORD,
        }
    )
    print(f"Transform job triggered: {response['JobRunId']}")

def lambda_handler(event, context):
    print("Step 1: Getting credentials...")
    username, api_key = get_kaggle_creds()
    print("Step 2: Downloading via curl...")
    download_dataset(username, api_key)
    print("Step 3: Unzipping...")
    unzip_dataset()
    print("Step 4: Uploading to S3...")
    upload_to_s3()
    print("Step 5: Triggering transform job...")
    trigger_transform_job()
    return {'statusCode': 200, 'body': 'Extraction done — transform job triggered'}
