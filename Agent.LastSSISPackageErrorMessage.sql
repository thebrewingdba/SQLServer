
IF EXISTS (SELECT * FROM sys.objects WHERE OBJECT_ID = OBJECT_ID(N'Agent.LastSSISPackageErrorMessage') AND [Type] IN (N'FN', N'IF', N'TF', N'FS', N'FT'))
  DROP FUNCTION Agent.LastSSISPackageErrorMessage;
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
--***************************************************************************************************************************************************
--* Name         : Agent.LastSSISPackageErrorMessage
--* Purpose      : Get Agent SSIS job error information from the Integration Services catalog
--* Applications : DBAdmin
--* Created Date : 2015-09-21
--***************************************************************************************************************************************************

CREATE FUNCTION Agent.LastSSISPackageErrorMessage
(
  @job_id UNIQUEIDENTIFIER,
  @step_id INT
)
RETURNS TABLE

AS

RETURN

SELECT SP.PackageName,
       EM.ErrorMessage, 
       EM.RankNum
  FROM (
       SELECT JS.job_id, 
              JS.step_id,
              JS.command,
              RIGHT(LEFT(JS.command,CHARINDEX('.dtsx',JS.command)-1),CHARINDEX('\',REVERSE(LEFT(JS.command,CHARINDEX('.dtsx',JS.command)-1)))-1)+'.dtsx' AS PackageName
         FROM msdb.dbo.sysjobsteps JS
        WHERE JS.Subsystem = 'SSIS'
          AND JS.command LIKE '%ssis%') SP
 INNER JOIN (
       SELECT RankNum = RANK() OVER (PARTITION BY EM.operation_id ORDER BY EM.message_time ASC, EM.event_message_id ASC),
              EM.operation_id,
              LEFT(EM.[message],4000) AS ErrorMessage,
              EM.package_name
         FROM SSISDB.[catalog].event_messages EM
        INNER JOIN (
              SELECT MAX(operation_id) AS operation_id,
                     package_name
                FROM SSISDB.[catalog].event_messages
               GROUP BY package_name) MO
           ON EM.operation_id = MO.operation_id
          AND EM.package_name = MO.package_name
        WHERE EM.event_name = 'OnError') EM
    ON SP.PackageName = EM.package_name
   AND EM.RankNum = 1
 WHERE SP.job_id = @job_id
   AND SP.step_id = @step_id;

GO
