################################################
# Creating the Get-RSCObjectComplianceAll function
################################################
Function Get-RSCObjectComplianceAll {
	
<#
.SYNOPSIS
Checks each protected object has a snapshot/backup within the last 24 hours and for every previous day specified depending on the DaysToReport configured (3 by default).

.DESCRIPTION
Makes the required GraphQL API calls to RSC via Invoke-RestMethod to get the data as described, then creates a usable array of the returned information, removing the need for the PowerShell user to understand GraphQL in order to interact with RSC.

.PARAMETER DaysToReport
The number of days to report back for compliance on each object. If null uses 3 days. Note: the more days you specify the longer it will take to calculate!
.PARAMETER BackupWindowEndHour
The UTC hour at which your backup window ends and you consider the backup a failure. If null it uses 10 for 10am, for 7am use 7, 11am use 11, for 3pm use a 24-hour clock format so 15, 5pm would be 17.
.PARAMETER BackupWindowEndminutes
The UTC minute in addition to the above at which your backup window ends. If null it uses 0 so the window finishes on the hour. If you want to make it half past the hour, use 30 etc, max 59.
.PARAMETER SampleFirst100Objects
If you want to see what this looks like for a sample set of objects use this switch to see the first 100.
.PARAMETER ExcludeSystemDBs
By default all protected objects are included, if you want to exclude MSSQL system DBs (many of them, often not cared about) then use this switch.

.OUTPUTS
Returns an array of all the available information on the GraphQL endpoint in a uniform and usable format.

.EXAMPLE
$AllObjectCompliance = Get-RSCObjectComplianceAll
This returns an array of every protected object and its compliance based on the last backup being within the 24 hours of each day specified.

.NOTES
Author: Joshua Stenhouse
Date: 05/11/2023
#>

################################################
# Paramater Config
################################################
Param (
        $DaysToReport,$BackupWindowStartHour,$BackupWindowStartMinutes,$MaxSnapshots,$ObjectType,$ExcludeObjectType,$SLADomain,
        [Parameter(ParameterSetName="User")][switch]$SampleFirst100Objects,
        [Parameter(ParameterSetName="User")][switch]$ExcludeSystemDBs
      )

# Note: Backup window end hour & minutes controls when the compliance is calculated from. I.E 7 days back from 10am this morning to 10am yesterday.
# This is because checking a backup on a daily basis doesn't work, you could have a backup at 7am on Friday. Does that mean you have a backup of Friday?
# No, the only way to be sure you have a backup for Friday is to check if a backup exists between 10am Friday and 10am Saturday. 

# Setting days to report to be 7 if null
IF($DaysToReport -eq $null){$DaysToReport = 7}

# Auto calculating $MaxSnapshots by maximum snapshots that would be allowed within window
IF($MaxSnapshots -eq $null){$MaxSnapshots = $DaysToReport * 24}

# Setting backup window start hour to default of 8pm if none set
IF($BackupWindowStartHour -eq $null){$BackupWindowStartHour = 20}

# Setting backup window end minutes to b 0 if null
IF($BackupWindowStartMinutes -eq $null){$BackupWindowStartMinutes = 0}

# SQL System DBs
$SystemDBs = "master","model","msdb"

################################################
# Importing Module & Running Required Functions
################################################
# Importing the module is it needs other modules
Import-Module RSCReporting
# Checking connectivity, exiting function with error if not connected
Test-RSCConnection
# Getting objects list if not already pulled as a global variable in this session
IF($RSCGlobalObjects -eq $null)
{
IF($ObjectType -eq $null){$RSCObjects = Get-RSCObjects;$Global:RSCGlobalObjects = $RSCObjects}ELSE{$RSCObjects = Get-RSCObjects -ObjectType $ObjectType}
}
ELSE
{
$RSCObjects = $RSCGlobalObjects
}
# Filtering for protected objects
# $ProtectedObjects = Get-RSCObjects | Where-Object {$_.ProtectionStatus -eq "Protected"}
$ProtectedObjects = $RSCObjects | Where-Object {$_.ReportOnCompliance -eq $TRUE}
# Filtering for object type if used
IF($ObjectType -ne $null){$ProtectedObjects = $ProtectedObjects | Where-Object {$_.Type -eq $ObjectType}}
# Reducing to sample data set if switch used
IF($SampleFirst100Objects){$ProtectedObjects = $ProtectedObjects | Select-Object -First 100}
# Excluing System DBs if switch used
IF($ExcludeSystemDBs){$ProtectedObjects = $ProtectedObjects | Where-Object {$SystemDBs -notcontains $_.Object}}
# Filtering to remove objects if used
IF($ExcludeObjectType -ne $null){$ProtectedObjects = $ProtectedObjects | Where-Object {$_.Type -ne $ExcludeObjectType}}
# Filtering for SLAdomain if used
IF($SLADomain -ne $null){$ProtectedObjects = $ProtectedObjects | Where-Object {$_.SLADomain -eq $SLADomain}}
# Counting
$ProtectedObjectsCount = $ProtectedObjects | Measure-Object | Select-Object -ExpandProperty Count
$ProtectedObjectsCounter = 0
# Getting MSSQL DBs (need the DAG IDs)
$RSCMSSQLDBs = Get-RSCMSSQLDatabases
$RSCMSSQLDBIDs = $RSCMSSQLDBs | Select-Object DBID
######################################################
# Creating Arrays & Getting Date
######################################################
# Array for storing & returning results
$ObjectCompliance = [System.Collections.ArrayList]@()
$ObjectSnapshots = [System.Collections.ArrayList]@()
$ObjectComplianceSummary = [System.Collections.ArrayList]@()
# Taking 1 day off as count starts at 0
$DaysToReportAdjusted = $DaysToReport - 1
# Creating range for days selected
$Days = 0..$DaysToReportAdjusted
# Creating array to store dates
$DateRanges = @()
# Getting date to determine compliance
$Window = Get-Date -Hour $BackupWindowStartHour -Minute $BackupWindowStartMinutes -Second 00
# For each Day getting date range
ForEach ($Day in $Days)
{
# Getting start date for range
$StartDate = $Window.AddDays(-$Day)
# Deciding if last day (used for SQL query)
IF ($Day -eq $DaysToReport)
{
$IsLastDay = $TRUE
}
ELSE
{
$IsLastDay = $FALSE
}
# Getting end date for range
$EndDate = $StartDate.AddDays(-1)
# Creating string for HTML report
$DateString = $StartDate.ToString("dd-MMM")
# Getting day in short format
$DateDay = $StartDate.ToString("ddd")
# Getting long format
$DateFullString = $StartDate.ToString("dd-MMM-yy")
# Adding array
$DateRange = New-Object PSObject
$DateRange | Add-Member -MemberType NoteProperty -Name "Day" -Value $Day
$DateRange | Add-Member -MemberType NoteProperty -Name "Date" -Value $DateFullString
$DateRange | Add-Member -MemberType NoteProperty -Name "DateStart" -Value $StartDate
$DateRange | Add-Member -MemberType NoteProperty -Name "DateEnd" -Value $EndDate
$DateRange | Add-Member -MemberType NoteProperty -Name "DateHTML" -Value $DateString
$DateRange | Add-Member -MemberType NoteProperty -Name "DayHTML" -Value $DateDay
$DateRange | Add-Member -MemberType NoteProperty -Name "IsLastDay" -Value $IsLastDay
$DateRanges += $DateRange
}
################################################
# Running Main Function
################################################
ForEach($ProtectedObject in $ProtectedObjects)
{
$ProtectedObjectsCounter++
# Setting variables
$ProtectedObjectName = $ProtectedObject.Object
$ProtectedObjectID = $ProtectedObject.ObjectID
$ProtectedObjectType = $ProtectedObject.Type
$ProtectedObjectLocation = $ProtectedObject.Location
$ProtectedObjectRubrikCluster = $ProtectedObject.RubrikCluster
$ProtectedObjectRubrikClusterID = $ProtectedObject.RubrikClusterID
$ProtectedObjectSLADomain = $ProtectedObject.SLADomain
$ProtectedObjectSLADomainID = $ProtectedObject.SLADomainID
# Logging
Write-Host "ProcessingObject:$ProtectedObjectsCounter/$ProtectedObjectsCount Type:$ProtectedObjectType SLA:$ProtectedObjectSLADomain"
# Overriding objectID if MSSQL, if ID matches, if so, overriding
IF($ProtectedObjectType -eq "Mssql")
{
IF($RSCMSSQLDBIDs -match $ProtectedObjectID)
{
# ProtectedObjectID is an mssql DB, need to use the DAG ID instead (stupid design decision by MSSQL team)
$ProtectedObjectDBID = $ProtectedObjectID
$ProtectedObjectID = $RSCMSSQLDBs | Where-Object {$_.DBID -eq $ProtectedObjectID} | Select-Object -ExpandProperty DAGID
}
}
# Note: for "sortOrder" = use ASC for oldest snapshots first, DESC for newest snapshots first 
$RSCGraphQL = @{"operationName" = "SnapshotOfASnappableConnection";

"variables" = @{
"workloadId" = "$ProtectedObjectID"
"sortOrder" = "DESC"
"first" = $MaxSnapshots
};

"query" = "query SnapshotOfASnappableConnection(`$workloadId: String!, `$first: Int, `$sortOrder: SortOrder) {
  snapshotOfASnappableConnection(workloadId: `$workloadId, first: `$first, sortOrder: `$sortOrder) {
    nodes {
      ... on CdmSnapshot {
        id
        date
        expirationDate
        __typename
      }
      ... on PolarisSnapshot {
        id
        date
        expirationDate
        __typename
      }
    }
  }
}"
}
################################################
# API Call To RSC GraphQL URI
################################################
# Querying API
Try
{
$ObjectSnapshotsResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Headers $RSCSessionHeader -Body $($RSCGraphQL | ConvertTo-JSON -Depth 10)
$ObjectSnapshotsToProcess = $ObjectSnapshotsResponse.data.snapshotOfASnappableConnection.nodes
}
Catch
{
$ErrorMessage = $_.ErrorDetails; "ERROR: $ErrorMessage"
}
# Setting the object ID back to the DB ID rather than the DAG if MSSQL, otherwise it breaks URLs etc
IF($ProtectedObjectType -eq "Mssql")
{
$ProtectedObjectID = $ProtectedObjectDBID
}
# Creating array
$ThisObjectSnapshots = [System.Collections.ArrayList]@()
# Processing snapshots
ForEach ($ObjectSnapshot in $ObjectSnapshotsToProcess)
{
# Getting snapshot data
$SnapshotDateUNIX = $ObjectSnapshot.date
$SnapshotID = $ObjectSnapshot.id
# Converting
$SnapshotDate = Convert-RSCUNIXTime $SnapshotDateUNIX
# Adding
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "Date" -Value $SnapshotDate
$Object | Add-Member -MemberType NoteProperty -Name "SnapshotID" -Value $SnapshotID
$Object | Add-Member -MemberType NoteProperty -Name "ObjectID" -Value $ProtectedObjectID
$Object | Add-Member -MemberType NoteProperty -Name "MaxSnapshots" -Value $MaxSnapshots
$ThisObjectSnapshots.Add($Object) | Out-Null
$ObjectSnapshots.Add($Object) | Out-Null
}
##################################
# Calculating Backups For Each DateRange in DateRanges
##################################
# Getting backup compliance for each day
ForEach ($DateRange in $DateRanges)
{
# Setting variables
$Day = $DateRange.Day
$Date = $DateRange.Date
$DayHTML = $DateRange.DayHTML
$DateHTML = $DateRange.DateHTML
$DateRangeStart = $DateRange.DateStart
$DateRangeEnd = $DateRange.DateEnd
# Selecting record
$ObjectBackup = $ThisObjectSnapshots | Where-Object {(($_.Date -le $DateRangeStart) -and ($_.Date -ge $DateRangeEnd))} | Select-Object -First 1
$ObjectSnapshotID = $ObjectBackup.SnapshotID
$ObjectSnapshotDate = $ObjectBackup.Date
#  Only calculating results if any backups exist, else setting to fails
IF ($ObjectBackup -eq $null)
{
$ObjectBackupDay = $FALSE
$ObjectBackupFoundDay = 0
$ObjectBackupNotFoundDay = 1
}
ELSE
{
# Setting backup found
$ObjectBackupFoundDay = 1
$ObjectBackupNotFoundDay = 0
$ObjectBackupDay = $TRUE
# End of bypass for no backups exist
}
# End of bypass for no backups exist
##################################
# Adding to ObjectComplianceDates array
##################################
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
$Object | Add-Member -MemberType NoteProperty -Name "Object" -Value $ProtectedObjectName
$Object | Add-Member -MemberType NoteProperty -Name "ObjectID" -Value $ProtectedObjectID
$Object | Add-Member -MemberType NoteProperty -Name "Type" -Value $ProtectedObjectType
$Object | Add-Member -MemberType NoteProperty -Name "Location" -Value $ProtectedObjectLocation
$Object | Add-Member -MemberType NoteProperty -Name "SLADomain" -Value $ProtectedObjectSLADomain
$Object | Add-Member -MemberType NoteProperty -Name "SLADomainID" -Value $ProtectedObjectSLADomainID
$Object | Add-Member -MemberType NoteProperty -Name "RubrikCluster" -Value $ProtectedObjectRubrikCluster
$Object | Add-Member -MemberType NoteProperty -Name "RubrikClusterID" -Value $ProtectedObjectRubrikClusterID
$Object | Add-Member -MemberType NoteProperty -Name "DayCounter" -Value $Day
$Object | Add-Member -MemberType NoteProperty -Name "BackupDate" -Value $Date
$Object | Add-Member -MemberType NoteProperty -Name "RangeStart" -Value $DateRangeStart
$Object | Add-Member -MemberType NoteProperty -Name "Snapshot" -Value $ObjectSnapshotDate
$Object | Add-Member -MemberType NoteProperty -Name "RangeEnd" -Value $DateRangeEnd
$Object | Add-Member -MemberType NoteProperty -Name "BackupFound" -Value $ObjectBackupFoundDay
$Object | Add-Member -MemberType NoteProperty -Name "BackupNotFound" -Value $ObjectBackupNotFoundDay
$Object | Add-Member -MemberType NoteProperty -Name "DayLabel" -Value $DayHTML
$Object | Add-Member -MemberType NoteProperty -Name "DateLabel" -Value $DateHTML
$Object | Add-Member -MemberType NoteProperty -Name "SnapshotID" -Value $ObjectSnapshotID
# Storing in array
$ObjectCompliance.Add($Object) | Out-Null
# End of for each date in dateranges below
}
# End of for each date in dateranges below
##################################
# Summarizing Per Object Compliance
##################################
# Selecting object info
$ObjectBackups = $ObjectCompliance | Where-Object {$_.ObjectID -eq $ProtectedObjectID} | Sort-Object DayCounter
# Summarizing data
$ObjectDays = $ObjectBackups | Measure-Object | Select-Object -Expandproperty Count
$ObjectStrikeCount = $ObjectBackups | Select-Object -ExpandProperty BackupNotFound | Measure-Object -Sum | Select-Object -Expandproperty Sum
$ObjectBackupCount = $ObjectBackups | Select-Object -ExpandProperty BackupFound | Measure-Object -Sum | Select-Object -Expandproperty Sum
# Summarizing data for last 24 hours
$ObjectLastDayBackups = $ObjectBackups | Where-Object {$_.DayCounter -eq 0}
$ObjectLastDayStrikeCount = $ObjectLastDayBackups | Select-Object -ExpandProperty BackupNotFound | Measure-Object -Sum | Select-Object -Expandproperty Sum
$ObjectLastDayBackupCount = $ObjectLastDayBackups | Select-Object -ExpandProperty BackupFound | Measure-Object -Sum | Select-Object -Expandproperty Sum
# Most recent backup
$ObjectLastBackup = $ObjectBackups | Where-Object {$_.Snapshot -ne $null} | Select-Object -ExpandProperty Snapshot -First 1
$UTCDateTime = [System.DateTime]::UtcNow
IF($ObjectLastBackup -ne $null){$ObjectLastBackupTimespan = New-TimeSpan -Start $ObjectLastBackup -End $UTCDateTime;$ObjectLastBackupHoursSince = $ObjectLastBackupTimespan | Select-Object -ExpandProperty TotalHours;$ObjectLastBackupHoursSince = [Math]::Round($ObjectLastBackupHoursSince,1)}ELSE{$ObjectLastBackupHoursSince = $null}
# Getting object URL
$ObjectURL = Get-RSCObjectURL -ObjectType $ProtectedObjectType -ObjectID $ProtectedObjectID
# Adding
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
$Object | Add-Member -MemberType NoteProperty -Name "Object" -Value $ProtectedObjectName
$Object | Add-Member -MemberType NoteProperty -Name "ObjectID" -Value $ProtectedObjectID
$Object | Add-Member -MemberType NoteProperty -Name "Type" -Value $ProtectedObjectType
$Object | Add-Member -MemberType NoteProperty -Name "Location" -Value $ProtectedObjectLocation
$Object | Add-Member -MemberType NoteProperty -Name "SLADomain" -Value $ProtectedObjectSLADomain
$Object | Add-Member -MemberType NoteProperty -Name "SLADomainID" -Value $ProtectedObjectSLADomainID
$Object | Add-Member -MemberType NoteProperty -Name "RubrikCluster" -Value $ProtectedObjectRubrikCluster
$Object | Add-Member -MemberType NoteProperty -Name "RubrikClusterID" -Value $ProtectedObjectRubrikClusterID
$Object | Add-Member -MemberType NoteProperty -Name "Days" -Value $DaysToReport
$Object | Add-Member -MemberType NoteProperty -Name "Strikes" -Value $ObjectStrikeCount
$Object | Add-Member -MemberType NoteProperty -Name "Backups" -Value $ObjectBackupCount
$Object | Add-Member -MemberType NoteProperty -Name "Last24HoursStrikes" -Value $ObjectLastDayStrikeCount
$Object | Add-Member -MemberType NoteProperty -Name "Last24HoursBackups" -Value $ObjectLastDayBackupCount
$Object | Add-Member -MemberType NoteProperty -Name "LastBackup" -Value $ObjectLastBackup
$Object | Add-Member -MemberType NoteProperty -Name "HoursSince" -Value $ObjectLastBackupHoursSince
$Object | Add-Member -MemberType NoteProperty -Name "URL" -Value $ObjectURL
$ObjectComplianceSummary.Add($Object) | Out-Null
# End of for each object below
}
# End of for each object above

##########################
# Setting Global Variables
##########################
$Global:RSCObjectCompliance = $ObjectCompliance
$Global:RSCObjectSnapshots = $ObjectSnapshots
$Global:RSCDateRanges = $DateRanges

# Returning Result
Return $ObjectComplianceSummary
}