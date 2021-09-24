-- 32
DROP TABLE IF EXISTS WideWorldImportersDW.Dimension.CountryOfManufacture

SELECT ROW_NUMBER() OVER(ORDER BY c.CountryName) [CountryOfManufacture Key], c.CountryID [WWI CountryOfManufacture Key], c.CountryName, c.FormalName, 
	c.IsoAlpha3Code, c.IsoNumericCode, c.CountryType, c.LatestRecordedPopulation, c.Continent, c.Region, c.Subregion, c.Border
INTO WideWorldImportersDW.Dimension.CountryOfManufacture
FROM (SELECT DISTINCT JSON_VALUE(si.CustomFields, '$.CountryOfManufacture') [CountryOfManufacture]
FROM WideWorldImporters.Warehouse.StockItems si) [t1] JOIN WideWorldImporters.Application.Countries c ON t1.CountryOfManufacture = c.CountryName OR t1.CountryOfManufacture = c.IsoAlpha3Code

SELECT * FROM WideWorldImportersDW.Dimension.CountryOfManufacture

USE WideWorldImportersDW
GO

CREATE TYPE [dbo].[MemoryType] 
AS TABLE
(
	[Order Staging Key] [bigint] IDENTITY(1,1) NOT NULL PRIMARY KEY NONCLUSTERED,
	[City Key] [int] NULL,
	[Customer Key] [int] NULL,
	[Stock Item Key] [int] NULL,
	[Order Date Key] [date] NULL,
	[Picked Date Key] [date] NULL,
	[Salesperson Key] [int] NULL,
	[Picker Key] [int] NULL,
	[WWI Order ID] [int] NULL,
	[WWI Backorder ID] [int] NULL,
	[Description] [nvarchar](100) COLLATE Latin1_General_100_CI_AS NULL,
	[Package] [nvarchar](50) COLLATE Latin1_General_100_CI_AS NULL,
	[Quantity] [int] NULL,
	[Unit Price] [decimal](18, 2) NULL,
	[Tax Rate] [decimal](18, 3) NULL,
	[Total Excluding Tax] [decimal](18, 2) NULL,
	[Tax Amount] [decimal](18, 2) NULL,
	[Total Including Tax] [decimal](18, 2) NULL,
	[Lineage Key] [int] NULL,
	[WWI City ID] [int] NULL,
	[WWI Customer ID] [int] NULL,
	[WWI Stock Item ID] [int] NULL,
	[WWI Salesperson ID] [int] NULL,
	[WWI Picker ID] [int] NULL,
	[Last Modified When] [datetime2](7) NULL
)WITH (MEMORY_OPTIMIZED = ON)

CREATE PROCEDURE dbo.WWIOrderToDW
AS
	DECLARE @InMem dbo.MemoryType
	INSERT @InMem
	SELECT dwc.[City Key], dwcus.[Customer Key], dwsi.[Stock Item Key], o2.OrderDate [Order Date Key], 
		o2.ExpectedDeliveryDate [Picked Date Key], dwe.[Employee Key] [Salesperson Key], dwcus_p.[Customer Key] [Picker Key], t1.*
	FROM (SELECT o.OrderID [WWI Order ID], o.BackorderOrderID [WWI BackOrder ID], ol.Description, pt.PackageTypeName [Package], ol.Quantity, ol.UnitPrice [Unit Price],
			ol.TaxRate [Tax Rate], ol.Quantity*ol.UnitPrice [Total Excluding Tax], ol.Quantity*ol.UnitPrice*ol.TaxRate/100 [Tax Amount], 
			ol.Quantity*ol.UnitPrice*(1+ol.TaxRate/100) [Total Including Tax], 8 [Lineage Key], cus.DeliveryCityID [WWI City ID], 
			cus.CustomerID [WWI Customer ID], ol.StockItemID [WWI Stock Item ID], o.SalespersonPersonID [WWI Salesperson ID], 
		o.PickedByPersonID [WWI Picker ID], o.LastEditedWhen [Last Modified When]
		FROM WideWorldImporters.Sales.Orders o JOIN WideWorldImporters.Sales.OrderLines ol ON o.OrderID = ol.OrderID
			JOIN WideWorldImporters.Sales.Customers cus ON o.CustomerID = cus.CustomerID
			JOIN WideWorldImporters.Warehouse.PackageTypes pt ON ol.PackageTypeID = pt.PackageTypeID) [t1] 
		JOIN WideWorldImportersDW.Dimension.City dwc ON t1.[WWI City ID] = dwc.[WWI City ID]
		JOIN WideWorldImportersDW.Dimension.Customer dwcus ON t1.[WWI Customer ID] = dwcus.[WWI Customer ID]
		JOIN WideWorldImportersDW.Dimension.Customer dwcus_p ON t1.[WWI Picker ID] = dwcus_p.[WWI Customer ID]
		JOIN WideWorldImportersDW.Dimension.Employee dwe ON t1.[WWI Salesperson ID] = dwe.[WWI Employee ID]
		JOIN WideWorldImportersDW.Dimension.[Stock Item] dwsi ON t1.[WWI Stock Item ID] = dwsi.[WWI Stock Item ID]
		JOIN WideWorldImporters.Sales.Orders o2 ON t1.[WWI Order ID] = o2.OrderID
		
	DELETE FROM WideWorldImportersDW.Integration.Order_Staging
	INSERT INTO WideWorldImportersDW.Integration.Order_Staging
	SELECT [City Key], [Customer Key], [Stock Item Key], [Order Date Key], [Picked Date Key], [Salesperson Key],
		[Picker Key], [WWI Order ID], [WWI Backorder ID], Description, Package, Quantity, [Unit Price], [Tax Rate], [Total Excluding Tax], [Tax Amount],
		[Total Including Tax], [Lineage Key], [WWI City ID], [WWI Customer ID], [WWI Stock Item ID], [WWI Salesperson ID], [WWI Picker ID], [Last Modified When] 
	FROM @InMem

	INSERT INTO WideWorldImportersDW.Fact.[Order] 
	SELECT [City Key], [Customer Key], [Stock Item Key], [Order Date Key], [Picked Date Key],
		[Salesperson Key], [Picker Key], [WWI Order ID], [WWI Backorder ID], Description, Package, Quantity, [Unit Price],
		[Tax Rate], [Total Excluding Tax], [Tax Amount], [Total Including Tax], [Lineage Key]
	FROM WideWorldImportersDW.Integration.Order_Staging
GO

EXEC dbo.WWIOrderToDW
