################################################
# Creating the Get-RSCObjectCompliance function
################################################
Function Get-RSCObjectCompliance {
	
<#
.SYNOPSIS
A Rubrik Security Cloud (RSC) Reporting Module Function for getting compliance of backups per object.

.DESCRIPTION
This function checks if the object has a backup within the days to report specified and returns an array with the result.

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.PARAMETER ObjectID
A valid ObjectID of the protected object within RSC.
.PARAMETER DaysToReport
Number of days to report back, it will take a default backup window of 10am to 10sm, unless you specify differently with the param below.
.PARAMETER BackupWindowEndHour
The end hour of your backup window for consideration of a succesful backup. I.E 11am = 11
.PARAMETER BackupWindowEndminutes
The end minutes of your backup window for consideration of a succesful backup. I.E 11:30am = 30 + configuring the above.

.OUTPUTS
Returns an array of all the available information on the GraphQL endpoint in a uniform and usable format.

.EXAMPLE
Get-RSCObjectCompliance -ObjectID "dqwdqdoj-dqwdwd-wwwdwd-wdwd" -DaysToReport 5
This example checks if the object has a backup within the days to report specified.

.NOTES
Author: Joshua Stenhouse
Date: 05/11/2023
#>
################################################
# Paramater Config
################################################
Param ([Parameter(Mandatory=$true)]
  [String]$ObjectID,$DaysToReport,$BackupWindowStartHour,$BackupWindowEndminutes)

# Note: Backup window end hour & minutes controls when the compliance is calculated from. I.E 7 days back from 10am this morning to 10am yesterday.
# This is because checking a backup on a daily basis doesn't work, you could have a backup at 7am on Friday. Does that mean you have a backup of Friday?
# No, the only way to be sure you have a backup for Friday is to check if a backup exists between 10am Friday and 10am Saturday. 

# Example: $ObjectCompliance = Get-RSCObjectCompliance -ObjectID "$ObjectID"

# Setting days to report to be 7 if null
IF($DaysToReport -eq $null){$DaysToReport = 7}

# Auto calculating $MaxSnapshots by maximum snapshots that would be allowed within window
$MaxSnapshots = $DaysToReport * 24

# Setting backup window start hour to be 8pm if null
IF($BackupWindowStartHour -eq $null){$BackupWindowStartHour = 20}

# Setting backup window start minutes to b 0 if null
IF($BackupWindowStartMinutes -eq $null){$BackupWindowStartMinutes = 0}

################################################
# Importing Module & Running Required Functions
################################################
# Importing the module is it needs other modules
Import-Module RSCReporting
# Checking connectivity, exiting function with error if not connected
Test-RSCConnection
######################################################
# Creating Arrays & Getting Date
######################################################
# Array for storing & returning results
$ObjectCompliance = [System.Collections.ArrayList]@()
# Taking 1 day off as count starts at 0
$DaysToReportAdjusted = $DaysToReport - 1
# Creating range for days selected
$Days = 0..$DaysToReportAdjusted
# Creating array to store dates
$DateRanges = @()
# Getting date to determine compliance
$Window = Get-Date -Hour $BackupWindowStartHour -Minute $BackupWindowStartMinutes -Second 00
# Adding lag days
$Window = $Window.AddDays(-$DaysLag)
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
# Getting MSSQL DBs
$RSCMSSQLDBs = Get-RSCMSSQLDatabases
$RSCMSSQLDBIDs = $RSCMSSQLDBs | Select-Object DBID
# Checking if ID matches, if so, overriding
IF($RSCMSSQLDBIDs -match $ObjectID)
{
# ObjectID is an mssql DB, need to use the DAG ID instead (stupid design decision by MSSQL team)
$ObjectID = $RSCMSSQLDBs | Where-Object {$_.DBID -eq $ObjectID} | Select-Object -ExpandProperty DAGID
}
# Note: for "sortOrder" = use ASC for oldest snapshots first, DESC for newest snapshots first 
$RSCGraphQL = @{"operationName" = "SnapshotOfASnappableConnection";

"variables" = @{
"workloadId" = "$ObjectID"
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
# Creating array
$ObjectSnapshots = [System.Collections.ArrayList]@()
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
$Object | Add-Member -MemberType NoteProperty -Name "ObjectID" -Value $ObjectID
$Object | Add-Member -MemberType NoteProperty -Name "MaxSnapshots" -Value $MaxSnapshots
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
$ObjectBackup = $ObjectSnapshots | Where-Object {(($_.Date -le $DateRangeStart) -and ($_.Date -ge $DateRangeEnd))} | Select-Object -First 1
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
$Object | Add-Member -MemberType NoteProperty -Name "ObjectID" -Value $ObjectID
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

# Returning Result
Return $ObjectCompliance
}