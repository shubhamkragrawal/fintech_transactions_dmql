CREATE SCHEMA IF NOT EXISTS dmql_base;

-- 1. No dependencies, create first
CREATE TABLE dmql_base.DimProductCategory (
    ProductCategoryID   INT           PRIMARY KEY,
    ProductCategoryName VARCHAR(50)   NOT NULL,
    ingested_at         TIMESTAMP
);

-- 2. Depends on DimProductCategory
CREATE TABLE dmql_base.DimProductSubCategory (
    ProductSubCategoryID   INT         PRIMARY KEY,
    ProductCategoryID      INT         REFERENCES dmql_base.DimProductCategory(ProductCategoryID),
    ProductSubCategoryName VARCHAR(50) NOT NULL,
    ingested_at            TIMESTAMP
);

-- 3. Depends on DimProductSubCategory
CREATE TABLE dmql_base.DimProduct (
    ProductID            INT          PRIMARY KEY,
    ProductSubCategoryID INT          REFERENCES dmql_base.DimProductSubCategory(ProductSubCategoryID),
    ProductName          VARCHAR(100) NOT NULL,
    ingested_at          TIMESTAMP
);

-- 4. No dependencies
CREATE TABLE dmql_base.DimCustomer (
    CustomerID  INT          PRIMARY KEY,
    FullName    VARCHAR(255) NOT NULL,
    DOB         DATE,
    Gender      VARCHAR(50),
    Region      VARCHAR(100),
    Email       VARCHAR(255),
    Status      VARCHAR(50),
    JoinDate    DATE,
    ingested_at TIMESTAMP
);

-- 5. No dependencies
CREATE TABLE dmql_base.DimCustomerUSA (
    CustomerID  INT          PRIMARY KEY,
    FullName    VARCHAR(255) NOT NULL,
    DOB         DATE,
    Gender      VARCHAR(50),
    Region      VARCHAR(100),
    Email       VARCHAR(255),
    Status      VARCHAR(50),
    JoinDate    DATE,
    ingested_at TIMESTAMP
);

-- 6. Depends on DimCustomer
CREATE TABLE dmql_base.DimAccount (
    AccountID      INT            PRIMARY KEY,
    CustomerID     INT            REFERENCES dmql_base.DimCustomer(CustomerID),
    AccountType    VARCHAR(50),
    OpenDate       DATE,
    ClosedDate     DATE,
    Status         VARCHAR(20),
    RegistrationID INT,
    Balance        DECIMAL(15,2),
    ingested_at    TIMESTAMP
);

-- 7. Depends on DimAccount and DimProduct
CREATE TABLE dmql_base.FactTransaction (
    TransactionID      INT            PRIMARY KEY,
    AccountID          INT            REFERENCES dmql_base.DimAccount(AccountID),
    TransactionDate    DATE,
    TransactionAmount  DECIMAL(15,2),
    TransactionType    VARCHAR(20),
    TransactionChannel VARCHAR(20),
    ProductID          INT            REFERENCES dmql_base.DimProduct(ProductID),
    Status             VARCHAR(20),
    ingested_at        TIMESTAMP
);