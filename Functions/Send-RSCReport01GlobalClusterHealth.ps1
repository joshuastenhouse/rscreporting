################################################
# Function - Send-RSCReport01GlobalClusterHealth - Sending RSC Report
################################################
Function Send-RSCReport01GlobalClusterHealth {

<#
.SYNOPSIS
Creates and emails a pre-canned HTML report on all your Rubrik clusters.

.DESCRIPTION
Pre-built template of a common request for a global daily cluster health email.

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

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

.OUTPUTS
Logs it's actions and the result of sending the email.

.EXAMPLE
Send-RSCReport01GlobalClusterHealth -EmailTo "admin@lab.local" -EmailFrom "reporting@lab.local" -SMTPServer "localhost"
Creates a HTML report of all your Rubrik clusters and emails it via local SMTP.

.NOTES
Author: Joshua Stenhouse
Date: 05/11/2023
#>
################################################
# Paramater Config
################################################
	Param
    (
        $EmailTo,$EmailFrom,$SMTPServer,[switch]$SSLRequired,[switch]$ExportReportHTML
    )

# Threholds for coloring storage usage fields (%)
$WarningUsedThreshold = 85
$FailureUsedThreshold = 95
# HTML Color codes used for reports
$HTMLColorSuccess = "#000000"
$HTMLColorWarning = "#ff8c00"
$HTMLColorFailure = "#e60000"
# Email subject
$EmailSubject = "Rubrik Global Cluster Health"
# Report Name
$ReportName = "01-GlobalClusterHealth"
################################################
# Importing Module & Running Required Functions
################################################
Import-Module RSCReporting
# Checking connectivity, exiting function with error if not connected
Test-RSCConnection
# Getting RSC files
$RSCFiles = Get-RSCModuleFiles
# Getting templates
$RSCTemplates = Get-RSCReportTemplates
# Getting file path of required template
$RSCTemplatePath = $RSCTemplates | Where-Object {$_.Report -match $ReportName} | Select-Object -ExpandProperty FilePath
# Getting the machine time
$SystemDateTime = Get-Date
##################################
# Report Description
##################################
$ReportDescription = "This report gives you a list of all Rubrik clusters current status including version, capacity, used storage etc. It is designed to be used as a daily report showing cluster health across a global deployment. If you are looking for cluster storage trending over time use report 22-GlobalClusterStorageUsage."
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
##################################
# Setting Time
##################################
$SystemDateTime = Get-Date
###########################
# Getting RSC Data & Template
###########################
$RubrikClusters = Get-RSCClusters
# Importing template
$HTMLCode = Import-RSCReportTemplate $RSCTemplatePath
##################################
# Calculating totals
##################################
$ClusterCount = $RubrikClusters | Measure-Object | Select-Object -ExpandProperty Count
$ClusterCriticalCount = $RubrikClusters | Where-Object {$_.BadNodes -ge "1"} | Measure-Object | Select-Object -ExpandProperty Count
$ClusterHealthyCount = $RubrikClusters | Where-Object {$_.BadNodes -eq "0"} | Measure-Object | Select-Object -ExpandProperty Count
$ClusterNodeCount = $RubrikClusters | Select-Object -ExpandProperty TotalNodes | Measure-Object -Sum | Select-Object -ExpandProperty Sum
$ClusterBadNodeCount = $RubrikClusters | Select-Object -ExpandProperty BadNodes | Measure-Object -Sum | Select-Object -ExpandProperty Sum
$ClusterHealthyNodeCount = $RubrikClusters | Select-Object -ExpandProperty HealthyNodes | Measure-Object -Sum | Select-Object -ExpandProperty Sum
$ClustersPhsical = $RubrikClusters | Where-Object {$_.Type -eq "Physical"} | Measure-Object | Select-Object -ExpandProperty Count
$ClustersVirtual = $RubrikClusters | Where-Object {$_.Type -ne "Physical"} | Measure-Object | Select-Object -ExpandProperty Count
$ClusterTotalCapacityTB = $RubrikClusters | Select-Object -ExpandProperty TotalStorageTB | Measure-Object -Sum | Select-Object -ExpandProperty Sum
$ClusterTotalUsedTB = $RubrikClusters | Select-Object -ExpandProperty UsedStorageTB | Measure-Object -Sum | Select-Object -ExpandProperty Sum
$ClusterTotalFreeTB = $RubrikClusters | Select-Object -ExpandProperty FreeStorageTB | Measure-Object -Sum | Select-Object -ExpandProperty Sum
$ClustersTotalProtectedObjects = $RubrikClusters | Select-Object -ExpandProperty ProtectedObjects | Measure-Object -Sum | Select-Object -ExpandProperty Sum
$ClustersTotalDoNotProtectObjects = $RubrikClusters | Select-Object -ExpandProperty DoNotProtectObjects | Measure-Object -Sum | Select-Object -ExpandProperty Sum
$ClustersTotalUnProtectedObjects = $RubrikClusters | Select-Object -ExpandProperty UnProtectedObjects | Measure-Object -Sum | Select-Object -ExpandProperty Sum
$ClustersTimeZones = $RubrikClusters | Select-Object -ExpandProperty Timezone -Unique | Measure-Object | Select-Object -ExpandProperty Count
# Counting clusters not connected
$ClustersNotConnectedCount = $RubrikConnections | Where-Object {$_.ConnectionStatus -ne "Connected"} | Measure-Object | Select-Object -ExpandProperty Count
# Combining
$ClusterTotalCriticalCount = $ClusterCriticalCount + $ClustersNotConnectedCount
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
$HTMLSummaryTable = $HTMLSummaryTable.Replace("#ClusterCount",$ClusterCount)
$HTMLSummaryTable = $HTMLSummaryTable.Replace("#ClusterNodeCount",$ClusterNodeCount)
$HTMLSummaryTable = $HTMLSummaryTable.Replace("#ClusterTotalCapacityTB",$ClusterTotalCapacityTB)
$HTMLSummaryTable = $HTMLSummaryTable.Replace("#ClustersTotalProtectedObjects",$ClustersTotalProtectedObjects)
$HTMLSummaryTable = $HTMLSummaryTable.Replace("#ClusterCriticalCount",$ClusterTotalCriticalCount)
$HTMLSummaryTable = $HTMLSummaryTable.Replace("#ClusterBadNodeCount",$ClusterBadNodeCount)
$HTMLSummaryTable = $HTMLSummaryTable.Replace("#ClusterTotalUsedTB",$ClusterTotalUsedTB)
$HTMLSummaryTable = $HTMLSummaryTable.Replace("#ClustersTimeZones",$ClustersTimeZones)
$HTMLSummaryTable = $HTMLSummaryTable.Replace("#ClusterHealthyCount",$ClusterHealthyCount)
$HTMLSummaryTable = $HTMLSummaryTable.Replace("#ClusterHealthyNodeCount",$ClusterHealthyNodeCount)
$HTMLSummaryTable = $HTMLSummaryTable.Replace("#ClusterTotalFreeTB",$ClusterTotalFreeTB)
$HTMLSummaryTable = $HTMLSummaryTable.Replace("#ClustersTotalDoNotProtectObjects",$ClustersTotalDoNotProtectObjects)
$HTMLSummaryTable = $HTMLSummaryTable.Replace("#ClustersTotalUnProtectedObjects",$ClustersTotalUnProtectedObjects)
##################################
# Creating Table 1 HTML structure
##################################
$HTMLTable1Start = $HTMLCode | Where-Object {$_.SectionName -eq "TABLE1START"} | Select-Object -ExpandProperty HTMLCode
$HTMLTable1End = $HTMLCode | Where-Object {$_.SectionName -eq "TABLE1END"} | Select-Object -ExpandProperty HTMLCode
##################################
# Creating Table 1 HTML Rows
##################################
# Selecting data required for HTML rows
$RubrikClusters = $RubrikClusters | Sort-Object ProtectedObjects -Descending
# Counting records
$RubrikClusterCount = $RubrikClusters | Measure-Object | Select-Object -ExpandProperty Count
$RubrikClusterCounter = 0
# Output to host
"----------------------------"
# Nulling out table, protects against issues with multiple runs in PowerShell ISE
$HTMLReportTable1Middle = $null
# Creating table row for each line
ForEach ($Row in $RubrikClusters) 
{
# Incrementing counter
$RubrikClusterCounter ++
# Output to host
"ProcessingCluster: $RubrikClusterCounter/$RubrikClusterCount"
# Setting values
$HTML1Name = $Row.Cluster
$HTML1Type = $Row.Type
$HTML1ClusterID = $Row.ClusterID
$HTML1Status = $Row.Status
$HTML1ConnectionStatus = $Row.ConnectionStatus
$HTML1Version = $Row.Version
$HTML1VersionStatus = $Row.VersionStatus
$HTML1Nodes = $Row.TotalNodes
$HTML1BadNodes = $Row.BadNodes
$HTML1Disks = $Row.TotalDisks
$HTML1BadDisks = $Row.BadDisks
$HTML1CapacityTB = $Row.TotalStorageTB
$HTML1UsedTB = $Row.UsedStorageTB
$HTML1FreeTB = $Row.FreeStorageTB
$HTML1Used = $Row.Used
$HTML1Free = $Row.Free
$HTML1LocalDedupeRateINT = $Row.LocalDataReduction
$HTML1CloudDedupeRateINT = $Row.ArchiveDataReduction
$HTML1Runwaydays = $Row.RunwayDays
$HTML1Protected = $Row.ProtectedObjects
$HTML1Unprotected = $Row.UnprotectedObjects
$HTML1DoNotProtect = $Row.DoNotProtectObjects
$HTML1SLADomains = $Row.SLADomains
$HTML1TimeZone = $Row.Timezone
$HTML1Location = $Row.Location
$HTML1Encrypted = $Row.Encrypted
# Getting INT
$HTML1UsedINT = $HTML1Used.Replace("%","")
# Getting URL for cluster
$HTML1ClusterURL = Get-RSCObjectURL -ObjectType "Cluster" -ObjectID $HTML1ClusterID
# Setting cluster status color
IF ($HTML1Status -eq "Healthy"){$HTMLStatusColor =  $HTMLColorSuccess}
IF ($HTML1Status -ne "Healthy"){$HTMLStatusColor =  $HTMLColorFailure}
# Overriding status color if not connected recently
IF ($HTML1ConnectionStatus -eq "Connected"){$HTMLStatusColor =  $HTMLColorSuccess}
IF ($HTML1ConnectionStatus -ne "Connected"){$HTMLStatusColor =  $HTMLColorFailure}
# Overriding status color if running low on space
IF ($HTML1UsedINT -lt $FailureUsedThreshold){$HTMLSpaceStatusColor =  $HTMLColorSuccess}
IF ($HTML1UsedINT -ge $WarningUsedThreshold){$HTMLSpaceStatusColor =  $HTMLColorWarning}
IF ($HTML1UsedINT -ge $FailureUsedThreshold){$HTMLSpaceStatusColor =  $HTMLColorFailure}
# Setting color for status
IF ($HTML1VersionStatus -eq "STABLE"){$HTMLVersionStatusColor = $HTMLColorSuccess}
IF ($HTML1VersionStatus -ne "STABLE"){$HTMLVersionStatusColor = $HTMLColorWarning}
# Building HTML table row
$HTMLReportTable1Row = $HTMLCode | Where-Object {$_.SectionName -eq "TABLE1ROW"} | Select-Object -ExpandProperty HTMLCode
# Updating variables in HTML code
$HTMLReportTable1Row = $HTMLReportTable1Row.Replace("#HTML1ClusterURL",$HTML1ClusterURL)
$HTMLReportTable1Row = $HTMLReportTable1Row.Replace("#HTML1Name",$HTML1Name)
$HTMLReportTable1Row = $HTMLReportTable1Row.Replace("#HTML1Type",$HTML1Type)
$HTMLReportTable1Row = $HTMLReportTable1Row.Replace("#HTMLStatusColor",$HTMLStatusColor)
$HTMLReportTable1Row = $HTMLReportTable1Row.Replace("#HTML1Status",$HTML1Status)
$HTMLReportTable1Row = $HTMLReportTable1Row.Replace("#HTML1Errors",$HTML1Errors)
$HTMLReportTable1Row = $HTMLReportTable1Row.Replace("#HTML1Version",$HTML1Version)
$HTMLReportTable1Row = $HTMLReportTable1Row.Replace("#HTMLVersionStatusColor",$HTMLVersionStatusColor)
$HTMLReportTable1Row = $HTMLReportTable1Row.Replace("#HTML1Nodes",$HTML1Nodes)
$HTMLReportTable1Row = $HTMLReportTable1Row.Replace("#HTML1BadNodes",$HTML1BadNodes)
$HTMLReportTable1Row = $HTMLReportTable1Row.Replace("#HTML1Disks",$HTML1Disks)
$HTMLReportTable1Row = $HTMLReportTable1Row.Replace("#HTML1BadDisks",$HTML1BadDisks)
$HTMLReportTable1Row = $HTMLReportTable1Row.Replace("#HTML1Details",$HTML1Details)
$HTMLReportTable1Row = $HTMLReportTable1Row.Replace("#HTMLSpaceStatusColor",$HTMLSpaceStatusColor)
$HTMLReportTable1Row = $HTMLReportTable1Row.Replace("#HTML1Used",$HTML1Used)
$HTMLReportTable1Row = $HTMLReportTable1Row.Replace("#HTML1Free",$HTML1Free)
$HTMLReportTable1Row = $HTMLReportTable1Row.Replace("#HTML1TBCapacity",$HTML1CapacityTB)
$HTMLReportTable1Row = $HTMLReportTable1Row.Replace("#HTML1TBUsed",$HTML1UsedTB)
$HTMLReportTable1Row = $HTMLReportTable1Row.Replace("#HTML1TBFree",$HTML1FreeTB)
$HTMLReportTable1Row = $HTMLReportTable1Row.Replace("#HTML1Runwaydays",$HTML1Runwaydays)
$HTMLReportTable1Row = $HTMLReportTable1Row.Replace("#HTML1Protected",$HTML1Protected)
$HTMLReportTable1Row = $HTMLReportTable1Row.Replace("#HTML1Unprotected",$HTML1Unprotected)
$HTMLReportTable1Row = $HTMLReportTable1Row.Replace("#HTML1DoNotProtect",$HTML1DoNotProtect)
$HTMLReportTable1Row = $HTMLReportTable1Row.Replace("#HTML1TimeZone",$HTML1TimeZone)
$HTMLReportTable1Row = $HTMLReportTable1Row.Replace("#HTML1Location",$HTML1Location)
$HTMLReportTable1Row = $HTMLReportTable1Row.Replace("#HTML1Encrypted",$HTML1Encrypted)
# Adding row to table
$HTMLReportTable1Middle += $HTMLReportTable1Row
}
##################################
# Putting Table 1 together
##################################
$HTMLTable1 = $HTMLTable1Start + $HTMLReportTable1Middle + $HTMLTable1End
##################################
# Creating Report
##################################
# Building HTML report:
$HTMLReport = [string]$HTMLStart + [string]$HTMLSummaryTable + [string]$HTMLTable1 + [string]$HTMLEnd
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
# Output to host
"----------------------------
CreatedReport: $ObjectReportFile"
$HTMLReport | Out-File -FilePath $ObjectReportFile -Force
}
##################################
# Creating CSVs
##################################
# Creating the file names
$ObjectCSVFile = $CSVExportDir + $ReportName + "-" + $SystemDateTime.ToString("yyyy-MM-dd") + "@" + $SystemDateTime.ToString("HH-mm-ss") + ".csv"
# Exporting to CSV
$RubrikClusters | Export-Csv -Path $ObjectCSVFile -NoTypeInformation -Force
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
