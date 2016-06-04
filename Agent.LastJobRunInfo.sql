
-- Agent.LastJobRunInfo: View used to grab job history for all enabled jobs
IF EXISTS (SELECT * FROM sys.objects WHERE OBJECT_ID = OBJECT_ID('Agent.LastJobRunInfo') AND [Type] = 'V')
  DROP VIEW Agent.LastJobRunInfo;
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER OFF;
GO
--***************************************************************************************************************************************************
--* Name         : Agent.LastJobRunInfo
--* Purpose      : Get info on last run for all enabled jobs for each step
--* Applications : DBA
--* Created Date : 04/19/2012
--***************************************************************************************************************************************************

CREATE VIEW Agent.LastJobRunInfo

AS

SELECT L.instance_id,
       SJ.[name], 
       SJH.job_id, 
       L.step_name, 
       L.step_id, 
       SJH.[message],
       L.last_run_outcome,
       CASE L.last_run_date
         WHEN 0 THEN NULL
         ELSE CAST(CAST(L.last_run_date AS CHAR(8)) + ' ' + STUFF(STUFF(RIGHT('000000' + CAST(L.last_run_time AS VARCHAR(6)),6),3,0,':'),6,0,':') AS DATETIME)
       END AS LastRunDateTime,
       STUFF(STUFF(RIGHT('000000' + CAST(L.last_run_duration AS VARCHAR(6)),6),3,0,':'),6,0,':') AS LastRunDuration,
       L.subsystem
  FROM msdb.dbo.sysjobhistory SJH WITH (NOLOCK)
 INNER JOIN (
       SELECT SJS.job_id, 
              SJS.step_id, 
              SJS.step_name, 
              SJS.last_run_outcome, 
              SJS.last_run_date, 
              SJS.last_run_time, 
              SJS.last_run_duration, 
              SJS.subsystem,
              MAX(SJH.instance_id) AS instance_id
         FROM msdb.dbo.sysjobhistory SJH WITH (NOLOCK)
        INNER JOIN msdb.dbo.sysjobsteps SJS WITH (NOLOCK)
           ON SJS.job_id = SJH.job_id
          AND SJS.step_id = SJH.step_id
        GROUP BY SJS.job_id, SJS.step_id, SJS.step_name, SJS.last_run_outcome, SJS.last_run_date, SJS.last_run_time, SJS.last_run_duration, SJS.subsystem) L
    ON SJH.job_id = L.job_id
   AND SJH.instance_id = L.instance_id
 INNER JOIN msdb.dbo.sysjobs SJ WITH (NOLOCK)
    ON SJH.job_id = SJ.job_id
 WHERE SJ.[Name] NOT LIKE '_____________-____-____-____________'
   AND SJ.[enabled] = 1;

GO
