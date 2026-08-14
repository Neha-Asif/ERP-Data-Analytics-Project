-- 1-4: OVERALL BUSINESS SUMMARY

-- 1. Total Sales Revenue
SELECT SUM(TotalSalesAmount) AS TotalSalesRevenue FROM SalesOrders;
GO

-- 2. Total Order Count
SELECT COUNT(*) AS TotalOrderCount FROM SalesOrders;
GO

-- 3. Total Customers
SELECT COUNT(DISTINCT CustomerID) AS TotalCustomers FROM SalesOrders;
GO

-- 4. Average Order Value (AOV)
SELECT AVG(TotalSalesAmount) AS AverageOrderValue FROM SalesOrders;
GO

-- 5: TOP 10 CUSTOMERS BY SPEND


-- 5. Top 10 Customers by overall spend
SELECT TOP 10
    c.CustomerName,
    c.City,
    c.Country,
    SUM(so.TotalSalesAmount) AS TotalSpend,
    COUNT(so.SalesOrderID) AS OrderCount
FROM SalesOrders so
JOIN Customers c ON so.CustomerID = c.CustomerID
GROUP BY c.CustomerName, c.City, c.Country
ORDER BY TotalSpend DESC;
GO

-- 6-7: TOP-SELLING PRODUCTS

-- 6. Top 10 Products by Total Revenue
SELECT TOP 10
    p.ProductLabel,
    p.Category,
    SUM(so.TotalSalesAmount) AS TotalRevenue
FROM SalesOrders so
JOIN Products p ON so.ProductID = p.ProductID
GROUP BY p.ProductLabel, p.Category
ORDER BY TotalRevenue DESC;
GO

-- 7. Top 10 Products by Quantity Sold
SELECT TOP 10
    p.ProductLabel,
    p.Category,
    SUM(so.Quantity) AS TotalQuantitySold
FROM SalesOrders so
JOIN Products p ON so.ProductID = p.ProductID
GROUP BY p.ProductLabel, p.Category
ORDER BY TotalQuantitySold DESC;
GO

-- 8-9: MONTHLY REVENUE TREND & YoY GROWTH


-- 8. Monthly Revenue Trend (excludes invalid future-dated orders, DateFlag = 'OK' only)
SELECT
    YEAR(OrderDate) AS OrderYear,
    MONTH(OrderDate) AS OrderMonth,
    SUM(TotalSalesAmount) AS MonthlyRevenue
FROM SalesOrders
WHERE OrderDate IS NOT NULL AND DateFlag = 'OK'
GROUP BY YEAR(OrderDate), MONTH(OrderDate)
ORDER BY OrderYear, OrderMonth;
GO

-- 9. Year-over-Year (YoY) Revenue Growth (excludes invalid future-dated orders, DateFlag = 'OK' only)
-- CAVEAT: 2024 data starts mid-year (Jul) and 2026 data is partial (through Jul only,
-- since this is the latest month in the source data) - so raw calendar-year totals
-- are NOT a fair like-for-like comparison. See Query 9b below for a fairer version
-- that compares the same 7 months (Jan-Jul) across years.
WITH YearlyRevenue AS (
    SELECT YEAR(OrderDate) AS OrderYear, SUM(TotalSalesAmount) AS Revenue
    FROM SalesOrders
    WHERE OrderDate IS NOT NULL AND DateFlag = 'OK'
    GROUP BY YEAR(OrderDate)
)
SELECT
    OrderYear,
    Revenue,
    LAG(Revenue) OVER (ORDER BY OrderYear) AS PreviousYearRevenue,
    CAST(
        (Revenue - LAG(Revenue) OVER (ORDER BY OrderYear)) * 100.0
        / NULLIF(LAG(Revenue) OVER (ORDER BY OrderYear), 0)
    AS DECIMAL(6,2)) AS YoYGrowthPercent
FROM YearlyRevenue
ORDER BY OrderYear;
GO

-- 9b. Fair Like-for-Like YoY Growth (Jan-Jul only, every year - avoids partial-year distortion)
WITH FairYearlyRevenue AS (
    SELECT YEAR(OrderDate) AS OrderYear, SUM(TotalSalesAmount) AS Revenue
    FROM SalesOrders
    WHERE OrderDate IS NOT NULL AND DateFlag = 'OK' AND MONTH(OrderDate) BETWEEN 1 AND 7
    GROUP BY YEAR(OrderDate)
)
SELECT
    OrderYear,
    Revenue AS JanToJulRevenue,
    LAG(Revenue) OVER (ORDER BY OrderYear) AS PreviousYearJanToJulRevenue,
    CAST(
        (Revenue - LAG(Revenue) OVER (ORDER BY OrderYear)) * 100.0
        / NULLIF(LAG(Revenue) OVER (ORDER BY OrderYear), 0)
    AS DECIMAL(12,2)) AS FairYoYGrowthPercent
FROM FairYearlyRevenue
ORDER BY OrderYear;
GO


-- 10-12: SALES BREAKDOWN BY CATEGORY, CITY, COUNTRY


-- 10. Sales Breakdown by Product Category
SELECT p.Category, SUM(so.TotalSalesAmount) AS Revenue, COUNT(*) AS OrderCount
FROM SalesOrders so
JOIN Products p ON so.ProductID = p.ProductID
GROUP BY p.Category
ORDER BY Revenue DESC;
GO

-- 11. Sales Breakdown by City
SELECT c.City, SUM(so.TotalSalesAmount) AS Revenue, COUNT(*) AS OrderCount
FROM SalesOrders so
JOIN Customers c ON so.CustomerID = c.CustomerID
GROUP BY c.City
ORDER BY Revenue DESC;
GO

-- 12. Sales Breakdown by Country
SELECT c.Country, SUM(so.TotalSalesAmount) AS Revenue, COUNT(*) AS OrderCount
FROM SalesOrders so
JOIN Customers c ON so.CustomerID = c.CustomerID
GROUP BY c.Country
ORDER BY Revenue DESC;
GO

-- 13-14: SUPPLIER PERFORMANCE
-- (True on-time fulfillment rate omitted - no delivery date field exists)


-- 13. Supplier Performance - Total Purchase Value & Order Count
SELECT
    sup.SupplierName,
    COUNT(po.PurchaseOrderID) AS PurchaseOrderCount,
    SUM(po.Quantity * po.UnitPrice) AS TotalPurchaseValue
FROM PurchaseOrders po
JOIN Suppliers sup ON po.SupplierID = sup.SupplierID
GROUP BY sup.SupplierName
ORDER BY TotalPurchaseValue DESC;
GO

-- 14. Supplier Performance - Product Diversity Supplied
SELECT
    sup.SupplierName,
    COUNT(DISTINCT po.ProductID) AS DistinctProductsSupplied
FROM PurchaseOrders po
JOIN Suppliers sup ON po.SupplierID = sup.SupplierID
GROUP BY sup.SupplierName
ORDER BY DistinctProductsSupplied DESC;
GO

-- 15-16: INVENTORY VALUATION / LOW-STOCK ALERTS - NOT COMPUTABLE

-- These were tested as "Total Purchased minus Total Sold" per product, but
-- the result is structurally meaningless: the source file is a single flat
-- table where PurchaseOrders.Quantity and SalesOrders.Quantity for a given
-- ProductID are both drawn from the same underlying row/field, so the
-- subtraction returns ~0 for every product regardless of real stock levels.
-- No genuine stock-on-hand quantity or reorder-point threshold exists
-- anywhere in the source data. Rather than present a misleading number,
-- this metric is intentionally omitted and documented as a data limitation
-- in the Data Profiling Report / Executive Summary.
GO

-- 17-18: ORDER FULFILLMENT / PAYMENT STATUS BREAKDOWN


-- 17. Order Fulfillment Status Breakdown (Shipment Status)
SELECT
    ShipmentStatus,
    COUNT(*) AS OrderCount,
    CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER () AS DECIMAL(5,2)) AS PercentOfOrders
FROM Shipments
GROUP BY ShipmentStatus
ORDER BY OrderCount DESC;
GO

-- 18. Payment Status Breakdown
SELECT
    PaymentStatus,
    COUNT(*) AS OrderCount,
    CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER () AS DECIMAL(5,2)) AS PercentOfOrders
FROM Payments
GROUP BY PaymentStatus
ORDER BY OrderCount DESC;
GO

-- 19-20: RETURNS ANALYSIS


-- 19. Return Rate Percentage
-- NOTE: Source data assigns a ReturnID to ~97% of all rows regardless of
-- whether a return actually occurred (consistent with the near-universal ID
-- fill rate found across all ID columns during Task 1 profiling - no source
-- field distinguishes "returned" from "not returned"). The resulting 100%
-- figure reflects this data artifact, not real return behavior, and should
-- be reported with this caveat rather than as a literal business metric.
SELECT
    (SELECT COUNT(*) FROM Returns) AS TotalReturns,
    (SELECT COUNT(*) FROM SalesOrders) AS TotalOrders,
    CAST((SELECT COUNT(*) FROM Returns) * 100.0 / (SELECT COUNT(*) FROM SalesOrders) AS DECIMAL(5,2)) AS ReturnRatePercent;
GO

-- 20. Top Returned Product Categories
SELECT TOP 10
    p.Category,
    COUNT(*) AS ReturnCount
FROM Returns r
JOIN SalesOrders so ON r.SalesOrderID = so.SalesOrderID
JOIN Products p ON so.ProductID = p.ProductID
GROUP BY p.Category
ORDER BY ReturnCount DESC;
GO

-- 21-23: PAYMENT METHOD & EMPLOYEE PERFORMANCE


-- 21. Payment Method Distribution
SELECT
    PaymentMethod,
    COUNT(*) AS UsageCount,
    CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER () AS DECIMAL(5,2)) AS PercentOfPayments
FROM Payments
GROUP BY PaymentMethod
ORDER BY UsageCount DESC;
GO

-- 22. Employee Sales Performance (by Revenue)
SELECT TOP 10
    e.EmployeeName,
    SUM(so.TotalSalesAmount) AS TotalRevenueHandled,
    COUNT(so.SalesOrderID) AS OrdersHandled
FROM SalesOrders so
JOIN Employees e ON so.EmployeeID = e.EmployeeID
GROUP BY e.EmployeeName
ORDER BY TotalRevenueHandled DESC;
GO

-- 23. Employee Performance by Order Count
SELECT TOP 10
    e.EmployeeName,
    COUNT(so.SalesOrderID) AS OrdersHandled
FROM SalesOrders so
JOIN Employees e ON so.EmployeeID = e.EmployeeID
GROUP BY e.EmployeeName
ORDER BY OrdersHandled DESC;
GO

