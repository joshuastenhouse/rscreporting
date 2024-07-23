################################################
# Function - Send-RSCReport02MultiDayStrikes - Sending RSC Report
################################################
Function Send-RSCReport02MultiDayStrikes {

<#
.SYNOPSIS
Creates and emails a pre-canned HTML report for multi-day strikes and backups (days missing a backup/snapshot) across all protected objects, also known as a christmas tree report.

.DESCRIPTION
By default reports back 7 days, but configurable via DaysToReport for any timeframe required. Warning: the longer the time frame the longer it will take to run!

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.PARAMETER DaysToReport
The number of days to report on. Typical use cases are 3, 7, 14, or 30 day strike reports.
.PARAMETER EmailSubject
Set the name of the email subject, by default uses "Rubrik Multi-Day Strikes"
.PARAMETER ObjectType
Use Get-RSCObjectTypes for a list of valid params, can be left null to report on all objects (default), don't specify more than 1 but useful for a "MSSQL Strike Report" etc.
.PARAMETER SwitchOrder
If switch is not used, days are shown left to right with left being the most recent. If you prefer right to left, with right most being most recent use this switch.
.PARAMETER ExcludeSystemDBs
If reporting on all objects, or just MSSQL, you might not want to include system DBs (master, model etc) in this report. Use this switch to remove them automatically.
.PARAMETER BackupWindowEndHour
The end hour of your backup window for consideration of a succesful backup. Default is 10am unless you specicy otherwise. I.E 11am = 11
.PARAMETER BackupWindowEndminutes
The end minutes of your backup window for consideration of a succesful backup. I.E 11:30am = 30 + configuring the above.
.PARAMETER EmailTo
The email address to send the report to.
.PARAMETER EmailFrom
The email address the report will be sent from.
.PARAMETER SMTPServer
Your local SMTP server which will accept a relay request from the server you are running this script on (does not send via RSC itself)
.PARAMETER SortByColumnName
The name of a single column heading in the array to sort by. I.E Username
.PARAMETER ExportReportHTML
Creates a HTML file of the report in the $ScriptDirectory specified when connecting to RSC.
.PARAMETER SSLRequired
Switch if you require SSL to send the email via SMTP locally.
.PARAMETER SampleFirst100Objects
If you have a large environment use this to test sampling with a subset.

.OUTPUTS
Logs it's actions and the result of sending the email.

.EXAMPLE
Send-RSCReport02MultiDayStrikes -DaysToReport 3 -EmailSubject "Rubrik 3-Strike Report" -EmailTo "admin@lab.local" -EmailFrom "reporting@lab.local" -SMTPServer "localhost" -ExcludeSystemDBs
Creates a HTML report of all protected object backups within the last 3 days, excluding MSSQL system DBs.

.EXAMPLE
Send-RSCReport02MultiDayStrikes -DaysToReport 7 -ObjectType "VmwareVirtualMachine" -EmailSubject "Rubrik MSSQL 3-Strike Report" -EmailTo "admin@lab.local" -EmailFrom "reporting@lab.local" -SMTPServer "localhost"
Creates a HTML report of all protected VmwareVirtualMachine backups within the last 7 days.

.EXAMPLE
Send-RSCReport02MultiDayStrikes -DaysToReport 7 -ObjectType "Mssql" -EmailSubject "Rubrik MSSQL 3-Strike Report" -EmailTo "admin@lab.local" -EmailFrom "reporting@lab.local" -SMTPServer "localhost" -ExcludeSystemDBs
Creates a HTML report of all protected MSSQL full backups within the last 7 days, excluding MSSQL system DBs.

.EXAMPLE
Send-RSCReport02MultiDayStrikes -DaysToReport 3 -ObjectType "OracleDatabase" -EmailSubject "Rubrik 3-Strike Report" -EmailTo "admin@lab.local" -EmailFrom "reporting@lab.local" -SMTPServer "localhost"
Creates a HTML report of all protected Oracle full backups within the last 3 days.

.EXAMPLE
Send-RSCReport02MultiDayStrikes -DaysToReport 5 -ObjectType "Db2Database" -EmailSubject "Rubrik 3-Strike Report" -EmailTo "admin@lab.local" -EmailFrom "reporting@lab.local" -SMTPServer "localhost"
Creates a HTML report of all protected DB2 full backups within the last 5 days.

.NOTES
Author: Joshua Stenhouse
Date: 05/11/2023
#>
################################################
# Paramater Config
################################################
Param
    (
        $DaysToReport,$EmailTo,$EmailFrom,$EmailSubject,$SMTPServer,$ObjectType,$BackupWindowStartHour,$BackupWindowStartMinutes,$ExcludeObjectType,$SLADomain,
        [Parameter(ParameterSetName="User")][switch]$SwitchOrder,
        [Parameter(ParameterSetName="User")][switch]$UseSymbols,
        [Parameter(ParameterSetName="User")][switch]$SSLRequired,
        [Parameter(ParameterSetName="User")][switch]$ExcludeSystemDBs,
        [Parameter(ParameterSetName="User")][switch]$OnlyShowObjectsWithStrikes,
        [Parameter(ParameterSetName="User")][switch]$OnlyShowObjectsWithAllStrikes,
        [Parameter(ParameterSetName="User")][switch]$SampleFirst100Objects,
        [Parameter(ParameterSetName="User")][switch]$ExportReportHTML
    )


# Email subject
IF($EmailSubject -eq $null){$EmailSubject = "Rubrik Multi-Day Strikes"}

# Report Name
$ReportName = "02-MultiDayStrikes"

# Setting days to report to be 7 if null
IF($DaysToReport -eq $null){$DaysToReport = 7}

# Setting backup window start hour to be 8pm if null
IF($BackupWindowStartHour -eq $null){$BackupWindowStartHour = 20}

# Setting backup window start minutes to b 0 if null
IF($BackupWindowStartMinutes -eq $null){$BackupWindowStartMinutes = 0}

# Setting switch order
IF($SwitchOrder){$SwitchOrder = $TRUE}ELSE{$SwitchOrder = $FALSE}

# If multiple emails passed converting to an array
IF($EmailTo -match """"){$EmailTo = Invoke-Expression $EmailTo}

################################################
# Importing Module & Running Required Functions
################################################
Import-Module RSCReporting
# Getting RSC files
$RSCFiles = Get-RSCModuleFiles
# Getting templates
$RSCTemplates = Get-RSCReportTemplates
# Getting file path of required template
$RSCTemplatePath = $RSCTemplates | Where-Object {$_.Report -match $ReportName} | Select-Object -ExpandProperty FilePath
# Getting logo file included with module
$LogoFile = $RSCFiles | Where-Object {$_.File -match "logo"} | Select-Object -ExpandProperty FilePath -First 1
# Getting the machine time
$SystemDateTime = Get-Date
##################################
# Setting file names required
##################################
IF ($IsLinux -eq $TRUE)
{
$CSVExportDir = $RSCScriptDirectory + "CSVExports/" + $ReportName + "/"
$ReportExportDir = $RSCScriptDirectory + "ReportExports/" + $ReportName + "/"
}
ELSE
{
$CSVExportDir = $RSCScriptDirectory + "CSVExports\" + $ReportName + "\"
$ReportExportDir = $RSCScriptDirectory + "ReportExports\" + $ReportName + "\"
}
##################################
# Creating export directories if not exists
##################################
$ReportExportDirTest = Test-Path $ReportExportDir
IF ($ReportExportDirTest -eq $False)
{
New-Item -Path $ReportExportDir -ItemType "directory" | Out-Null
}
$CSVExportDirTest = Test-Path $CSVExportDir
IF ($CSVExportDirTest -eq $False)
{
New-Item -Path $CSVExportDir -ItemType "directory" | Out-Null
}
###########################
# Getting RSC Data & Template
###########################
IF($SampleFirst100Objects)
{
# Switch set for sample, only getting first 100 objects
$ObjectCompliance = Get-RSCObjectComplianceAll -DaysToReport $DaysToReport -BackupWindowStartHour $BackupWindowStartHour -BackupWindowStartminutes $BackupWindowStartMinutes -SampleFirst100Objects -ObjectType $ObjectType -ExcludeObjectType $ExcludeObjectType -SLADomain $SLADomain
}
ELSE
{
# Deciding if excluding system DBs or not
IF($ExcludeSystemDBs)
{
# Switch set to exclude system DBs, removes them on function
$ObjectCompliance = Get-RSCObjectComplianceAll -DaysToReport $DaysToReport -BackupWindowStartHour $BackupWindowStartHour -BackupWindowStartminutes $BackupWindowStartMinutes -ExcludeSystemDBs -ObjectType $ObjectType -ExcludeObjectType $ExcludeObjectType -SLADomain $SLADomain
}
ELSE
{
# No switches set, getting all objects
$ObjectCompliance = Get-RSCObjectComplianceAll -DaysToReport $DaysToReport -BackupWindowStartHour $BackupWindowStartHour -BackupWindowStartminutes $BackupWindowStartMinutes -ObjectType $ObjectType -ExcludeObjectType $ExcludeObjectType -SLADomain $SLADomain
}
}
# Importing template
$HTMLCode = Import-RSCReportTemplate $RSCTemplatePath
####################################################################
# Calculating totals
####################################################################
"----------------------------
Calculating Totals & Creating HTML Report"
# Totals
$ObjectCount = $ObjectCompliance | Select-Object ObjectID -Unique | Measure-Object | Select-Object -ExpandProperty Count
$ObjectClusterCount = $ObjectCompliance | Select-Object ClusterID -Unique | Measure-Object | Select-Object -ExpandProperty Count
$ObjectSLADomainCount = $ObjectCompliance | Select-Object SLADomainID -Unique | Measure-Object | Select-Object -ExpandProperty Count
# Totals
$TotalBackups = $ObjectCompliance | Select-Object -ExpandProperty Backups | Measure-Object -Sum | Select-Object -ExpandProperty Sum
$TotalStrikes = $ObjectCompliance | Select-Object -ExpandProperty Strikes | Measure-Object -Sum | Select-Object -ExpandProperty Sum
# Objects
$ObjectsWithStrikes = $ObjectCompliance | Where-Object {$_.Strikes -gt 0} 
$ObjectsWithoutStrikes = $ObjectCompliance | Where-Object {$_.Strikes -eq 0}
$ObjectsWithStrikesCount = $ObjectsWithStrikes | Measure-Object | Select-Object -ExpandProperty Count
$ObjectsWithoutStrikesCount = $ObjectsWithoutStrikes | Measure-Object | Select-Object -ExpandProperty Count
# Getting total backups that should exist for success rate calc
$TotalBackupsThatShouldExist = $ObjectCount * $DaysToReport
# Calculating percent, but only if there are strikes
IF ($TotalStrikes -eq 0){$ObjectSuccessRate = "100%"}ELSE{$ObjectSuccessRate = ($TotalBackups / $TotalBackupsThatShouldExist).ToString("P")}
# Getting integer
$ObjectSuccessRateINT = $ObjectSuccessRate.Replace("%"," ").TrimEnd()
# Last 24 hour totals
$LastDayBackups = $ObjectCompliance | Select-Object -ExpandProperty Last24HoursBackups | Measure-Object -Sum | Select-Object -ExpandProperty Sum
$LastDayStrikes = $ObjectCompliance | Select-Object -ExpandProperty Last24HoursStrikes | Measure-Object -Sum | Select-Object -ExpandProperty Sum
# Calculating percent, but only if there are strikes
IF ($LastDayStrikes -eq 0){$LastDaySuccessRate = "100%"}ELSE{$LastDaySuccessRate = ($LastDayBackups / $ObjectCount).ToString("P")}
# Getting integer
$LastDaySuccessRateINT = $LastDaySuccessRate.Replace("%"," ").TrimEnd()
##################################
# SMTP Body - HTML Email style settings
##################################
$HTMLStart = $HTMLCode | Where-Object {$_.SectionName -eq "Header"} | Select-Object -ExpandProperty HTMLCode
$HTMLEnd = $HTMLCode | Where-Object {$_.SectionName -eq "End"} | Select-Object -ExpandProperty HTMLCode
# Updating title in HTML start
$HTMLStart = $HTMLStart.Replace("#HTMLReportTitle",$EmailSubject)
##################################
# Creating HTML Summary table
##################################
$HTMLSummaryTable = $HTMLCode | Where-Object {$_.SectionName -eq "SUMMARYTABLE"} | Select-Object -ExpandProperty HTMLCode
# Updating variables in HTML code
$HTMLSummaryTable = $HTMLSummaryTable.Replace("#SystemDateTime",$SystemDateTime)
$HTMLSummaryTable = $HTMLSummaryTable.Replace("#DaysToReport",$DaysToReport)
$HTMLSummaryTable = $HTMLSummaryTable.Replace("#ObjectCount",$ObjectCount)
$HTMLSummaryTable = $HTMLSummaryTable.Replace("#ObjectsWithStrikes",$ObjectsWithStrikesCount)
$HTMLSummaryTable = $HTMLSummaryTable.Replace("#ObjectsWithoutStrikes",$ObjectsWithoutStrikesCount)
$HTMLSummaryTable = $HTMLSummaryTable.Replace("#ObjectSuccessRate",$ObjectSuccessRate)
$HTMLSummaryTable = $HTMLSummaryTable.Replace("#TotalBackups",$TotalBackups)
$HTMLSummaryTable = $HTMLSummaryTable.Replace("#TotalStrikes",$TotalStrikes)
$HTMLSummaryTable = $HTMLSummaryTable.Replace("#LastDayBackups",$LastDayBackups)
$HTMLSummaryTable = $HTMLSummaryTable.Replace("#LastDayStrikes",$LastDayStrikes)
$HTMLSummaryTable = $HTMLSummaryTable.Replace("#LastDaySuccessRate",$LastDaySuccessRate)
##################################
# Creating Table 1 HTML structure
##################################
# Creating column for every day
$HTMLTable1Colunms = @()
# Switching order if enabled, pulling date ranges from global variable on RSCAllObjectCompliance
IF ($SwitchOrder -eq $TRUE)
{
[array]::Reverse($RSCDateRanges)
}
# For Each
ForEach ($Date in $RSCDateRanges)
{
# Setting day
$HTMLDay = $Date.DayHTML
$HTMLDate = $Date.DateHTML
# Creating column
$HTMLTable1Column = $HTMLCode | Where-Object {$_.SectionName -eq "TABLE1COLUMNSTART"} | Select-Object -ExpandProperty HTMLCode
$HTMLTable1Column = $HTMLTable1Column.Replace("#HTMLDay",$HTMLDay)
$HTMLTable1Column = $HTMLTable1Column.Replace("#HTMLDate",$HTMLDate)
# Adding column
$HTMLTable1Colunms += $HTMLTable1Column
}
# Adding end to columns
$HTMLTable1ColumnEnd = $HTMLCode | Where-Object {$_.SectionName -eq "TABLE1COLUMNEND"} | Select-Object -ExpandProperty HTMLCode
$HTMLTable1Colunms += $HTMLTable1ColumnEnd
# Creating end of table
$HTMLTable1End = $HTMLCode | Where-Object {$_.SectionName -eq "TABLE1END"} | Select-Object -ExpandProperty HTMLCode
####################################################################
# Getting Unique Object Types With Strikes & Creating Table Array
####################################################################
$ObjectTypes = $ObjectCompliance | Sort-Object Type | Select-Object -ExpandProperty Type -Unique
$HTMLTables = @()
##################################
# For Each Object Type Creating Table
##################################
ForEach ($ObjectType in $ObjectTypes)
{
# Setting object type
$HTML1ObjectType = $ObjectType
# Getting table 1 code
$HTMLTable1Start = $HTMLCode | Where-Object {$_.SectionName -eq "TABLE1START"} | Select-Object -ExpandProperty HTMLCode
# Output to host
"----------------------------
CreatingHTMLTable: $HTML1ObjectType"
# Getting objects
$Table1Data = $ObjectCompliance | Where-Object {$_.Type -eq $HTML1ObjectType} | Sort-Object Object
# Counting 
$HTML1ObjectCount = $Table1Data | Measure-Object | Select-Object -ExpandProperty Count
$HTML1ObjectStrikeCount = $Table1Data | Where-Object {$_.Strikes -gt 0} | Measure-Object | Select-Object -ExpandProperty Count
# Updating table title
$HTMLTable1Start = $HTMLTable1Start.Replace("#HTMLTableTitle","$HTML1ObjectType").Replace("#HTMLTableObjectStrikeCount","$HTML1ObjectStrikeCount").Replace("#HTMLTableObjectCount","$HTML1ObjectCount")
# Removing non-strike objects for list if switch used
IF($OnlyShowObjectsWithStrikes){$Table1Data = $Table1Data | Where-Object {$_.Strikes -gt 0}}
# Showing only all-strike objects for list if switch used
IF($OnlyShowObjectsWithAllStrikes){$Table1Data = $Table1Data | Where-Object {$_.Strikes -ge $DaysToReport}}
##################################
# Creating Table 1 HTML Rows
##################################
# Nulling out table, protects against issues with multiple runs in PowerShell ISE
$HTMLReportTable1Rows = $null
# Creating table row for each line
ForEach ($Row in $Table1Data) 
{
# Setting values
$HTML1Object = $Row.Object
$HTML1ObjectID = $Row.ObjectID
$HTML1Type = $Row.Type
$HTML1Location = $Row.Location
$HTML1LocationID = $Row.LocationID
$HTML1Cluster = $Row.RubrikCluster
$HTML1ClusterID = $Row.RubrikClusterID
$HTML1SLADomain = $Row.SLADomain
$HTML1SLADomainID = $Row.SLADomainID
$HTML1TotalBackups = $Row.Backups
$HTML1TotalStrikes = $Row.Strikes
$HTML1LastBackup = $Row.LastBackup
$HTML1HoursSince = $Row.HoursSince
# Getting Object URLs
$HTML1ClusterURL = Get-RSCObjectURL -ObjectType "Cluster" -ObjectID $HTML1ClusterID
$HTML1SLAURL = Get-RSCObjectURL -ObjectType "SLADomain" -ObjectID $HTML1SLADomainID
$HTML1ObjectURL = Get-RSCObjectURL -ObjectType $HTML1Type -ObjectID $HTML1ObjectID
# Deciding status color
IF ($HTML1TotalStrikes -gt 0){$HTMLStatusColor =  "red"}ELSE{$HTMLStatusColor =  "black"}
# Building HTML table row
$HTMLReportTable1Row = $HTMLCode | Where-Object {$_.SectionName -eq "TABLE1ROW"} | Select-Object -ExpandProperty HTMLCode
$HTMLReportTable1Row = $HTMLReportTable1Row.Replace("#HTML1ObjectURL",$HTML1ObjectURL)
$HTMLReportTable1Row = $HTMLReportTable1Row.Replace("#HTMLStatusColor",$HTMLStatusColor)
$HTMLReportTable1Row = $HTMLReportTable1Row.Replace("#HTML1Object",$HTML1Object)
$HTMLReportTable1Row = $HTMLReportTable1Row.Replace("#HTML1Location",$HTML1Location)
$HTMLReportTable1Row = $HTMLReportTable1Row.Replace("#HTML1ClusterURL",$HTML1ClusterURL)
$HTMLReportTable1Row = $HTMLReportTable1Row.Replace("#HTML1Cluster",$HTML1Cluster)
$HTMLReportTable1Row = $HTMLReportTable1Row.Replace("#HTML1SLAURL",$HTML1SLAURL)
$HTMLReportTable1Row = $HTMLReportTable1Row.Replace("#HTML1SLADomain",$HTML1SLADomain)
$HTMLReportTable1Row = $HTMLReportTable1Row.Replace("#HTML1LastBackup",$HTML1LastBackup)
$HTMLReportTable1Row = $HTMLReportTable1Row.Replace("#HTML1HoursSince",$HTML1HoursSince)
# Getting columns for object
$HTMLObjectHistory = $RSCObjectCompliance | Where-Object {$_.ObjectID -eq $HTML1ObjectID}
# Switching order if enabled
IF ($SwitchOrder -eq $TRUE)
{
[array]::Reverse($HTMLObjectHistory)
}
# Creating column for every day
# For Each
ForEach ($HTMLDate in $HTMLObjectHistory)
{
# Setting variables
$HTML1BackupNotFound = $HTMLDate.BackupNotFound
$HTML1BackupFound = $HTMLDate.BackupFound
$HTML1Day = $HTMLDate.DayHTML
$HTML1Date = $HTMLDate.DateHTML
$HTML1DayDate = $HTML1Day + " " + $HTML1Date
# Setting result - new way
IF ($HTML1BackupFound -eq 1){$HTML1BackupStatus = "green"}ELSE{$HTML1BackupStatus = "red"}
# Changing result if set to use symbols
IF ($UseSymbols)
{
# Setting appropirate symbol
IF ($HTML1BackupFound -eq 1){$HTML1Symbol = "&#10004"}ELSE{$HTML1Symbol = "&#10060"}
# Setting cell background to nothing as using symbols
$HTML1BackupStatus = $null
}
ELSE
{
# Not using symbols, so setting to null
$HTML1Symbol = $null
}
# Creating column
$HTMLTable1Column = $HTMLCode | Where-Object {$_.SectionName -eq "TABLE1COLUMN"} | Select-Object -ExpandProperty HTMLCode
$HTMLTable1Column = $HTMLTable1Column.Replace("#HTML1BackupStatus",$HTML1BackupStatus)
$HTMLTable1Column = $HTMLTable1Column.Replace("#HTML1Date",$HTML1DayDate)
$HTMLTable1Column = $HTMLTable1Column.Replace("#HTML1Symbol",$HTML1Symbol)
# Adding column
$HTMLReportTable1Row += $HTMLTable1Column
}
# Adding end to columns
$HTMLTable1ColumnEnd = $HTMLCode | Where-Object {$_.SectionName -eq "TABLE1COLUMNEND"} | Select-Object -ExpandProperty HTMLCode
$HTMLReportTable1Row += $HTMLTable1ColumnEnd
# Adding row to table
$HTMLReportTable1Rows += $HTMLReportTable1Row
}
##################################
# Putting Table 1 together
##################################
$HTMLTable1 = $HTMLTable1Start + $HTMLTable1Colunms + $HTMLReportTable1Rows + $HTMLTable1End
# Adding to tables array
$HTMLTables += $HTMLTable1
##################################
# End of for each object type below
##################################
}
# End of for each object type above
##################################
# Creating Report
##################################
# Building HTML report:
$HTMLReport = $HTMLStart + $HTMLSummaryTable + $HTMLTables + $HTMLEnd
# Replacing any 100.00% strings with 100% for easier reading
$HTMLReport = $HTMLReport.Replace("100.00%","100%").TrimEnd()
##################################
# Exporting Report
##################################
# Creating the file names
$ObjectReportFile = $ReportExportDir + $ReportName + "-" + $SystemDateTime.ToString("yyyy-MM-dd") + "@" + $SystemDateTime.ToString("HH-mm-ss") + ".html"
# Exporting the report, if enabled
IF($ExportReportHTML)
{
$HTMLReport | Out-File -FilePath $ObjectReportFile -Force
# Output to host
"----------------------------
CreatedReport: $ObjectReportFile"
}
##################################
# Creating CSVs
##################################
# Creating the file names
$ObjectCSVFile = $CSVExportDir + "Rubrik-AllObjects-" + $SystemDateTime.ToString("yyyy-MM-dd") + "@" + $SystemDateTime.ToString("HH-mm-ss") + ".csv"
$ObjectStrikesCSVFile = $CSVExportDir + "Rubrik-Strikes-" + $SystemDateTime.ToString("yyyy-MM-dd") + "@" + $SystemDateTime.ToString("HH-mm-ss") + ".csv"
# Exporting to CSV
$ObjectCompliance | Sort-Object Strikes,Object | Export-Csv -Path $ObjectCSVFile -NoTypeInformation -Force
$ObjectCompliance | Where-Object {$_.Strikes -gt 0} | Sort-Object Strikes,Object | Export-Csv -Path $ObjectStrikesCSVFile -NoTypeInformation -Force
# Creating email attachement
$Attachments = "$ObjectCSVFile"
##################################
# Sending email using function
##################################
# Output to host
"----------------------------
SendingEmailTo: $EmailTo"
# Sending
Try
{
Send-RSCEmail -SMTPServer $SMTPServer -EmailTo $EmailTo -EmailFrom $EmailFrom -EmailBody $HTMLReport -EmailSubject $EmailSubject -Attachments $Attachments
$EmailSent = $TRUE
}
Catch
{
$EmailSent = $FALSE
$Error[0] | Format-List -Force
}

# Returning status
Return $EmailStatus
}
###############################################
# End of script
###############################################