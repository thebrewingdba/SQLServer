
-- dbo.JobFailures_IgnoreJobs: Put all of the jobs you want to ignore in here
IF EXISTS (SELECT * FROM sys.objects WHERE OBJECT_ID = OBJECT_ID('dbo.JobFailures_IgnoreJobs') AND [Type] = 'U')
  DROP TABLE dbo.JobFailures_IgnoreJobs;
GO

SET ANSI_NULLS ON;
GO
SET QUOTED_IDENTIFIER ON;
GO
SET ANSI_PADDING ON;
GO

CREATE TABLE dbo.JobFailures_IgnoreJobs
(
  JobName SYSNAME NOT NULL,
  JobID   UNIQUEIDENTIFIER NOT NULL,
  CONSTRAINT [PKC_JobFailures_IgnoreJobs_JobID] PRIMARY KEY CLUSTERED 
  (
    JobID ASC
  )
  WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) 
  ON [PRIMARY]
) 
ON [PRIMARY]
GO
