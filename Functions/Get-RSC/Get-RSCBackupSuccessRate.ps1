################################################
# Creating the Get-RSCBackupSuccessRate function
################################################
Function Get-RSCBackupSuccessRate {
	
<#
.SYNOPSIS
A Rubrik Security Cloud (RSC) Reporting Module Function getting the backup success rate of all objects over the days specified.

.DESCRIPTION
Makes the required GraphQL API calls to RSC via Invoke-RestMethod to get the data as described, then creates a usable array of the returned information, removing the need for the PowerShell user to understand GraphQL in order to interact with RSC.

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.PARAMETER SkipDays
If you want to start your count back from a few days ago use this. I.E it's Tuesday and you want to count back from Sunday, you'd set this to 1 to skip Mon-Tue.
.PARAMETER DaysToReport
Number of days to report back, it will take a default backup window of 10am to 10sm, unless you specify differently with the param below.
.PARAMETER BackupWindowEndHour
The end hour of your backup window for consideration of a succesful backup. I.E 11am = 11
.PARAMETER BackupWindowEndminutes
The end minutes of your backup window for consideration of a succesful backup. I.E 11:30am = 30 + configuring the above.
.PARAMETER ReportLastMonth
Overrides skipdays and daystoreport to report on the last calendar month, calculating the skip days and days to report for you based on the number of days in that month and how many days since.
.PARAMETER ReportMonthToDate
Overrides skipdays and daystoreport to report on the current calendar month to date, calculating the skip days and days to report for you based on the number of days in that month you are on.
.PARAMETER ExcludeNonDailyBackups
Use to remove objects from calculation that aren't backed up at least once per day (I.E weekly backup only), or backed up once and never again in an SLA.

.OUTPUTS
Returns an array of all the available information on the GraphQL endpoint in a uniform and usable format.

.EXAMPLE
Get-RSCBackupSuccessRate -DaysToReport 7 -ExcludeNonDailyBackups
This example gets the backup success rate of all objects over the last 7 days, ignoring any object that isn't backed up at least once per day.

.NOTES
Author: Joshua Stenhouse
Date: 05/11/2023
#>
################################################
# Paramater Config
################################################
Param (
        $DaysToReport,$SkipDays,$BackupWindowEndHour,$BackupWindowEndminutes,
        [Parameter(ParameterSetName="User")][switch]$ReportLastMonth,
        [Parameter(ParameterSetName="User")][switch]$ReportMonthToDate,
        [Parameter(ParameterSetName="User")][switch]$ExcludeNonDailyBackups
        )

# Note: Backup window end hour & minutes controls when the compliance is calculated from. I.E 7 days back from 10am this morning to 10am yesterday.
# This is because checking a backup on a daily basis doesn't work, you could have a backup at 7am on Friday. Does that mean you have a backup of Friday?
# No, the only way to be sure you have a backup for Friday is to check if a backup exists between 10am Friday and 10am Saturday. 

# Getting current date in UTC
$UTCDateTime = [System.DateTime]::UtcNow

# Setting days to report to be 7 if null
IF($DaysToReport -eq $null){$DaysToReport = 1}

# Auto calculating $MaxSnapshots by maximum snapshots that would be allowed within window
$MaxSnapshots = [int]$DaysToReport * 24
IF($MaxSnapshots -ge 1000){$MaxSnapshots = 1000}

# Setting backup window end hour to be 10am if null
IF($BackupWindowEndHour -eq $null){$BackupWindowEndHour = 10}

# Setting backup window end minutes to b 0 if null
IF($BackupWindowEndminutes -eq $null){$BackupWindowEndminutes = 0}

# If report last month, auto calculates days in the last month
IF($ReportLastMonth)
{
# Calculating days in the last month
$Now = GET-DATE -Hour 0 -Minute 0 -Second 0
$PreviousMonth = $Now.AddMonths(-1)
$FirstDayofMonth = GET-DATE $PreviousMonth -Day 1
$LastDayOfMonth = GET-DATE $FirstDayofMonth.AddMonths(1).AddSeconds(-1)
$FirstDayOfThisMonth = GET-DATE $FirstDayofMonth.AddMonths(1)
$DaysOfMonth = New-TimeSpan -Start $FirstDayofMonth -End $LastDayOfMonth | Select-Object -ExpandProperty TotalDays; $DaysOfMonth = [Math]::Round($DaysOfMonth,0)
$DaysToReport = $DaysOfMonth
$MaxSnapshots = 1000 # setting this to try ensure snapshots will cover range being reported on
}

# If reporting month to date, calculating days in current month, you can always select DailyBackupSuccessRate global variable so you don't have to calculate twice
IF($ReportMonthToDate)
{
# Calculating days in the current month
$Now = GET-DATE -Hour 0 -Minute 0 -Second 0
$FirstDayofMonth = GET-DATE $Now -Day 1
$DaysOfMonth = New-TimeSpan -Start $FirstDayofMonth -End $Now | Select-Object -ExpandProperty TotalDays; $DaysOfMonth = [Math]::Round($DaysOfMonth,0)
$DaysToReport = $DaysOfMonth
$MaxSnapshots = 1000 # setting this to try ensure snapshots will cover range being reported on
}

################################################
# Importing Module & Running Required Functions
################################################
# Importing the module is it needs other modules
Import-Module RSCReporting
# Checking connectivity, exiting function with error if not connected
Test-RSCConnection
# Getting All SLA Domains
$RSCSLADomains = Get-RSCSLADomains
# Getting All Objects 
$RSCObjectsList = Get-RSCObjects
# Filtering for protectec objects
$RSCProtectedObjects = $RSCObjectsList | Where-Object {$_.ReportOnCompliance -eq $TRUE} # | Select-Object -First 100
$RSCProtectedObjectsCount = $RSCProtectedObjects | Measure-Object | Select-Object -ExpandProperty Count
######################################################
# Creating Arrays & Getting Date
######################################################
$AllObjectBackups = [System.Collections.ArrayList]@()
$AllObjectSuccessRate = [System.Collections.ArrayList]@()
# Taking 1 day off as count starts at 0
$DaysToReportAdjusted = $DaysToReport - 1
# Creating range for days selected
$Days = 0..$DaysToReportAdjusted
# Creating array to store dates
$DateRanges = @()
$DateRangeCounter = 0
# Getting date to determine compliance
IF($ReportLastMonth)
{
$Window = Get-Date $FirstDayofMonth.AddMonths(1) -Hour $BackupWindowEndHour -Minute $BackupWindowEndminutes -Second 00
}
ELSE
{
$Window = Get-Date -Hour $BackupWindowEndHour -Minute $BackupWindowEndminutes -Second 00
}
# Adding skip last X days if specified
IF($SkipDays -ne $null){$Window = $Window.AddDays(-$SkipDays)}
# For each Day getting date range
ForEach ($Day in $Days)
{
# Incrementing counter
$DateRangeCounter++
# Getting start date for range
$StartDate = $Window.AddDays(-$Day)
# Setting date range start
IF($DateRangeCounter -eq 1){$DateRangeStart = $StartDate}
# Deciding if last day (used for SQL query)
IF ($Day -eq $DaysToReport){$IsLastDay = $TRUE}ELSE{$IsLastDay = $FALSE}
# Getting end date for range
$EndDate = $StartDate.AddDays(-1)
# Setting date range end, will continously overwrite until last
$DateRangeEnd = $EndDate
# Creating string for HTML report
$DateString = $EndDate.ToString("dd-MMM")
# Getting day in short format
$DateDay = $EndDate.ToString("ddd")
# Getting long format
$DateFullString = $EndDate.ToString("dd-MMM-yy")
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
# Selecting dates
$ReportingFrom = $DateRanges | Select-Object -ExpandProperty DateEnd -Last 1
$ReportingTo = $DateRanges | Select-Object -ExpandProperty DateStart -First 1
# Logging
Write-Host "-----------------------------------------
RSC Backup Success Rate Calculator
-----------------------------------------
TotalProtectedObjects: $RSCProtectedObjectsCount
ReportLastMonth: $ReportLastMonth
DaysToReport: $DaysToReport
ReportingFrom: $ReportingFrom
ReportingTo: $ReportingTo
MaxSnapshotsPerObject: $MaxSnapshots
Calculating success rates, this may take a while..
-----------------------------------------"
Start-Sleep 3
################################################
# Running Main Function
################################################
# Counters
$RSCProtectedObjectsCounter = 0
ForEach($RSCProtectedObject in $RSCProtectedObjects)
{
$RSCProtectedObjectsCounter++
# Logging
Write-Host "ProcessingObject: $RSCProtectedObjectsCounter/$RSCProtectedObjectsCount"
# Creating array for the object
$ObjectBackups = [System.Collections.ArrayList]@()
# Setting variables
$ObjectID = $RSCProtectedObject.ObjectID
$ObjectCDMID = $RSCProtectedObject.ObjectCDMID
$ObjectName = $RSCProtectedObject.Object
$ObjectLocation = $RSCProtectedObject.Location
$ObjectType = $RSCProtectedObject.Type
$ObjectSLADomain = $ObjectSLADomainInfo.SLADomain
$ObjectSLADomainID = $ObjectSLADomainInfo.SLADomainID
$ObjectClusterID = $ObjectClusterInfo.RubrikClusterID
$ObjectClusterName = $ObjectClusterInfo.RubrikCluster
# Getting SLA domain detail
$ObjectSLADomainDetail = $RSCSLADomains | Where-Object {$_.SLADomainID -eq $ObjectSLADomainID}
$ObjectSLADomainFrequencyDays = $ObjectSLADomainDetail.FrequencyDays
# Deciding if object should be excluded from calculation or not
IF($ExcludeNonDailyBackups){IF($ObjectSLADomainFrequencyDays -eq 0){$ObjectExclude = $TRUE}ELSE{$ObjectExclude = $FALSE}}ELSE{$ObjectExclude = $FALSE}
# Querying API
$ObjectSnapshots = Get-RSCObjectSnapshots -ObjectID $ObjectID -MaxSnapshots $MaxSnapshots
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
$ObjectBackup = $ObjectSnapshots | Where-Object {(($_.DateUTC -le $DateRangeStart) -and ($_.DateUTC -ge $DateRangeEnd))} | Select-Object -First 1
$ObjectSnapshotID = $ObjectBackup.SnapshotID
$ObjectSnapshotDate = $ObjectBackup.DateUTC
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
$Object | Add-Member -MemberType NoteProperty -Name "ObjectType" -Value $ObjectType
$Object | Add-Member -MemberType NoteProperty -Name "ObjectName" -Value $ObjectName
$Object | Add-Member -MemberType NoteProperty -Name "ObjectID" -Value $ObjectID
$Object | Add-Member -MemberType NoteProperty -Name "DayCounter" -Value $Day
$Object | Add-Member -MemberType NoteProperty -Name "BackupDate" -Value $Date
$Object | Add-Member -MemberType NoteProperty -Name "RangeStart" -Value $DateRangeStart
$Object | Add-Member -MemberType NoteProperty -Name "Snapshot" -Value $ObjectSnapshotDate
$Object | Add-Member -MemberType NoteProperty -Name "RangeEnd" -Value $DateRangeEnd
$Object | Add-Member -MemberType NoteProperty -Name "Backups" -Value $ObjectBackupFoundDay
$Object | Add-Member -MemberType NoteProperty -Name "Strikes" -Value $ObjectBackupNotFoundDay
$Object | Add-Member -MemberType NoteProperty -Name "DayLabel" -Value $DayHTML
$Object | Add-Member -MemberType NoteProperty -Name "DateLabel" -Value $DateHTML
$Object | Add-Member -MemberType NoteProperty -Name "SnapshotID" -Value $ObjectSnapshotID
$Object | Add-Member -MemberType NoteProperty -Name "SLADomain" -Value $ObjectSLADomain
$Object | Add-Member -MemberType NoteProperty -Name "SLADomainID" -Value $ObjectSLADomainID
$Object | Add-Member -MemberType NoteProperty -Name "RubrikCluster" -Value $ObjectClusterName
$Object | Add-Member -MemberType NoteProperty -Name "RubrikClusterID" -Value $ObjectClusterID
# Storing in array
IF($ObjectExclude -eq $FALSE){$ObjectBackups.Add($Object) | Out-Null}
IF($ObjectExclude -eq $FALSE){$AllObjectBackups.Add($Object) | Out-Null}
# End of for each date in dateranges below
}
# End of for each date in dateranges below
##################################
# Summarizing Object
##################################
# Summarizing data
$ObjectBackupCount = $ObjectBackups | Select-Object -ExpandProperty Backups | Measure-Object -Sum | Select-Object -Expandproperty Sum
$ObjectStrikeCount = $ObjectBackups | Select-Object -ExpandProperty Strikes | Measure-Object -Sum | Select-Object -Expandproperty Sum
# Calculating success rate
$ObjectBackupSuccessPC = ($ObjectBackupCount / $DaysToReport).ToString("P")
IF($ObjectBackupSuccessPC -eq "100.00%"){$ObjectBackupSuccessPC = "100%"}
$ObjectBackupSuccessINT = $ObjectBackupSuccessPC.Replace("%","")
# Adding
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
$Object | Add-Member -MemberType NoteProperty -Name "ObjectType" -Value $ObjectType
$Object | Add-Member -MemberType NoteProperty -Name "ObjectName" -Value $ObjectName
$Object | Add-Member -MemberType NoteProperty -Name "ObjectID" -Value $ObjectID
$Object | Add-Member -MemberType NoteProperty -Name "Days" -Value $DaysToReport
$Object | Add-Member -MemberType NoteProperty -Name "Strikes" -Value $ObjectStrikeCount
$Object | Add-Member -MemberType NoteProperty -Name "Backups" -Value $ObjectBackupCount
$Object | Add-Member -MemberType NoteProperty -Name "SuccessRate" -Value $ObjectBackupSuccessPC
$Object | Add-Member -MemberType NoteProperty -Name "SuccessRateINT" -Value $ObjectBackupSuccessINT
$Object | Add-Member -MemberType NoteProperty -Name "SLADomain" -Value $ObjectSLADomain
$Object | Add-Member -MemberType NoteProperty -Name "SLADomainID" -Value $ObjectSLADomainID
$Object | Add-Member -MemberType NoteProperty -Name "SLAMinFrequencyPerDay" -Value $ObjectSLADomainFrequencyDays
$Object | Add-Member -MemberType NoteProperty -Name "RubrikCluster" -Value $ObjectClusterName
$Object | Add-Member -MemberType NoteProperty -Name "RubrikClusterID" -Value $ObjectClusterID
IF($ObjectExclude -eq $FALSE){$AllObjectSuccessRate.Add($Object) | Out-Null}
# End of for each protected object below
}
# End of for each protected object above
##################################
# Summarizing Objects by type
##################################
# Creating array for the object
$ObjectTypeSuccessRate = [System.Collections.ArrayList]@()
# Selecting unique objects
$ObjectTypes = $AllObjectBackups | Select-Object -ExpandProperty ObjectType -Unique
# For each object type
ForEach($ObjectType in $ObjectTypes)
{
# Selecting data
$ObjectTypeBackups = $AllObjectBackups | Where-Object {$_.ObjectType -eq $ObjectType}
$ObjectTypeObjectsCount = $ObjectTypeBackups | Select-Object -ExpandProperty ObjectID -Unique | Measure-Object | Select-Object -ExpandProperty Count
$ObjectTypeExpectedBackupCount = $ObjectTypeObjectsCount * $DaysToReport
# Summarizing data
$ObjectTypeTotalBackupCount = $ObjectTypeBackups | Select-Object -ExpandProperty Backups | Measure-Object -Sum | Select-Object -Expandproperty Sum
$ObjectTypeTotalStrikeCount = $ObjectTypeBackups | Select-Object -ExpandProperty Strikes | Measure-Object -Sum | Select-Object -Expandproperty Sum
# Calculating success rate
$ObjectBackupSuccessPC = ($ObjectTypeTotalBackupCount / $ObjectTypeExpectedBackupCount).ToString("P")
IF($ObjectBackupSuccessPC -eq "100.00%"){$ObjectBackupSuccessPC = "100%"}
$ObjectBackupSuccessINT = $ObjectBackupSuccessPC.Replace("%","")
# Adding
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
$Object | Add-Member -MemberType NoteProperty -Name "ObjectType" -Value $ObjectType
$Object | Add-Member -MemberType NoteProperty -Name "ReportDays" -Value $DaysToReport
$Object | Add-Member -MemberType NoteProperty -Name "DateFrom" -Value $ReportingFrom
$Object | Add-Member -MemberType NoteProperty -Name "DateTo" -Value $ReportingTo
$Object | Add-Member -MemberType NoteProperty -Name "ProtectedObjects" -Value $ObjectTypeObjectsCount
$Object | Add-Member -MemberType NoteProperty -Name "ExpectedBackups" -Value $ObjectTypeExpectedBackupCount
$Object | Add-Member -MemberType NoteProperty -Name "Backups" -Value $ObjectTypeTotalBackupCount
$Object | Add-Member -MemberType NoteProperty -Name "Strikes" -Value $ObjectTypeTotalStrikeCount
$Object | Add-Member -MemberType NoteProperty -Name "SuccessRate" -Value $ObjectBackupSuccessPC
$Object | Add-Member -MemberType NoteProperty -Name "SuccessRateINT" -Value $ObjectBackupSuccessINT
$ObjectTypeSuccessRate.Add($Object) | Out-Null
# End of for each object type below
}
# End of for each object type above
##################################
# Summarizing Objects by SLA Domain
##################################
# Creating array for the object
$SLADomainSuccessRate = [System.Collections.ArrayList]@()
# Selecting unique objects
$ObjectSLADomains = $AllObjectBackups | Select-Object -ExpandProperty SLADomain -Unique
# For each object type
ForEach($ObjectSLADomain in $ObjectSLADomains)
{
# Selecting data
$ObjectSLABackups = $AllObjectBackups | Where-Object {$_.SLADomain -eq $ObjectSLADomain}
$ObjectSLAObjectsCount = $ObjectSLABackups | Select-Object -ExpandProperty ObjectID -Unique | Measure-Object | Select-Object -ExpandProperty Count
$ObjectSLAExpectedBackupCount = $ObjectSLAObjectsCount * $DaysToReport
# Getting SLA domain ID
$ObjectSLADomainID = $RSCSLADomains | Where-Object {$_.SLADomain -eq $ObjectSLADomain} | Select-Object -ExpandProperty SLADomainID -First 1
# Summarizing data
$ObjectSLATotalBackupCount = $ObjectSLABackups | Select-Object -ExpandProperty Backups | Measure-Object -Sum | Select-Object -Expandproperty Sum
$ObjectSLATotalStrikeCount = $ObjectSLABackups | Select-Object -ExpandProperty Strikes | Measure-Object -Sum | Select-Object -Expandproperty Sum
# Calculating success rate
$ObjectSLABackupSuccessPC = ($ObjectSLATotalBackupCount / $ObjectSLAExpectedBackupCount).ToString("P")
IF($ObjectSLABackupSuccessPC -eq "100.00%"){$ObjectSLABackupSuccessPC = "100%"}
$ObjectSLABackupSuccessINT = $ObjectSLABackupSuccessPC.Replace("%","")
# Adding
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
$Object | Add-Member -MemberType NoteProperty -Name "SLADomain" -Value $ObjectSLADomain
# $Object | Add-Member -MemberType NoteProperty -Name "SLADomainID" -Value $ObjectSLADomainID 
$Object | Add-Member -MemberType NoteProperty -Name "ReportDays" -Value $DaysToReport
$Object | Add-Member -MemberType NoteProperty -Name "DateFrom" -Value $ReportingFrom
$Object | Add-Member -MemberType NoteProperty -Name "DateTo" -Value $ReportingTo
$Object | Add-Member -MemberType NoteProperty -Name "ProtectedObjects" -Value $ObjectSLAObjectsCount
$Object | Add-Member -MemberType NoteProperty -Name "ExpectedBackups" -Value $ObjectSLAExpectedBackupCount
$Object | Add-Member -MemberType NoteProperty -Name "Backups" -Value $ObjectSLATotalBackupCount
$Object | Add-Member -MemberType NoteProperty -Name "Strikes" -Value $ObjectSLATotalStrikeCount
$Object | Add-Member -MemberType NoteProperty -Name "SuccessRate" -Value $ObjectSLABackupSuccessPC
$Object | Add-Member -MemberType NoteProperty -Name "SuccessRateINT" -Value $ObjectSLABackupSuccessINT
$SLADomainSuccessRate.Add($Object) | Out-Null
# End of for each object type below
}
# End of for each object type above
##################################
# Summarizing Objects by Rubrik Cluster
##################################
# Creating array for the object
$RubrikClusterSuccessRate = [System.Collections.ArrayList]@()
# Selecting unique objects
$ObjectRubrikClusters = $AllObjectBackups | Select-Object -ExpandProperty RubrikCluster -Unique
# For each object type
ForEach($ObjectRubrikCluster in $ObjectRubrikClusters)
{
# Selecting data
$ObjectClusterBackups = $AllObjectBackups | Where-Object {$_.RubrikCluster -eq $ObjectRubrikCluster}
$ObjectClusterObjectsCount = $ObjectClusterBackups | Select-Object -ExpandProperty ObjectID -Unique | Measure-Object | Select-Object -ExpandProperty Count
$ObjectClusterExpectedBackupCount = $ObjectClusterObjectsCount * $DaysToReport
# Getting SLA domain ID
$ObjectSLADomainID = $RSCSLADomains | Where-Object {$_.SLADomain -eq $ObjectSLADomain} | Select-Object -ExpandProperty SLADomainID -First 1
# Summarizing data
$ObjectClusterTotalBackupCount = $ObjectClusterBackups | Select-Object -ExpandProperty Backups | Measure-Object -Sum | Select-Object -Expandproperty Sum
$ObjectClusterTotalStrikeCount = $ObjectClusterBackups | Select-Object -ExpandProperty Strikes | Measure-Object -Sum | Select-Object -Expandproperty Sum
# Calculating success rate
$ObjectClusterBackupSuccessPC = ($ObjectClusterSLATotalBackupCount / $ObjectClusterExpectedBackupCount).ToString("P")
IF($ObjectClusterBackupSuccessPC -eq "100.00%"){$ObjectClusterBackupSuccessPC = "100%"}
$ObjectClusterBackupSuccessINT = $ObjectClusterBackupSuccessPC.Replace("%","")
# Adding
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
$Object | Add-Member -MemberType NoteProperty -Name "RubrikCluster" -Value $ObjectSLADomain
$Object | Add-Member -MemberType NoteProperty -Name "ReportDays" -Value $DaysToReport
$Object | Add-Member -MemberType NoteProperty -Name "DateFrom" -Value $ReportingFrom
$Object | Add-Member -MemberType NoteProperty -Name "DateTo" -Value $ReportingTo
$Object | Add-Member -MemberType NoteProperty -Name "ProtectedObjects" -Value $ObjectSLAObjectsCount
$Object | Add-Member -MemberType NoteProperty -Name "ExpectedBackups" -Value $ObjectSLAExpectedBackupCount
$Object | Add-Member -MemberType NoteProperty -Name "Backups" -Value $ObjectSLATotalBackupCount
$Object | Add-Member -MemberType NoteProperty -Name "Strikes" -Value $ObjectSLATotalStrikeCount
$Object | Add-Member -MemberType NoteProperty -Name "SuccessRate" -Value $ObjectSLABackupSuccessPC
$Object | Add-Member -MemberType NoteProperty -Name "SuccessRateINT" -Value $ObjectSLABackupSuccessINT
$RubrikClusterSuccessRate.Add($Object) | Out-Null
# End of for each object type below
}
# End of for each object type above
####################################################################
# Summarizing All Object Backups For Success Rate
####################################################################
# Creating array for the object
$TotalBackupSuccessRate = [System.Collections.ArrayList]@()
# Calculating totals
$TotalExpectedBackupCount = $RSCProtectedObjectsCount * $DaysToReport
$TotalStrikeCount = $AllObjectSuccessRate | Select-Object -ExpandProperty Strikes | Measure-Object -Sum | Select-Object -Expandproperty Sum
$TotalBackupCount = $AllObjectSuccessRate | Select-Object -ExpandProperty Backups | Measure-Object -Sum | Select-Object -Expandproperty Sum
# Calculating success rate
$TotalBackupSuccessPC = ($TotalBackupCount / $TotalExpectedBackupCount).ToString("P")
IF($TotalBackupSuccessPC -eq "100.00%"){$TotalBackupSuccessPC = "100%"}
$TotalBackupSuccessINT = $TotalBackupSuccessPC.Replace("%","")
# Adding
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
$Object | Add-Member -MemberType NoteProperty -Name "ReportDays" -Value $DaysToReport
$Object | Add-Member -MemberType NoteProperty -Name "DateFrom" -Value $ReportingFrom
$Object | Add-Member -MemberType NoteProperty -Name "DateTo" -Value $ReportingTo
$Object | Add-Member -MemberType NoteProperty -Name "ProtectedObjects" -Value $RSCProtectedObjectsCount
$Object | Add-Member -MemberType NoteProperty -Name "ExpectedBackups" -Value $TotalExpectedBackupCount
$Object | Add-Member -MemberType NoteProperty -Name "TotalBackups" -Value $TotalBackupCount
$Object | Add-Member -MemberType NoteProperty -Name "TotalStrikes" -Value $TotalStrikeCount
$Object | Add-Member -MemberType NoteProperty -Name "SuccessRate" -Value $TotalBackupSuccessPC
$Object | Add-Member -MemberType NoteProperty -Name "SuccessRateINT" -Value $TotalBackupSuccessINT
$TotalBackupSuccessRate.Add($Object) | Out-Null
####################################################################
# Creating Per Day Success Rate Summary for Global Variable
####################################################################
# Creating array for the object
$DailyBackupSuccessRate = [System.Collections.ArrayList]@()
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
# Selecting records
$DailyBackups = $AllObjectBackups | Where-Object {$_.DayCounter -eq $Day}
# Calculating totals
$DailyExpectedBackupCount = $RSCProtectedObjectsCount
$DailyBackupCount = $DailyBackups | Select-Object -ExpandProperty Backups | Measure-Object -Sum | Select-Object -Expandproperty Sum
$DailyStrikeCount = $DailyBackups | Select-Object -ExpandProperty Strikes | Measure-Object -Sum | Select-Object -Expandproperty Sum
# Calculating success rate
$DailyBackupSuccessPC = ($DailyBackupCount / $DailyExpectedBackupCount).ToString("P")
IF($DailyBackupSuccessPC -eq "100.00%"){$DailyBackupSuccessPC = "100%"}
$DailyBackupSuccessINT = $DailyBackupSuccessPC.Replace("%","")
##################################
# Adding to ObjectComplianceDates array
##################################
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
$Object | Add-Member -MemberType NoteProperty -Name "DayCounter" -Value $Day
$Object | Add-Member -MemberType NoteProperty -Name "BackupDate" -Value $Date
$Object | Add-Member -MemberType NoteProperty -Name "RangeStart" -Value $DateRangeStart
$Object | Add-Member -MemberType NoteProperty -Name "RangeEnd" -Value $DateRangeEnd
$Object | Add-Member -MemberType NoteProperty -Name "ProtectedObjects" -Value $RSCProtectedObjectsCount
$Object | Add-Member -MemberType NoteProperty -Name "Backups" -Value $DailyBackupCount
$Object | Add-Member -MemberType NoteProperty -Name "Strikes" -Value $DailyStrikeCount
$Object | Add-Member -MemberType NoteProperty -Name "SuccessRate" -Value $DailyBackupSuccessPC
$Object | Add-Member -MemberType NoteProperty -Name "SuccessRateINT" -Value $DailyBackupSuccessINT
$Object | Add-Member -MemberType NoteProperty -Name "DayLabel" -Value $DayHTML
$Object | Add-Member -MemberType NoteProperty -Name "DateLabel" -Value $DateHTML
# Storing in array
$DailyBackupSuccessRate.Add($Object) | Out-Null
# End of for each date in dateranges below
}
# Logging
Write-Host "-----------------------------------------
Backup success rate calculation completed.
-----------------------------------------
Success rate determined by object have 1 snapshot per day, SLA domain config and events are ignored.

For additional detail of objects, backups etc, all relevant data is stored on the following global variables:

Use BackupSuccessRate for backup success rate
Use ObjectTypeSuccessRate for backup success rate per object type
Use SLADomainSuccessRate for success rate per SLA domain
Use RubrikClusterSuccessRate for success rate per Rubrik cluster
Use DailyBackupSuccessRate for success rate per day
Use AllObjectSuccessRate for summary per protected object
Use AllObjectBackups for each object per day

Function itself will return the BackupSuccessRate."
# Outputting the object backups and summarieslist to global variables for subsequent use
$Global:AllObjectBackups = $AllObjectBackups
$Global:AllObjectSuccessRate = $AllObjectSuccessRate
$Global:DailyBackupSuccessRate = $DailyBackupSuccessRate
$Global:BackupSuccessRate = $TotalBackupSuccessRate
$Global:ObjectTypeSuccessRate = $ObjectTypeSuccessRate
$Global:SLADomainSuccessRate = $SLADomainSuccessRate
$Global:RubrikClusterSuccessRate = $RubrikClusterSuccessRate

# Returning Result
Return $TotalBackupSuccessRate
}