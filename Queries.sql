
------------------------------------------
-- Reporting Services - Useful Queries: -- 
------------------------------------------

-- Here's a link with several good queries:
--  http://sankarreddy.spaces.live.com/blog/cns!1F1B61765691B5CD!362.entry

-----------------------------------------------------------------------------------------------------------------------
-- Catalog Queries:

-- Show every report and the default data source(s):
SELECT C.[Name] AS ReportName, C.[Path] AS ReportManagerPath, DS.[Name] AS DataSourceName, U.UserName AS CreatedByUser, 
       C.CreationDate, C.ModifiedDate
  FROM dbo.[Catalog] C WITH (NOLOCK)
  LEFT JOIN dbo.DataSource DS WITH (NOLOCK)
    ON C.ItemID = DS.ItemID
  LEFT JOIN dbo.Users U WITH (NOLOCK)
    on C.CreatedByID = U.UserID
 WHERE C.[Type] = 2
 ORDER BY C.[Name];

-- Show each item in the catalog and decode by type (not sure if the list is complete):
SELECT C.[Name], C.[Type],
       CASE C.[Type]
         WHEN 1 THEN 'Folder'
         WHEN 2 THEN 'Report'
         WHEN 5 THEN 'Data Source'
         ELSE 'Other'
       END AS TypeDescription
  FROM dbo.[Catalog] C WITH (NOLOCK)
 ORDER BY C.[Name];

-- Link a report, subscription to the SQL Agent job, including the last run datetime:
SELECT C.[Name] AS ReportName, C.[Path] AS ReportPath, J.[Name] AS JobName, J.Date_Created, J.Date_Modified, 
       CAST(extensionSettings AS XML).value('(//ParameterValue/Value)[1]','varchar(max)') AS ExtSettingsXML,
       CASE SJS.last_run_date
         WHEN 0 THEN NULL
         ELSE CAST(CAST(SJS.last_run_date AS CHAR(8)) + ' ' + STUFF(STUFF(RIGHT('000000' + 
           CAST(SJS.last_run_time AS VARCHAR(6)),6),3,0,':'),6,0,':') AS DATETIME)
         END AS LastRunDateTime
  FROM ReportServer.dbo.ReportSchedule R WITH (NOLOCK)
 INNER JOIN msdb.dbo.sysjobs J WITH (NOLOCK)
    ON CONVERT(VARCHAR(50),R.ScheduleID) = J.[Name]
 INNER JOIN msdb.dbo.sysjobsteps SJS WITH (NOLOCK)
    ON J.job_id = SJS.job_id 
 INNER JOIN ReportServer.dbo.Subscriptions S WITH (NOLOCK)
    ON R.SubscriptionID = S.SubscriptionID
 INNER JOIN ReportServer.dbo.Catalog C WITH (NOLOCK)
    ON S.Report_OID = C.ItemID
 ORDER BY C.[Name], 'LastRunDateTime' ASC
 
-- Great query to show all permissions (and path) given to a user or group:
SELECT CASE C.Name
         WHEN '' THEN 'Root Folder'
         ELSE C.[Name]
       END AS ObjectName
      ,C.[Path] AS ObjectPath
      ,U.UserName
      ,R.RoleName
      ,R.Description
      ,U.AuthType
  FROM ReportServer.dbo.Users U
  JOIN ReportServer.dbo.PolicyUserRole PUR
    ON U.UserID = PUR.UserID
  JOIN ReportServer.dbo.Policies P
    ON P.PolicyID = PUR.PolicyID
  JOIN ReportServer.dbo.Roles R
    ON R.RoleID = PUR.RoleID
  JOIN ReportServer.dbo.Catalog C
    ON C.PolicyID = P.PolicyID
 WHERE U.UserName = 'HERITAGECOIN\Domain Users'
 ORDER BY C.[Name], U.UserName, R.RoleName
 
-- Show item permissions in a certain path, by user/object:
SELECT CASE C.Name
         WHEN '' THEN 'Root Folder'
         ELSE C.[Name]
       END AS ObjectName
      ,C.[Path] AS ObjectPath
      ,U.UserName
      ,R.RoleName
      ,R.Description
      ,U.AuthType
  FROM ReportServer.dbo.[Catalog] C
 INNER JOIN ReportServer.dbo.Policies P
    ON C.PolicyID = P.PolicyID
 INNER JOIN ReportServer.dbo.PolicyUserRole PUR
    ON P.PolicyID = PUR.PolicyID
 INNER JOIN ReportServer.dbo.Users U 
    ON PUR.UserID = U.UserID
 INNER JOIN ReportServer.dbo.Roles R
    ON PUR.RoleID = R.RoleID
 WHERE C.[Path] LIKE '/MailList%'
 ORDER BY C.[Name], C.[Path], U.UserName, R.RoleName
 
-- Show information on all Shared Data Sources:
;WITH XMLNAMESPACES
(
  DEFAULT 'http://schemas.microsoft.com/sqlserver/reporting/2006/03/reportdatasource',
          'http://schemas.microsoft.com/SQLServer/reporting/reportdesigner' AS RD
), 
SDS_CTE AS 
(
  SELECT SDS.[name] AS SharedDataSourceName
        ,ISNULL(RCounts.Dependents,0) AS Dependents
        ,SDS.[Path] AS DataSourcePath
        ,CONVERT(XML,CONVERT(VARBINARY(MAX),SDS.Content)) AS DEF
        ,DS.Extension AS Extension
        ,CASE DS.credentialretrieval
           WHEN 1 THEN 'User Supplied'
           WHEN 2 THEN 'Stored'
           WHEN 3 THEN 'Windows Integrated'
           WHEN 4 THEN 'Not Required'
         END AS CredentialType
        ,SDS.CreationDate
        ,U.Username AS CreatedBy
        ,UM.Username AS ModifiedBy
        ,SDS.ModifiedDate
    FROM ReportServer.dbo.[Catalog] AS SDS
   INNER JOIN ReportServer.dbo.Users U
      ON SDS.CreatedByID = U.UserID
   INNER JOIN ReportServer.dbo.Users UM
      ON SDS.ModifiedByID = UM.UserID
   INNER JOIN ReportServer.dbo.DataSource DS
      ON SDS.ItemID = DS.ItemID
    LEFT JOIN (
         SELECT DS.Link AS DSLink
               ,COUNT(1) AS Dependents
           FROM ReportServer.dbo.[Catalog] C
          INNER JOIN Users CU
             ON C.CreatedByID = CU.UserID
          INNER JOIN Users MU
             ON C.ModifiedByID = MU.UserID
           LEFT JOIN SecData SD
             ON C.PolicyID = SD.PolicyID
            AND SD.AuthType = 1
          INNER JOIN DataSource DS
             ON C.ItemID = DS.ItemID
          GROUP BY DS.Link) RCounts
      ON SDS.ItemID = Rcounts.DSLink
   WHERE SDS.[type] = 5)
SELECT SDS.DataSourcePath
      ,SDS.SharedDataSourceName
      ,SDS.Dependents
      ,DSN.value('ConnectString[1]','VARCHAR(MAX)') AS ConnectionString
      ,DSN.value('Enabled[1]','VARCHAR(MAX)') AS DataSourceEnabled
      ,SDS.Extension
      ,SDS.CredentialType
      ,SDS.CreationDate
      ,SDS.CreatedBy
      ,SDS.ModifiedDate
      ,SDS.ModifiedBy
      ,SDS.DEF AS DataSourceXML
  FROM SDS_CTE SDS
 CROSS APPLY SDS.DEF.nodes('/DataSourceDefinition') R(DSN)
 ORDER BY SDS.DataSourcePath, SDS.SharedDataSourceName;
 
-- Just like above, but get the actual names that use a data source:
;WITH XMLNAMESPACES
(
  DEFAULT 'http://schemas.microsoft.com/sqlserver/reporting/2006/03/reportdatasource',
          'http://schemas.microsoft.com/SQLServer/reporting/reportdesigner' AS RD
), 
SDS_CTE AS 
(
  SELECT SDS.[name] AS SharedDataSourceName
        --,ISNULL(RCounts.Dependents,0) AS Dependents
        ,RCounts.*
        ,SDS.[Path] AS DataSourcePath
        ,CONVERT(XML,CONVERT(VARBINARY(MAX),SDS.Content)) AS DEF
        ,DS.Extension AS Extension
        ,CASE DS.credentialretrieval
           WHEN 1 THEN 'User Supplied'
           WHEN 2 THEN 'Stored'
           WHEN 3 THEN 'Windows Integrated'
           WHEN 4 THEN 'Not Required'
         END AS CredentialType
        ,SDS.CreationDate
        ,U.Username AS CreatedBy
        ,UM.Username AS ModifiedBy
        ,SDS.ModifiedDate
    FROM ReportServer.dbo.[Catalog] AS SDS
   INNER JOIN ReportServer.dbo.Users U
      ON SDS.CreatedByID = U.UserID
   INNER JOIN ReportServer.dbo.Users UM
      ON SDS.ModifiedByID = UM.UserID
   INNER JOIN ReportServer.dbo.DataSource DS
      ON SDS.ItemID = DS.ItemID
    LEFT JOIN (
         SELECT DS.Link AS DSLink
               ,C.[Name] AS ObjectName
               --,COUNT(1) AS Dependents
           FROM ReportServer.dbo.[Catalog] C
          INNER JOIN Users CU
             ON C.CreatedByID = CU.UserID
          INNER JOIN Users MU
             ON C.ModifiedByID = MU.UserID
           LEFT JOIN SecData SD
             ON C.PolicyID = SD.PolicyID
            AND SD.AuthType = 1
          INNER JOIN DataSource DS
             ON C.ItemID = DS.ItemID) RCounts
      ON SDS.ItemID = Rcounts.DSLink
   WHERE SDS.[type] = 5)
SELECT SDS.DataSourcePath
      ,SDS.SharedDataSourceName
      ,SDS.DSLink
      ,SDS.ObjectName
      ,DSN.value('ConnectString[1]','VARCHAR(MAX)') AS ConnectionString
      ,DSN.value('Enabled[1]','VARCHAR(MAX)') AS DataSourceEnabled
      ,SDS.Extension
      ,SDS.CredentialType
      ,SDS.CreationDate
      ,SDS.CreatedBy
      ,SDS.ModifiedDate
      ,SDS.ModifiedBy
      ,SDS.DEF AS DataSourceXML
  FROM SDS_CTE SDS
 CROSS APPLY SDS.DEF.nodes('/DataSourceDefinition') R(DSN)
 WHERE DataSourcePath = '/Data Sources/DSS_HNAI'
 ORDER BY SDS.DataSourcePath, SDS.SharedDataSourceName;

-----------------------------------------------------------------------------------------------------------------------

-- Query the dbo.ExecutionLog table for report-running info:
SELECT C.[Name] AS ReportName, C.[Path] AS ReportPath, EL.TimeStart, EL.TimeEnd, EL.Parameters, EL.UserName, EL.[Status], 
       EL.TimeDataRetrieval, EL.TimeProcessing, EL.TimeRendering, 
       DATEADD(SS,(DATEDIFF(SS,EL.TimeStart,EL.TimeEnd)),CAST('00:00:00' AS TIME)) AS CommandDuration
  FROM ReportServer.dbo.ExecutionLog EL
 INNER JOIN ReportServer.dbo.[Catalog] C 
    ON EL.ReportID = C.ItemID
 WHERE TimeStart > '2015-03-24'
   AND C.[Name] = 'Client Shipping Report'
 ORDER BY TimeStart DESC

SELECT C.[Name] AS ReportName, C.[Path] AS ReportPath, EL.TimeStart, EL.TimeEnd, EL.Parameters, EL.UserName, EL.[Status]
  FROM ReportServer.dbo.ExecutionLog EL
 INNER JOIN ReportServer.dbo.[Catalog] C 
    ON EL.ReportID = C.ItemID
 WHERE TimeStart > '2013-02-15'
 ORDER BY TimeStart DESC
 
-- Query any reports that are currently running:
SELECT *
  FROM ReportServer.dbo.RunningJobs
 ORDER BY StartDate ASC
 

-- Use the same table to view ByteCount information (in KB):
select *
from dbo.ExecutionLog
where (ByteCount/1024) > 100		-- Change (default - 100KB)
order by ByteCount desc
go


-- Find the reports/names run within a certain time frame:												GOOD QUERY
select x.UserName, x.TimeStart, x.TimeEnd, x.TimeDataRetrieval, x.TimeProcessing, x.TimeRendering, c.Name --, x.ByteCount/1024.00 as KB
  from dbo.ExecutionLog x join dbo.Catalog c
    on x.ReportID = c.ItemID
 where x.TimeStart BETWEEN '2009-11-09 00:00:00.000' AND '2009-11-10 20:00:00'
 order by x.TimeStart asc



-----------------------------------------------------------------------------------------------------------------------
-- More in-depth looks at the ExecutionLog table:


-- Find the average processing time and times run for the TimeProcessing value of each report, grouped by report name:

select c.Name, count(1) as TimesRun, avg(x.TimeProcessing) as AvgProcTimeMS, max(x.TimeStart) as LastRunDate
  from dbo.ExecutionLog x join dbo.Catalog c
    on x.ReportID = c.ItemID
 where x.TimeStart >= '2009-08-31 00:00:00.000'			-- Change date
 group by c.Name
 order by AvgProcTimeMS desc
go


-- For more detail, look at the TimeProcessing column for the amount of milliseconds taken to process the report:

select x.UserName, x.TimeStart, x.TimeEnd, x.TimeDataRetrieval, x.TimeProcessing, x.TimeRendering, c.Name --, x.ByteCount/1024.00 as KB
  from dbo.ExecutionLog x join dbo.Catalog c
    on x.ReportID = c.ItemID
 where x.TimeStart >= '2009-08-31 00:00:00.000'
   --and x.TimeStart < '2009-08-31 23:00:00.000'order by x.TimeProcessing desc  
go


-- Count the number of reports run by each user in a given week:

select UserName, count(*) as NumReports
  from ReportServer.dbo.ExecutionLog
 where TimeStart BETWEEN '2009-11-16 00:00:00.000' AND '2009-11-19 00:00:00.000'
 group by UserName
 order by Username
go

-----------------------------------------------------------------------------------------------------------------------
-- Browse the Configurations for Reporting Services:

select *
from dbo.ConfigurationInfo
go


-- Query for subscriptions with a certain recipient (note that Microsoft doesn't support updates to XML):
SELECT C.ItemID, C.[Path] AS ReportPath, C.[Name] AS ReportName, sub.SubscriptionID, 
       CAST(extensionSettings AS XML).value('(//ParameterValue/Value)[1]','varchar(max)') AS ExtSettingsXML,
       extensionSettings AS ActualXML
  FROM dbo.Catalog AS C
 INNER JOIN dbo.Subscriptions AS sub ON C.ItemID = sub.Report_OID
 WHERE CAST(extensionSettings AS XML).value('(//ParameterValue/Value)[1]','varchar(max)') LIKE '%justina%'
 ORDER BY C.[Path], C.[Name]
 

-----------------------------------------------------------------------------------------------------------------------
