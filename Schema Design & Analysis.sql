CREATE DATABASE inventory_project;
USE inventory_project;

CREATE TABLE IF NOT EXISTS DimProduct 
(
  ProductID VARCHAR(255) NOT NULL PRIMARY KEY,
  Category VARCHAR(255)
);

CREATE TABLE IF NOT EXISTS DimStore 
(
  StoreSK INTEGER PRIMARY KEY AUTO_INCREMENT, -- acts as the superkey
  StoreID VARCHAR(255) NOT NULL,
  Region VARCHAR(255),
  CONSTRAINT UNIQUE (StoreID, Region)
);

CREATE TABLE IF NOT EXISTS DimDate 
(
    DateKey INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    PDate DATE NOT NULL,
    PYear INT,
    PMonth INT,
    PDay INT,
    PDayOfWeek VARCHAR(10),
    Seasonality VARCHAR(50)
);

CREATE TABLE IF NOT EXISTS FactInventorySales 
(
  FactID INT NOT NULL AUTO_INCREMENT,
  PDate DATE,
  StoreID VARCHAR(255),
  Region VARCHAR(255),
  ProductID VARCHAR(255),
  StoreSK INT,
  InventoryLevel INT,
  UnitsSold INT,
  UnitsOrdered INT,
  DemandForecast DECIMAL(10,2),
  Price DECIMAL(10,2),
  Discount DECIMAL(5,2),
  EffectivePrice DECIMAL(10,2),
  WeatherCondition VARCHAR(50),
  IsHolidayPromotion TINYINT(1),
  CompetitorPricing DECIMAL(10,2),
  PRIMARY KEY (FactID),
  FOREIGN KEY (StoreSK) REFERENCES DimStore(StoreSK),
  FOREIGN KEY (ProductID) REFERENCES DimProduct(ProductID)
);

-- Populate DimProduct
INSERT INTO DimProduct (ProductID, Category)
SELECT DISTINCT TRIM(ProductID), TRIM(Category)
FROM inventory_data
ON DUPLICATE KEY UPDATE Category = VALUES(Category);

-- Populate DimStore
INSERT INTO DimStore (StoreID, Region)
SELECT DISTINCT TRIM(StoreID), TRIM(Region)
FROM inventory_data
ON DUPLICATE KEY UPDATE Region = VALUES(Region);

-- Populate DimDate
INSERT INTO DimDate (PDate, PYear, PMonth, PDay, PDayOfWeek, Seasonality)
SELECT DISTINCT
    PDate,
    YEAR(PDate),
    MONTH(PDate),
    DAY(PDate),
    DAYNAME(PDate),
    Seasonality
FROM inventory_data
ON DUPLICATE KEY UPDATE
    PYear = VALUES(PYear),
    PMonth = VALUES(PMonth),
    PDay = VALUES(PDay),
    PDayOfWeek = VALUES(PDayOfWeek),
    Seasonality = VALUES(Seasonality);

INSERT INTO FactInventorySales (
    PDate, StoreID, Region, ProductID, StoreSK, InventoryLevel, UnitsSold, 
    UnitsOrdered, DemandForecast, Price, Discount, EffectivePrice,
    WeatherCondition, IsHolidayPromotion, CompetitorPricing
)
SELECT 
    TRIM(i.PDate),
    TRIM(i.StoreID),
    TRIM(i.Region),
    TRIM(i.ProductID),
    s.StoreSK,
    i.InventoryLevel,
    i.UnitsSold,
    i.UnitsOrdered,
    i.DemandForecast,
    i.Price,
    i.Discount,
    i.Price * (1 - i.Discount/100.0) AS EffectivePrice,
    TRIM(i.WeatherCondition),
    CASE WHEN i.Holiday_Promotion = 1 THEN TRUE ELSE FALSE END,
    i.CompetitorPricing
FROM inventory_data i
JOIN DimStore s 
  ON TRIM(i.StoreID) = TRIM(s.StoreID) 
 AND TRIM(i.Region) = TRIM(s.Region);

 SELECT * FROM FactInventorySales LIMIT 20;

-- Stockout rate is calculated:

 SELECT 
    StoreID,
    COUNT(*) AS TotalDays,
    SUM(CASE WHEN InventoryLevel = 0 THEN 1 ELSE 0 END) AS StockoutDays,
    ROUND(SUM(CASE WHEN InventoryLevel = 0 THEN 1 ELSE 0 END) / COUNT(*) * 100, 2) AS StockoutRate
FROM FactInventorySales
GROUP BY StoreID;

SELECT 
    StoreID, ProductID,
    COUNT(*) AS TotalDays,
    SUM(CASE WHEN InventoryLevel = 0 THEN 1 ELSE 0 END) AS StockoutDays,
    ROUND(SUM(CASE WHEN InventoryLevel = 0 THEN 1 ELSE 0 END) / COUNT(*) * 100, 2) AS StockoutRate
FROM FactInventorySales
GROUP BY StoreID, ProductID;

-- Inventory Turnover Ratio:
SELECT 
    ProductID,
    SUM(UnitsSold) AS TotalSold,
    AVG(InventoryLevel) AS AvgInventory1,
    ROUND(SUM(UnitsSold) / NULLIF(AVG(InventoryLevel), 0), 2) AS InventoryTurnoverRatio
FROM FactInventorySales
GROUP BY ProductID;

-- Average Inventory Levels:

SELECT 
    StoreID,
    ProductID,
    ROUND(AVG(InventoryLevel), 2) AS AvgInventory
FROM FactInventorySales
GROUP BY StoreID, ProductID;

SELECT 
    ProductID,
    ROUND(AVG(UnitsSold), 2) AS AvgDailySales
FROM FactInventorySales
GROUP BY ProductID
ORDER BY AvgDailySales DESC;

-- Average

SELECT 
  ProductID,
  StoreID,
  ROUND(SUM(InventoryLevel) / NULLIF(SUM(UnitsSold), 0), 2) AS AvgInventoryAge
FROM FactInventorySales
GROUP BY ProductID, StoreID;


-- Low Inventory Detection:

SELECT 
    StoreID,
    ProductID,
    ROUND(AVG(UnitsSold) * 1.5) AS ReorderThreshold
FROM FactInventorySales
GROUP BY StoreID, ProductID;

WITH Thresholds AS (
    SELECT 
        StoreID, ProductID,
        ROUND(AVG(UnitsSold) * 1.5) AS ReorderThreshold
    FROM FactInventorySales
    GROUP BY StoreID, ProductID
)
SELECT 
    f.StoreID, f.ProductID, f.InventoryLevel, t.ReorderThreshold
FROM FactInventorySales f
JOIN Thresholds t
  ON f.StoreID = t.StoreID AND f.ProductID = t.ProductID
WHERE f.InventoryLevel < t.ReorderThreshold;

SELECT 
    d.Seasonality,
    SUM(f.UnitsSold) AS TotalUnitsSold
FROM FactInventorySales f
JOIN DimDate d ON f.PDate = d.PDate
GROUP BY d.Seasonality
ORDER BY TotalUnitsSold DESC;

SELECT 
    IsHolidayPromotion,
    ROUND(AVG(UnitsSold), 2) AS AvgUnitsSold,
    ROUND(AVG(Discount), 2) AS AvgDiscount
FROM FactInventorySales
GROUP BY IsHolidayPromotion;

SELECT 
    ProductID, PDate,
    ROUND(AVG(UnitsSold) OVER (PARTITION BY ProductID ORDER BY PDate ROWS BETWEEN 6 PRECEDING AND CURRENT ROW), 2) AS MovingAvgUnitsSold
FROM FactInventorySales;







-- 
