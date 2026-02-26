################################################
# Function - Write-RSCObjects - Getting all objects visible to the RSC instance and writing them to a SQL database table
################################################
function Write-RSCObject {

    <#
.SYNOPSIS
A Rubrik Security Cloud (RSC) Reporting Module Function for writing RSC Objects data into a MSSQL DB/Table of your choosing.

.DESCRIPTION
Makes the required GraphQL API calls to RSC via Invoke-RestMethod to get the data as described, then creates a usable array of the returned information, removing the need for the PowerShell user to understand GraphQL in order to interact with RSC.

.PARAMETER SQLInstance
The SQL server and instance name (if required) to connect to your MS SQL server. Ensure the user running the script has permission to connect, recommended to check using MS SQL Mgmt Studio first.
.PARAMETER SQLDB
The SQL database in which to create the required table to write the events. This must already exist, it will not create the database for you.
.PARAMETER SQLTable
Not required, it will create a table called RSCEvents for you, but you can customize the name (not the structure). Has to not already exist on 1st run unless you already used the correct structure. 
.PARAMETER DontUseTempDB
Switch to disable use of TempDB for scale. Use if you don't have permission to create/drop tables in TempDB. Events are written straight into the table then duplicate EventIDs are removed.
.PARAMETER DropExistingRows
Drops all existing rows in the table specified, otherwise it just uses a new datetime on each run (so you can either just maintain the latest, or over time on a frequency you desire).
.PARAMETER SampleFirst10Objects
If you have a large environment and simply want to do a test run, use this to get a sample.

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.OUTPUTS
None, all the events are written into the MS SQL DB specified.

.EXAMPLE
Write-RSCObjects -SQLInstance "localhost" -SQLDB "YourDBName"
This example gets all object storage usage, creates a table called RSCObjectStorageUsage with the required structure then populates it with the API data.

.EXAMPLE
Write-RSCObjects -SQLInstance "localhost" -SQLDB "YourDBName" -DontUseTempDB
This example does the same as above, but doesn't use TempDB (if you have permissions issues with creating tables in it and aren't concerned about locks).

.EXAMPLE
Write-RSCObjects -SQLInstance "localhost" -SQLDB "YourDBName" -SQLTable "YourTableName" 
This example gets all object storage usage, creates a table using the name specified with the required structure then populates it with the API data.

.NOTES
Author: Joshua Stenhouse
Date: 08/02/2024
#>

    ################################################
    # Paramater Config
    ################################################
    [CmdletBinding()]
    [Alias('Write-RSCObjects')]
    param
    (
        [Parameter(Mandatory = $true)]$SQLInstance,
        [Parameter(Mandatory = $true)]$SQLDB, $SQLTable,
        [switch]$DropExistingRows,
        [switch]$DontUseTempDB,
        [switch]$DisableLogging
    )
    ################################################
    # Getting times required
    ################################################
    $ScriptStart = Get-Date
    $MachineDateTime = Get-Date
    $UTCDateTime = [System.DateTime]::UtcNow
    ################################################
    # Importing SQL Server Module
    ################################################
    # Getting the name of the SQL Server module to use (either SqlServer or SQLPS)
    $PSModules = Get-Module -ListAvailable | Select-Object -ExpandProperty Name
    $SQLModuleName = $PSModules | Where-Object { (($_ -eq "SQLPS") -or ($_ -eq "SqlServer")) } | Select-Object -Last 1
    # Checking to see if SQL Server module is loaded
    $SQLModuleCheck = Get-Module $SQLModuleName
    # If SQL module not found in current session importing
    if ($SQLModuleCheck -eq $null) { Import-Module $SQLModuleName -ErrorAction SilentlyContinue }
    ##########################
    # SQL - Checking Table Exists
    ##########################
    # Manually setting SQL table name if not specified
    if ($SQLTable -eq $null) { $SQLTable = "RSCObjects" }
    # Creating query
    $SQLTableListQuery = "USE $SQLDB;
SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES;"
    # Run SQL query
    try {
        $SQLTableList = Invoke-Sqlcmd -Query $SQLTableListQuery -ServerInstance $SQLInstance -QueryTimeout 300 
    }
    catch {
        $Error[0] | Format-List -Force
    }
    # Selecting
    $SQLTableList = $SQLTableList | Select-Object -ExpandProperty TABLE_NAME
    # Checking
    if ($SQLTableList -match $SQLTable) { $SQLTableExists = $TRUE }else { $SQLTableExists = $FALSE }
    ##########################
    # SQL - Creating table if doesn't exist
    ##########################
    if ($SQLTableExists -eq $FALSE) {
        # Logging
        Write-Host "----------------------------------
SQLTableNotFound
CreatingSQLTable: $SQLTable"
        Start-Sleep 3
        # SQL query
        $SQLCreateTable = "USE $SQLDB;
CREATE TABLE [dbo].[$SQLTable](
	[RowID] [int] IDENTITY(1,1) NOT NULL,
	[RSCInstance] [varchar](max) NULL,
	[Object] [varchar](max) NULL,
	[ObjectID] [varchar](max) NULL,
    [ObjectCDMID] [varchar](max) NULL,
	[Type] [varchar](max) NULL,
	[Location] [varchar](max) NULL,
	[RubrikCluster] [varchar](max) NULL,
	[RubrikClusterID] [varchar](max) NULL,
	[SLADomain] [varchar](max) NULL,
    [SLADomainID] [varchar](max) NULL,
	[ProtectionStatus] [varchar](max) NULL,
    [ComplianceStatus] [varchar](max) NULL,
    [ReportOnCompliance] [varchar](max) NULL,
    [ProtectedOn] [varchar](max) NULL,
    [IsRelic] [varchar](50) NULL,
    [TotalSnapshots] [int] NULL,
    [ReplicatedSnaphots] [int] NULL,
    [ArchivedSnapshots] [int] NULL,
    [LastSnapshot] [datetime] NULL,
    [HoursSince] [decimal](18, 2) NULL,
    [PendingFirstFull] [varchar](50) NULL,
    [Replicated] [varchar](50) NULL,
    [ReplicaType] [varchar](50) NULL,
    [LastReplicatedSnapshot] [datetime] NULL,
    [LastArchivedSnapshot] [datetime] NULL,
    [LastUpdated] [datetime] NULL,
    [URL] [varchar](max) NULL,
 CONSTRAINT [PK_$SQLTable] PRIMARY KEY CLUSTERED 
(
	[RowID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY];"
        # Run SQL query
        try {
            Invoke-Sqlcmd -Query $SQLCreateTable -ServerInstance $SQLInstance -QueryTimeout 300 | Out-Null
        }
        catch {
            $Error[0] | Format-List -Force
        }
        # End of SQL table creation below
    }
    # End of SQL table creation above
    ##########################
    # SQL - Creating temp table
    ##########################
    if ($DontUseTempDB) {
        # Nothing to create, bypassing
    }
    else {
        $RandomID = 0..10000 | Get-Random
        # Create temp table name
        $TempTableName = $SQLTable + [string]$RandomID
        # Create the table from an existing structure
        $SQLCreateTable = "USE tempdb;
SELECT *   
INTO $TempTableName  
FROM $SQLDB.dbo.$SQLTable  
WHERE 1 > 2;"
        # Run SQL query
        try {
            Invoke-Sqlcmd -Query $SQLCreateTable -ServerInstance $SQLInstance -QueryTimeout 300 | Out-Null
        }
        catch {
            $Error[0] | Format-List -Force
        }
        # Logging
        Write-Host "----------------------------------
CreatingTableInTempDB: $TempTableName"
        Start-Sleep 2
    }
    ##################################
    # SQL - Deleting Data From Existing Table if Switch
    ##################################
    if ($DropExistingRows) {
        # Creating SQL query
        $SQLDrop = "USE $SQLDB
DELETE FROM $SQLTable;"
        # Run SQL query
        try {
            Invoke-Sqlcmd -Query $SQLDrop -ServerInstance $SQLInstance -QueryTimeout 300 | Out-Null
        }
        catch {
            $Error[0] | Format-List -Force
        }
        # Logging
        Write-Host "----------------------------------
DeletingExistingRowsIn: $SQLTable"
    }
    ################################################
    # Importing Module & Running Required Functions
    ################################################
    # Importing the module is it needs other modules
    Import-Module RSCReporting
    # Checking connectivity, exiting function with error if not connected
    Test-RSCConnection
    # Getting RSC SLA Domains
    Write-Host "QueryingSLADomains.."
    $RSCSLADomains = Get-RSCSLADomains
    $RSCSLADomainCount = $RSCSLADomains | Measure-Object | Select-Object -ExpandProperty Count
    Write-Host "SLADomainsFound: $RSCSLADomainCount"
    ################################################
    # Getting All Objects 
    ################################################
    # Setting first value if null
    if ($ObjectQueryLimit -eq $null) { $ObjectQueryLimit = 1000 }
    # Logging if set
    if ($ObjectType -ne $null) { Write-Host "QueryingObjects: $ObjectType" }
    # Creating array for objects
    $RSCObjectsList = @()
    # Building GraphQL query
    $RSCGraphQL = @{"operationName" = "snappableConnection";

        "variables"                 = @{
            "first"  = $ObjectQueryLimit
            "filter" = @{
                "objectType" = $ObjectType
            }
        };

        "query"                     = "query snappableConnection(`$after: String, `$filter: SnappableFilterInput) {
  snappableConnection(after: `$after, first: 1000, filter: `$filter) {
    edges {
      node {
        archivalComplianceStatus
        archivalSnapshotLag
        archiveSnapshots
        archiveStorage
        awaitingFirstFull
        complianceStatus
        dataReduction
        fid
        id
        lastSnapshot
        latestArchivalSnapshot
        latestReplicationSnapshot
        localOnDemandSnapshots
        location
        localSnapshots
        localStorage
        localEffectiveStorage
        logicalBytes
        logicalDataReduction
        missedSnapshots
        name
        usedBytes
        objectType
        physicalBytes
        protectedOn
        protectionStatus
        provisionedBytes
        pullTime
        replicaSnapshots
        replicaStorage
        replicationComplianceStatus
        slaDomain {
          id
          name
          version
        }
        replicationSnapshotLag
        totalSnapshots
        transferredBytes
        cluster {
          id
          name
        }
      }
    }
        pageInfo {
      endCursor
      hasNextPage
      hasPreviousPage
      __typename
    }
  }
}
"
    }
    # Converting to JSON
    $RSCJSON = $RSCGraphQL | ConvertTo-Json -Depth 32
    # Converting back to PS object for editing of variables
    $RSCJSONObject = $RSCJSON | ConvertFrom-Json
    ################################################
    # API Call To RSC GraphQL URI
    ################################################
    # Querying API
    $RSCObjectsResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCJSONObject | ConvertTo-Json -Depth 20) -Headers $RSCSessionHeader
    # Setting variable
    $RSCObjectsList += $RSCObjectsResponse.data.snappableConnection.edges.node
    # Counters
    $ObjectCount = 0
    $ObjectCounter = $ObjectCount + $ObjectQueryLimit
    # Getting all results from paginations
    while ($RSCObjectsResponse.data.snappableConnection.pageInfo.hasNextPage) {
        # Logging
        if ($DisableLogging) {}else { Write-Host "GettingObjects: $ObjectCount-$ObjectCounter" }
        # Getting next set
        $RSCGraphQL.variables.after = $RSCObjectsResponse.data.snappableConnection.pageInfo.endCursor
        $RSCObjectsResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-Json -Depth 20) -Headers $RSCSessionHeader
        $RSCObjectsList += $RSCObjectsResponse.data.snappableConnection.edges.node
        # Incrementing
        $ObjectCount = $ObjectCount + $ObjectQueryLimit
        $ObjectCounter = $ObjectCounter + $ObjectQueryLimit
    }
    ################################################
    # Processing All Objects 
    ################################################
    # Creating array
    $RSCObjects = [System.Collections.ArrayList]@()
    # Counting
    $RSCObjectsCount = $RSCObjectsList | Measure-Object | Select-Object -ExpandProperty Count
    $RSCObjectsCounter = 0
    # Getting current time for last snapshot age
    $UTCDateTime = [System.DateTime]::UtcNow
    # Processing
    foreach ($RSCObject in $RSCObjectsList) {
        # Logging
        $RSCObjectsCounter ++
        if ($DisableLogging) {}else { Write-Host "ProcessingObject: $RSCObjectsCounter/$RSCObjectsCount" }
        # Setting variables
        $ObjectCDMID = $RSCObject.id
        $ObjectID = $RSCObject.fid
        $ObjectName = $RSCObject.name
        $ObjectComplianceStatus = $RSCObject.complianceStatus
        $ObjectLocation = $RSCObject.location
        $ObjectType = $RSCObject.objectType
        $ObjectSLADomainInfo = $RSCObject.slaDomain
        $ObjectSLADomain = $ObjectSLADomainInfo.name
        $ObjectSLADomainID = $ObjectSLADomainInfo.id
        $ObjectTotalSnapshots = $RSCObject.totalSnapshots
        $ObjectLastSnapshot = $RSCObject.lastSnapshot
        $ObjectReplicatedSnapshots = $RSCObject.replicaSnapshots
        $ObjectArchivedSnapshots = $RSCObject.archiveSnapshots
        $ObjectPendingFirstFull = $RSCObject.awaitingFirstFull
        $ObjectProtectionStatus = $RSCObject.protectionStatus
        $ObjectProtectedOn = $RSCObject.protectedOn
        $ObjectLastUpdated = $RSCObject.pulltime
        $ObjectClusterInfo = $RSCObject.cluster
        $ObjectClusterID = $ObjectClusterInfo.id
        $ObjectClusterName = $ObjectClusterInfo.name
        $ObjectLastReplicatedSnapshot = $RSCObject.latestReplicationSnapshot
        $ObjectLastArhiveSnapshot = $RSCObject.latestArchivalSnapshot
        # Converting UNIX times if not null
        if ($ObjectProtectedOn -ne $null) { $ObjectProtectedOn = Convert-RSCUNIXTime $ObjectProtectedOn }
        if ($ObjectLastSnapshot -ne $null) { $ObjectLastSnapshot = Convert-RSCUNIXTime $ObjectLastSnapshot }
        if ($ObjectLastUpdated -ne $null) { $ObjectLastUpdated = Convert-RSCUNIXTime $ObjectLastUpdated }
        if ($ObjectLastReplicatedSnapshot -ne $null) { $ObjectLastReplicatedSnapshot = Convert-RSCUNIXTime $ObjectLastReplicatedSnapshot }
        if ($ObjectLastArhiveSnapshot -ne $null) { $ObjectLastArhiveSnapshot = Convert-RSCUNIXTime $ObjectLastArhiveSnapshot }
        # If last snapshot not null, calculating hours since
        if ($ObjectLastSnapshot -ne $null) {
            $ObjectSnapshotGap = New-TimeSpan -Start $ObjectLastSnapshot -End $UTCDateTime
            $ObjectSnapshotGapHours = $ObjectSnapshotGap.TotalHours
            $ObjectSnapshotGapHours = [Math]::Round($ObjectSnapshotGapHours, 1)
        }
        else {
            $ObjectSnapshotGapHours = 0	
        }
        # Overriding Polaris in cluster name
        if ($ObjectClusterName -eq "Polaris") { $ObjectClusterName = "RSC-Native" }
        # Overriding location to RSC if null
        if ($ObjectLocation -eq "") {
            # No account info in location for cloud native EC2/AWS/GCP etc, so for now just saying the cloud
            if ($ObjectType -match "Azure") { $ObjectLocation = "Azure" }
            if ($ObjectType -match "Ec2Instance") { $ObjectLocation = "AWS" }
            if ($ObjectType -match "Gcp") { $ObjectLocation = "GCP" }
        }
        # Getting object URL
        $ObjectURL = Get-RSCObjectURL -ObjectType $ObjectType -ObjectID $ObjectID
        # Getting SLA domain & replication info
        $RSCSLADomainInfo = $RSCSLADomains | Where-Object { $_.SLADomainID -eq $ObjectSLADomainID }
        if ($RSCSLADomainInfo.Replication -eq $True) { $ObjectISReplicated = $TRUE }else { $ObjectISReplicated = $FALSE }
        $ObjectReplicationTargetClusterID = $RSCSLADomainInfo.ReplicationTargetClusterID
        # If replicated, determining if source or target
        if ($ObjectISReplicated -eq $TRUE) {
            # Main rule, matching cluster
            if ($ObjectClusterID -eq $ObjectReplicationTargetClusterID) { $ObjectReplicaType = "Target" }else { $ObjectReplicaType = "Source" }
        }
        else {
            $ObjectReplicaType = "N/A"
        }
        # Deciding if object should be reported on for snapshots/compliance
        if (($ObjectProtectionStatus -eq "Protected") -and ($ObjectReplicaType -ne "Target")) { $ObjectReportOnCompliance = $TRUE }else { $ObjectReportOnCompliance = $FALSE }
        # Deciding if relic 
        if ($ObjectComplianceStatus -eq "NOT_APPLICABLE") { $ObjectIsRelic = $TRUE }else { $ObjectIsRelic = $FALSE }
        # Overridng $ObjectReportOnCompliance if relic
        if ($ObjectIsRelic -eq $TRUE) { $ObjectReportOnCompliance = $FALSE }
        # Overriding if compliance is empty, as this means it's a replica target
        if ($ObjectComplianceStatus -eq "EMPTY") { $ObjectReportOnCompliance = $FALSE }
        # Removing illegal SQL characters from object or location
        $ObjectName = $ObjectName.Replace("'", "")
        $ObjectLocation = $ObjectLocation.Replace("'", "")
        # Adding To Array
        $Object = New-Object PSObject
        $Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
        $Object | Add-Member -MemberType NoteProperty -Name "RubrikCluster" -Value $ObjectClusterName
        $Object | Add-Member -MemberType NoteProperty -Name "Object" -Value $ObjectName
        $Object | Add-Member -MemberType NoteProperty -Name "Type" -Value $ObjectType
        $Object | Add-Member -MemberType NoteProperty -Name "Location" -Value $ObjectLocation
        $Object | Add-Member -MemberType NoteProperty -Name "SLADomain" -Value $ObjectSLADomain
        $Object | Add-Member -MemberType NoteProperty -Name "ProtectionStatus" -Value $ObjectProtectionStatus
        $Object | Add-Member -MemberType NoteProperty -Name "ComplianceStatus" -Value $ObjectComplianceStatus
        $Object | Add-Member -MemberType NoteProperty -Name "ReportOnCompliance" -Value $ObjectReportOnCompliance
        $Object | Add-Member -MemberType NoteProperty -Name "ProtectedOn" -Value $ObjectProtectedOn
        $Object | Add-Member -MemberType NoteProperty -Name "IsRelic" -Value $ObjectIsRelic
        # Snapshot info
        $Object | Add-Member -MemberType NoteProperty -Name "TotalSnapshots" -Value $ObjectTotalSnapshots
        $Object | Add-Member -MemberType NoteProperty -Name "LastSnapshot" -Value $ObjectLastSnapshot
        $Object | Add-Member -MemberType NoteProperty -Name "HoursSince" -Value $ObjectSnapshotGapHours
        $Object | Add-Member -MemberType NoteProperty -Name "PendingFirstFull" -Value $ObjectPendingFirstFull
        # Replication info
        $Object | Add-Member -MemberType NoteProperty -Name "Replicated" -Value $ObjectISReplicated
        $Object | Add-Member -MemberType NoteProperty -Name "ReplicaType" -Value $ObjectReplicaType
        $Object | Add-Member -MemberType NoteProperty -Name "LastReplicatedSnapshot" -Value $ObjectLastReplicatedSnapshot
        $Object | Add-Member -MemberType NoteProperty -Name "ReplicatedSnaphots" -Value $ObjectReplicatedSnapshots
        # Archive info
        $Object | Add-Member -MemberType NoteProperty -Name "LastArchivedSnapshot" -Value $ObjectLastArhiveSnapshot
        $Object | Add-Member -MemberType NoteProperty -Name "ArchivedSnapshots" -Value $ObjectArchivedSnapshots
        $Object | Add-Member -MemberType NoteProperty -Name "LastUpdated" -Value $ObjectLastUpdated
        # IDs
        $Object | Add-Member -MemberType NoteProperty -Name "ObjectID" -Value $ObjectID
        $Object | Add-Member -MemberType NoteProperty -Name "ObjectCDMID" -Value $ObjectCDMID
        $Object | Add-Member -MemberType NoteProperty -Name "SLADomainID" -Value $ObjectSLADomainID
        $Object | Add-Member -MemberType NoteProperty -Name "RubrikClusterID" -Value $ObjectClusterID
        # URL
        $Object | Add-Member -MemberType NoteProperty -Name "URL" -Value $ObjectURL
        # Adding
        $RSCObjects.Add($Object) | Out-Null
        ############################
        # Adding To SQL Table directly if no tempDB
        ############################
        if ($DontUseTempDB) {
            $SQLInsert = "USE $SQLDB
INSERT INTO $SQLTable (
-- RSC & Object IDs
RSCInstance, Object, ObjectID, ObjectCDMID, Type, Location,

-- Cluster & SLA info
RubrikCluster, RubrikClusterID, SLADomain, SLADomainID,

-- Status
ProtectionStatus, ComplianceStatus, ReportOnCompliance, ProtectedOn, IsRelic,

-- Snapshots
TotalSnapshots, ReplicatedSnaphots, ArchivedSnapshots, LastSnapshot, HoursSince, PendingFirstFull,

-- Replica and Archive
Replicated, ReplicaType, LastReplicatedSnapshot, LastArchivedSnapshot,

-- End
LastUpdated, URL)
VALUES(
-- Date RSC & Object IDs
'$RSCInstance', '$ObjectName', '$ObjectID', '$ObjectCDMID', '$ObjectType', '$ObjectLocation',

-- Cluster & SLA info
'$ObjectClusterName', '$ObjectClusterID', '$ObjectSLADomain', '$ObjectSLADomainID',

-- Status
'$ObjectProtectionStatus', '$ObjectComplianceStatus', '$ObjectReportOnCompliance', '$ObjectProtectedOn', '$ObjectIsRelic',

-- Snapshots
'$ObjectTotalSnapshots', '$ObjectReplicatedSnapshots', '$ObjectArchivedSnapshots', '$ObjectLastSnapshot', '$ObjectSnapshotGapHours', '$ObjectPendingFirstFull',

-- Replica and Archive
'$ObjectISReplicated', '$ObjectReplicaType', '$ObjectLastReplicatedSnapshot', '$ObjectLastArhiveSnapshot',

-- End
'$ObjectLastUpdated', '$ObjectURL');"
            # Inserting
            try {
                Invoke-Sqlcmd -Query $SQLInsert -ServerInstance $SQLInstance -QueryTimeout 300 | Out-Null
            }
            catch {
                $Error[0] | Format-List -Force
            }
        }
        else {
            ############################
            # Adding To SQL temp table
            ############################
            $SQLInsert = "USE tempdb
INSERT INTO $TempTableName (
-- RSC & Object IDs
RSCInstance, Object, ObjectID, ObjectCDMID, Type, Location,

-- Cluster & SLA info
RubrikCluster, RubrikClusterID, SLADomain, SLADomainID,

-- Status
ProtectionStatus, ComplianceStatus, ReportOnCompliance, ProtectedOn, IsRelic,

-- Snapshots
TotalSnapshots, ReplicatedSnaphots, ArchivedSnapshots, LastSnapshot, HoursSince, PendingFirstFull,

-- Replica and Archive
Replicated, ReplicaType, LastReplicatedSnapshot, LastArchivedSnapshot,

-- End
LastUpdated, URL)
VALUES(
-- Date RSC & Object IDs
'$RSCInstance', '$ObjectName', '$ObjectID', '$ObjectCDMID', '$ObjectType', '$ObjectLocation',

-- Cluster & SLA info
'$ObjectClusterName', '$ObjectClusterID', '$ObjectSLADomain', '$ObjectSLADomainID',

-- Status
'$ObjectProtectionStatus', '$ObjectComplianceStatus', '$ObjectReportOnCompliance', '$ObjectProtectedOn', '$ObjectIsRelic',

-- Snapshots
'$ObjectTotalSnapshots', '$ObjectReplicatedSnapshots', '$ObjectArchivedSnapshots', '$ObjectLastSnapshot', '$ObjectSnapshotGapHours', '$ObjectPendingFirstFull',

-- Replica and Archive
'$ObjectISReplicated', '$ObjectReplicaType', '$ObjectLastReplicatedSnapshot', '$ObjectLastArhiveSnapshot',

-- End
'$ObjectLastUpdated', '$ObjectURL');"
            # Inserting
            try {
                Invoke-Sqlcmd -Query $SQLInsert -ServerInstance $SQLInstance -QueryTimeout 300 | Out-Null
            }
            catch {
                $Error[0] | Format-List -Force
            }
            # End of bypass for using tempdb below
        }
        # End of bypass for using tempdb above
        #
        # End of for each object below
    }
    # End of for each object above

    # Setting global variable for use in other functions so they don't have to collect it again
    $Global:RSCGlobalObjects = $RSCObjects

    ##################################
    # Finishing SQL Work
    ##################################
    # Logging
    Write-Host "----------------------------------
Finished Processing RSC Objects
----------------------------------"
    ############################
    # Removing Duplicates if not using TempDB
    ############################
    if ($DontUseTempDB) {
        # Nothing to do, this table is supposed to have multiple entries
    }
    else {
        ############################
        # Merging if using TempDB
        ############################
        Write-Host "MergingTableInTempDB: $TempTableName"
        Start-Sleep 3
        # Creating SQL query
        $SQLMergeTable = "MERGE $SQLDB.dbo.$SQLTable Target
USING tempdb.dbo.$TempTableName Source
ON (Target.ObjectID = Source.ObjectID)
WHEN MATCHED 
     THEN UPDATE
     SET    Target.RSCInstance = Source.RSCInstance,
            Target.Object = Source.Object,
            Target.ObjectCDMID = Source.ObjectCDMID, 
			Target.Type = Source.Type,
            Target.RubrikCluster = Source.RubrikCluster, 
            Target.RubrikClusterID = Source.RubrikClusterID,
            Target.SLADomain = Source.SLADomain,
            Target.SLADomainID = Source.SLADomainID, 
            Target.ProtectionStatus = Source.ProtectionStatus,
            Target.ComplianceStatus = Source.ComplianceStatus, 
            Target.ReportOnCompliance = Source.ReportOnCompliance,
            Target.ProtectedOn = Source.ProtectedOn,
            Target.IsRelic = Source.IsRelic,
            Target.TotalSnapshots = Source.TotalSnapshots,
            Target.ReplicatedSnaphots = Source.ReplicatedSnaphots,
            Target.ArchivedSnapshots = Source.ArchivedSnapshots,
            Target.LastSnapshot = Source.LastSnapshot,
            Target.HoursSince = Source.HoursSince,
            Target.PendingFirstFull = Source.PendingFirstFull,
            Target.Replicated = Source.Replicated,
            Target.ReplicaType = Source.ReplicaType,
            Target.LastReplicatedSnapshot = Source.LastReplicatedSnapshot,
            Target.LastArchivedSnapshot = Source.LastArchivedSnapshot,
            Target.LastUpdated = Source.LastUpdated,
            Target.URL = Source.URL
WHEN NOT MATCHED BY TARGET
THEN INSERT (RSCInstance, Object, ObjectID, ObjectCDMID, Type, Location,
            RubrikCluster, RubrikClusterID, SLADomain, SLADomainID,
            ProtectionStatus, ComplianceStatus, ReportOnCompliance, ProtectedOn, IsRelic,
            TotalSnapshots, ReplicatedSnaphots, ArchivedSnapshots, LastSnapshot, HoursSince, PendingFirstFull,
            Replicated, ReplicaType, LastReplicatedSnapshot, LastArchivedSnapshot,
            LastUpdated, URL)
     VALUES (Source.RSCInstance, Source.Object, Source.ObjectID, Source.ObjectCDMID, Source.Type, Source.Location,
            Source.RubrikCluster, Source.RubrikClusterID, Source.SLADomain, Source.SLADomainID,
            Source.ProtectionStatus, Source.ComplianceStatus, Source.ReportOnCompliance, Source.ProtectedOn, Source.IsRelic,
            Source.TotalSnapshots, Source.ReplicatedSnaphots, Source.ArchivedSnapshots, Source.LastSnapshot, Source.HoursSince, Source.PendingFirstFull,
            Source.Replicated, Source.ReplicaType, Source.LastReplicatedSnapshot, Source.LastArchivedSnapshot,
            Source.LastUpdated, Source.URL);"
        # Run SQL query
        try {
            Invoke-Sqlcmd -Query $SQLMergeTable -ServerInstance $SQLInstance -QueryTimeout 300 | Out-Null
            $SQLMergeSuccess = $TRUE
        }
        catch {
            $SQLMergeSuccess = $FALSE
            $Error[0] | Format-List -Force
        }
        ##################################
        # SQL - Deleting Temp Table
        ##################################
        if ($SQLMergeSuccess -eq $TRUE) {
            # Creating SQL query
            $SQLDropTable = "USE tempdb;
DROP TABLE $TempTableName;"
            # Run SQL query
            try {
                Invoke-Sqlcmd -Query $SQLDropTable -ServerInstance $SQLInstance -QueryTimeout 300 | Out-Null
            }
            catch {
                $Error[0] | Format-List -Force
            }
            # Logging
            Write-Host "----------------------------------
DroppedTableInTempDB: $TempTableName
----------------------------------"
        }
        else {
            # Logging
            Write-Host "----------------------------------
NotDroppedTableInTempDB: $TempTableName
SQLMergeSuccess: $SQLMergeSuccess
----------------------------------"	
        }
        Start-Sleep 2
        # End of bypass for using tempDB below
    }
    # End of bypass for using tempDB above
    ##########################
    # Benching
    ##########################
    $ScriptEnd = Get-Date
    if (($ScriptStart -ne $null) -and ($ScriptEnd -ne $null)) {
        $Timespan = New-TimeSpan -Start $ScriptStart -End $ScriptEnd
        $ScriptDurationSeconds = $Timespan.TotalSeconds
        $ScriptDurationSeconds = [Math]::Round($ScriptDurationSeconds)
        $ScriptDuration = "{0:}" -f $Timespan; $ScriptDuration = $ScriptDuration.Substring(0, 8)
    }
    else {
        $ScriptDuration = 0
    }
    # Calculating seconds per event
    if ($RSCObjectsCount -gt 0) { $SecondsPerObject = $ScriptDurationSeconds / $RSCObjectsCount; $SecondsPerObject = [Math]::Round($SecondsPerObject, 2) }else { $SecondsPerObject = 0 }
    # Logging
    Write-Host "Script Execution Summary
----------------------------------
Start: $ScriptStart
End: $ScriptEnd
CollectedEventsFrom: $TimeRange
TotalObjects: $RSCObjectsCount
Runtime: $ScriptDuration
SecondsPerObject: $SecondsPerObject"
    # Returning null
    return $null
    # End of function
}

