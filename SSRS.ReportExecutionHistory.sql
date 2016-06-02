
IF EXISTS (SELECT * FROM sys.objects WHERE OBJECT_ID = OBJECT_ID('SSRS.ReportExecutionHistory') AND [Type] = 'V')
  DROP VIEW SSRS.ReportExecutionHistory;
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER OFF;
GO
--***************************************************************************************************************************************************
--* Name         : SSRS.ReportExecutionHistory
--* Purpose      : Show SSRS report execution history stats
--* Applications : SSRS
--* Created Date : 03/24/2015
--* Created By   : JordanS
--***************************************************************************************************************************************************
--* Edited By    | Date     | WorkOrder   | Reason
--*--------------+----------+-------------+----------------------------------------------------------------------------------------------------------
--* JordanS      | 03/24/15 |             | Initial creation
--***************************************************************************************************************************************************

CREATE VIEW SSRS.ReportExecutionHistory

AS

SELECT C.[Name] AS ReportName,
       LEFT(C.[Path],LEN(C.[Path])-CHARINDEX('/',REVERSE(C.[Path]))+1) AS ReportPath,
       EL.TimeStart, 
       EL.TimeEnd, 
       DATEADD(SS,(DATEDIFF(SS,EL.TimeStart,EL.TimeEnd)),CAST('00:00:00' AS TIME(0))) AS Duration,
       EL.[Parameters], 
       REPLACE(EL.UserName,'HERITAGECOIN\','') AS UserName,
       EL.Format AS ReportFormat,
       EL.[Status], 
       EL.TimeDataRetrieval, 
       EL.TimeProcessing, 
       EL.TimeRendering,
       CAST((EL.ByteCount/1024.0) AS DECIMAL(10,2)) AS RenderedKB,
       EL.[RowCount]
  FROM ReportServer.dbo.ExecutionLog EL
 INNER JOIN ReportServer.dbo.[Catalog] C 
    ON EL.ReportID = C.ItemID;

GO
