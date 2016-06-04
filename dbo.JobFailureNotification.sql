
IF EXISTS (SELECT * FROM sys.objects WHERE OBJECT_ID = OBJECT_ID(N'dbo.JobFailureNotification') AND [Type] IN (N'P', N'PC'))
  DROP PROCEDURE dbo.JobFailureNotification;
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
--***************************************************************************************************************************************************
--* Name         : dbo.JobFailureNotification
--* Purpose      : Sends a notification with step output for failed jobs
--* Applications : DBA
--* Created Date : 04/19/2012
--***************************************************************************************************************************************************

CREATE PROCEDURE dbo.JobFailureNotification

AS

SET NOCOUNT ON;

MERGE DBAdmin.dbo.JobFailures AS TGT
USING (
        SELECT LJRI.instance_id
              ,LJRI.name
              ,LJRI.job_id
              ,LJRI.step_name
              ,LJRI.step_id
              ,LJRI.[message]
              ,LJRI.last_run_outcome
              ,LJRI.LastRunDateTime
              ,LJRI.LastRunDuration
              ,LJRI.subsystem
              ,1 AS UpdateFlag
          FROM DBAdmin.Agent.LastJobRunInfo LJRI
      ) AS SRC
   ON TGT.JobID = SRC.job_id
  AND TGT.StepID = SRC.step_id
 -- Handle any new jobs or steps:
 WHEN NOT MATCHED BY TARGET 
 THEN INSERT(InstanceID, 
             JobName, 
             JobID, 
             StepName, 
             StepID, 
             StepMessage, 
             LastRunOutcome, 
             LastRunDateTime, 
             LastRunDuration, 
             SubSystem,
             UpdateFlag)
      VALUES(SRC.instance_id, 
             SRC.[Name], 
             SRC.job_id, 
             SRC.step_name, 
             SRC.step_id, 
             SRC.[message], 
             SRC.last_run_outcome, 
             SRC.LastRunDateTime, 
             SRC.LastRunDuration, 
             SRC.subsystem,
             SRC.UpdateFlag)
 -- Delete from target table if they no longer exist (or were disabled):
 WHEN NOT MATCHED BY SOURCE 
 THEN DELETE
 -- Update the info if the InstanceIDs don't match:
 WHEN MATCHED AND SRC.instance_id <> TGT.InstanceID 
 THEN UPDATE 
         SET TGT.InstanceID = SRC.instance_id,
             TGT.JobName = SRC.[name],
             TGT.StepName = SRC.step_name,
             TGT.StepMessage = SRC.[message],
             TGT.LastRunOutcome = SRC.last_run_outcome,
             TGT.LastRunDateTime = SRC.LastRunDateTime,
             TGT.SubSystem = SRC.subsystem,
             TGT.UpdateFlag = 1
;

-- Ignore any jobs and steps that exist in the JobFailures_IgnoreJobs table:
UPDATE J
   SET J.UpdateFlag = 0
  FROM DBAdmin.dbo.JobFailures J
 INNER JOIN DBAdmin.dbo.JobFailures_IgnoreJobs I
    ON J.JobID = I.JobID;

-- Grab error information from the SSISDB catalog. Comment out this part if it isn't needed
UPDATE JF
   SET StepMessage = LSEM.ErrorMessage
  FROM DBAdmin.dbo.JobFailures JF
 OUTER APPLY DBAdmin.Agent.LastSSISPackageErrorMessage(JF.JobID,JF.StepID) LSEM
 WHERE LastRunOutcome = 0
   AND JF.SubSystem = 'SSIS';

IF EXISTS(SELECT TOP 1 JobID FROM DBAdmin.dbo.JobFailures WHERE UpdateFlag = 1 AND LastRunOutcome = 0 AND LastRunDateTime IS NOT NULL)
BEGIN

  DECLARE @DBMailProfileName    NVARCHAR(1000) = 'ProfileName',
          @NotifyEmail          VARCHAR(500)   = 'DistributionGroup@Domain',
          @EmailSubject         VARCHAR(1000)  = 'Job Failure Notification - ' + @@SERVERNAME,
          @EmailBody            VARCHAR(1000)  = 'Job failure notification generated at ' + CONVERT(VARCHAR,GETDATE()),
          @tableHTML            NVARCHAR(MAX);

  SET @tableHTML =
      N'<H1 align="center" style="font-family:Cambria;">' + @@SERVERNAME + ' Job Failure Report</H1>' +
      N'<table border="1" style="border: solid black 1px;font-family:Calibri;font-size:13">' +
      N'<tr><th>Job Name</th><th>Step Name</th>' +
      N'<th>Step Message</th><th>Last Run DateTime</th><th>Last Run Duration</th></tr>' +
      CAST ( ( SELECT td = JobName, '',
                      td = StepName, '',
                      td = StepMessage, '',
                      td = CONVERT(VARCHAR,LastRunDateTime,120), '',
                      td = LastRunDuration
                 FROM DBAdmin.dbo.JobFailures
                WHERE UpdateFlag = 1
                  AND LastRunOutcome = 0
                  AND LastRunDateTime IS NOT NULL
                ORDER BY JobName, StepName, LastRunDateTime ASC
                FOR XML PATH('tr'), TYPE 
    ) AS NVARCHAR(MAX) ) +
    N'</table>' ;

  EXEC msdb.dbo.SP_Send_DBMail  @Profile_Name = @DBMailProfileName,
                                @Recipients   = @NotifyEmail,
                                @Subject      = @EmailSubject,
                                @Body         = @tableHTML,
                                @Body_format  = 'HTML';

END;

UPDATE DBAdmin.dbo.JobFailures
   SET UpdateFlag = 0

GO
