
IF EXISTS (SELECT * FROM sys.objects WHERE OBJECT_ID = OBJECT_ID('SSRS.ReportQueries') AND [Type] = 'V')
  DROP VIEW SSRS.ReportQueries;
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER OFF;
GO
--***************************************************************************************************************************************************
--* Name         : SSRS.ReportQueries
--* Purpose      : Display All Report Datasets, Datasources, and Queries
--* Applications : SSRS
--* Created Date : 07/03/2013
--* Created By   : JordanS
--***************************************************************************************************************************************************
--* Edited By    | Date     | WorkOrder   | Reason
--*--------------+----------+-------------+----------------------------------------------------------------------------------------------------------
--* JordanS      | 09/09/14 |             | Reformatted; moved to SSRS schema and renamed
--***************************************************************************************************************************************************

CREATE VIEW SSRS.ReportQueries

AS

WITH RDL_CTE AS 
(
  SELECT [Path], 
         [Name] AS ReportName,
         CONVERT(XML,CONVERT(VARBINARY(MAX),Content)) AS RDL
    FROM ReportServer.dbo.[Catalog] WITH (NOLOCK)
)
SELECT LEFT(CTE.[Path],LEN(CTE.[Path])-CHARINDEX('/',REVERSE(CTE.[Path]))+1) AS ReportPath,
       CTE.ReportName,
       T1.N.value('@Name','nvarchar(128)') AS DataSetName,
       T2.N.value('(*:DataSourceName/text())[1]', 'nvarchar(128)') AS DataSourceName,
       ISNULL(T2.N.value('(*:CommandType/text())[1]', 'nvarchar(128)'), 'T-SQL') AS CommandType,
       T2.N.value('(*:CommandText/text())[1]', 'nvarchar(max)') AS CommandText
  FROM RDL_CTE AS CTE
 CROSS APPLY CTE.rdl.nodes('/*:Report/*:DataSets/*:DataSet') AS T1(N)
 CROSS APPLY T1.N.nodes('*:Query') AS T2(N);

GO
