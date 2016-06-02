
IF EXISTS (SELECT * FROM sys.objects WHERE OBJECT_ID = OBJECT_ID('SSRS.ReportsCurrentlyRunning') AND [Type] = 'V')
  DROP VIEW SSRS.ReportsCurrentlyRunning;
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER OFF;
GO
--***************************************************************************************************************************************************
--* Name         : SSRS.ReportsCurrentlyRunning
--* Purpose      : Info on currenty running SSRS reports - only returns those over 1 minute old due to SSRS settings
--* Applications : DBAdmin
--* Created Date : 03/03/2014
--* Created By   : JordanS
--***************************************************************************************************************************************************
--* Edited By    | Date     | WorkOrder   | Reason
--*--------------+----------+-------------+----------------------------------------------------------------------------------------------------------
--* JordanS      | 09/08/14 |             | Moved to SSRS schema and renamed
--***************************************************************************************************************************************************

CREATE VIEW SSRS.ReportsCurrentlyRunning

AS

SELECT RJ.RequestName,
       RJ.RequestPath,
       RJ.ComputerName,
       U.UserName,
       RJ.[Timeout] AS TimeoutSec,
       RJ.StartDate,
       CASE 
         WHEN RJ.JobStatus IN (0,4,5) THEN 'Success'
         WHEN RJ.JobStatus IN (1,2,3,7) THEN 'InProgress'
         ELSE 'Undefined'
       END AS JobStatus,
       CAST((CAST(CAST(RJ.StartDate AS FLOAT) - CAST(RJ.StartDate AS FLOAT) AS INT) * 24) + DATEPART(HH,GETDATE()-RJ.StartDate) AS VARCHAR(10))
         + ':' + RIGHT('0' + CAST(DATEPART(MI,GETDATE()-RJ.StartDate) AS VARCHAR(2)),2)
         + ':' + RIGHT('0' + CAST(DATEPART(SS,GETDATE()-RJ.StartDate) AS VARCHAR(2)),2) AS 'TimeElapsed(HH:MI:SS)'
  FROM ReportServer.dbo.RunningJobs RJ
  LEFT JOIN ReportServer.dbo.Users U
    ON RJ.UserId = U.UserID
 WHERE RJ.StartDate < DATEADD(MINUTE,-1,GETDATE())

GO
