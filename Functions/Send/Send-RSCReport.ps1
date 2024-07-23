################################################
# Function - Send-RSCReport - Sending RSC Report Email with the Specified CSV
################################################
Function Send-RSCReport {

<#
.SYNOPSIS
Creates and emails HTML reports based on custom array data that you pass into the function as a parameter, allowing you to create email reports on anything you want from the RSC APIs!

.DESCRIPTION
Specify an array of information to report on, it then creates a HTML report based on the columns in the $Array provided and sends it to the local SMTP server with the email settings params.

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.PARAMETER Array
An array of data to report on. I.E $Array = Get-RSCUsers | Select Username,LastLoginUTC,TOTPEnabled,TOTPEnforced,HasDefaultAdminRole
.PARAMETER ReportName
The name of the report you are creating. I.E "RSC User List"
.PARAMETER EmailTo
The email address to send the report to.
.PARAMETER EmailFrom
The email address the report will be sent from.
.PARAMETER SMTPServer
Your local SMTP server which will accept a relay request from the server you are running this script on (does not send via RSC itself)
.PARAMETER SortByColumnName
The name of a single column heading in the array to sort by. I.E Username
.PARAMETER ColumnOrder
A comma seperated list of all the columns in the array in the order you want them (has to be all), otherwise it will be random. I.E "Username,LastLoginUTC,TOTPEnabled,TOTPEnforced,HasDefaultAdminRole"
.PARAMETER SSLRequired
Switch if you require SSL to send the email via SMTP locally.

.OUTPUTS
Logs it's actions and the result of sending the email.

.EXAMPLE
Send a list of RSC Users
$RSCUsers = Get-RSCUsers | Select UserName,Email,Domain,TOTPEnabled,TOTPEnforced,LastLoginUTC,LastLoginHoursSince,Lockout,RoleCount,HasDefaultAdminRole
Send-RSCReport -Array $RSCUsers -EmailTo "joshua@lab.local" -EmailFrom "reports@lab.local" -SMTPServer "localhost" -ReportName "RSC Users" -SortByColumnName "LastLoginHoursSince" -ColumnOrder "UserName,Email,Domain,TOTPEnabled,TOTPEnforced,LastLoginUTC,LastLoginHoursSince,Lockout,RoleCount,HasDefaultAdminRole"

.EXAMPLE
Send a list of Local RSC Users
$Array = Get-RSCUsers | Where {$_.Domain -eq "LOCAL"} | Select URL,UserName,Email,Domain,TOTPEnabled,TOTPEnforced,LastLoginUTC,LastLoginHoursSince,Lockout,RoleCount,HasDefaultAdminRole
Send-RSCReport -Array $Array -EmailTo "joshua@lab.local" -EmailFrom "reports@lab.local" -SMTPServer "localhost" -ReportName "RSC Local Users" -SortByColumnName "LastLoginHoursSince" -ColumnOrder "UserName,Email,Domain,TOTPEnabled,TOTPEnforced,LastLoginUTC,LastLoginHoursSince,Lockout,RoleCount,HasDefaultAdminRole"

.EXAMPLE
Send a list of IPs in the allow list
$RSCIPAllowlist = Get-RSCIPAllowlist
Send-RSCReport -Array $RSCIPAllowlist -EmailTo "joshua@lab.local" -EmailFrom "reports@lab.local" -SMTPServer "localhost" -ReportName "RSC IP AllowList" -SortByColumnName "IP" -ColumnOrder "IP,SubnetMask,IPCidrs,Enabled,Mode"

.EXAMPLE
Send a list of VMware VMs
$VMwareVMs= Get-RSCVMwareVMs
$Array = $VMwareVMs | Where {$_.IsRelic -eq $False} | Select URL,VM,VMvCenter,OSType,RubrikCluster,SLADomain,SLAPaused,Power,ProtectedOn
Send-RSCReport -Array $Array -EmailTo "joshua@lab.local" -EmailFrom "reports@lab.local" -SMTPServer "localhost" -ReportName "VMware VMs" -SortByColumnName "VM" -ColumnOrder "VM,VMvCenter,OSType,RubrikCluster,SLADomain,SLAPaused,Power,ProtectedOn"

.EXAMPLE
Send a list of RBS hosts
$Array = Get-RSCHosts | Where {$_.Status -ne "REPLICATED_TARGET"} | Select Host,OS,RubrikCluster,Status,LastConnectedUTC,HoursSince,ProtectableObjects
$Array = $Array | Where {$_.OS -ne ""}
$Array = $Array | Where {$_.Status -ne "DELETED"}
Send-RSCReport -Array $Array -EmailTo "joshua@lab.local" -EmailFrom "reports@lab.local" -SMTPServer "localhost" -ReportName "RSC Hosts" -SortByColumnName "HoursSince" -ColumnOrder "Host,OS,RubrikCluster,Status,LastConnectedUTC,HoursSince,ProtectableObjects" -SortDescending

.EXAMPLE
Send a list of MS SQL DBs
$Array = Get-RSCMSSQLDatabases | Where {$_.IsRelic -eq $False} | Select URL,DB,Instance,Host,RubrikCluster,SLADomain,Online,InDag,DAG,HasPermissions
Send-RSCReport -Array $Array -EmailTo "joshua@lab.local" -EmailFrom "reports@lab.local" -SMTPServer "localhost" -ReportName "MSSQL DBs" -SortByColumnName "DB" -ColumnOrder "DB,Instance,Host,RubrikCluster,SLADomain,Online,InDag,DAG,HasPermissions"

.NOTES
Author: Joshua Stenhouse
Date: 05/11/2023
#>
################################################
# Paramater Config
################################################
[CmdletBinding(DefaultParameterSetName = "List")]
Param([Parameter(Mandatory=$true)]
	  $Array,$ReportName,$EmailTo,$EmailFrom,$SMTPServer,$SortByColumnName,$ColumnOrder,[switch]$SSLRequired,[switch]$SortDescending
  )
# Note: you can only sort by 1 column, but column order can be many I.E "VM,VMID"

################################################
# Importing Module & Running Required Functions
################################################
Import-Module RSCReporting
# Getting templates
$RSCTemplates = Get-RSCReportTemplates
# Getting file path of required template
$RSCTemplatePath = $RSCTemplates | Where-Object {$_.Report -match "00-RSCReport"} | Select-Object -ExpandProperty FilePath
# Importing template
$HTMLCode = Import-RSCReportTemplate $RSCTemplatePath
# Getting the machine time
$SystemDateTime = Get-Date
# Converting column order if needed
IF($ColumnOrder -ne $null)
{
IF($ColumnOrder -match ",")
{
$ColumnOrderArray = $ColumnOrder.Split(",")
}
ELSE
{
$ColumnOrderArray = $ColumnOrder
}
}
# Logging
Write-Host "----------------------------
CreatingReport: $ReportName
----------------------------
Building HTML.."
Start-Sleep 2
##################################
# Setting file names required
##################################
IF ($IsLinux -eq $TRUE)
{
$CSVExportDir = $RSCScriptDirectory + "CSVExports/" + $ReportName + "/"
}
ELSE
{
$CSVExportDir = $RSCScriptDirectory + "CSVExports\" + $ReportName + "\"
}
##################################
# Creating export directories if not exists
##################################
$CSVExportDirTest = Test-Path $CSVExportDir
IF ($CSVExportDirTest -eq $False)
{
New-Item -Path $CSVExportDir -ItemType "directory" | Out-Null
}
##################################
# Removing nulls from the array, otherwise it breaks the CSV export
##################################
$Array = $Array | Where-Object {$_ -ne $null}
##################################
# Creating CSVs
##################################
# Creating the file names
$ObjectCSVFile = $CSVExportDir + $ReportName + "-" + $SystemDateTime.ToString("yyyy-MM-dd") + "@" + $SystemDateTime.ToString("HH-mm-ss") + ".csv"
# Exporting to CSV
$Array | Export-Csv -Path $ObjectCSVFile -NoTypeInformation -Force
# Creating email attachement
$Attachments = "$ObjectCSVFile"
# Getting csv info
$FileName = Get-ChildItem $ObjectCSVFile | Select-Object -ExpandProperty Name
$RowCount = $Array | Measure-Object | Select-Object -ExpandProperty Count
##################################
# SMTP Body - HTML Email style settings
##################################
$HTMLStart = $HTMLCode | Where-Object {$_.SectionName -eq "Header"} | Select-Object -ExpandProperty HTMLCode
$HTMLEnd = $HTMLCode | Where-Object {$_.SectionName -eq "End"} | Select-Object -ExpandProperty HTMLCode
# Updating title in HTML start
$HTMLStart = $HTMLStart.Replace("#HTMLReportTitle",$ReportName)
##################################
# Creating HTML Summary table
##################################
$HTMLSummaryTable = $HTMLCode | Where-Object {$_.SectionName -eq "SUMMARYTABLE"} | Select-Object -ExpandProperty HTMLCode
# Updating variables in HTML code
$HTMLSummaryTable = $HTMLSummaryTable.Replace("#SystemDateTime",$SystemDateTime)
$HTMLSummaryTable = $HTMLSummaryTable.Replace("#ReportName",$ReportName)
$HTMLSummaryTable = $HTMLSummaryTable.Replace("#HTMLTableObjectCount",$RowCount)
##################################
# Creating HTML Data Table Start
##################################
$HTMLDataTable = @()
# Getting start of the table
$HTMLDataTableStart = $HTMLCode | Where-Object {$_.SectionName -eq "TABLE1START"} | Select-Object -ExpandProperty HTMLCode
# Adding to HTML 
$HTMLDataTable += $HTMLDataTableStart
# Getting list of columns in array
$ArrayColumns = $Array | Get-Member | Where-Object {$_.MemberType -eq "NoteProperty"} | Select-Object -ExpandProperty Name
##################################
# Sorting Order Of Columns If Specified
##################################
IF($ColumnOrderArray -ne $null)
{
$ArrayColumnsNewOrder = @()
ForEach($Column in $ColumnOrderArray){IF($ArrayColumns -contains $Column){$ArrayColumnsNewOrder += $Column}ELSE{Write-Host "ColumnInColumnOrderNotFound: $Column" -ForegroundColor Yellow}}
}
# Sorting remaining alphabetically
$ArrayColumns = $ArrayColumns | Sort-Object $_
# Adding remaning colums
ForEach($ArrayColumn in $ArrayColumns){IF($ArrayColumnsNewOrder -notcontains $ArrayColumn){$ArrayColumnsNewOrder += $ArrayColumn}}
# Overriding columns if specified with order + any remaining
IF($ColumnOrderArray -ne $null){$ArrayColumns = $ArrayColumnsNewOrder}
# Checking to see if colums contains a URL
IF($ArrayColumns -match "URL"){$ContainsURLColumn = $TRUE;$URLColumn = $ArrayColumns | Where {$_ -match "URL"}}ELSE{$ContainsURLColumn = $False;$URLColumn = $null}
# Removing URL column
IF($ContainsURLColumn -eq $TRUE){$ArrayColumns = $ArrayColumns | Where {$_ -ne "URL"}} 
##################################
# Adding Columns & Rows To Data Table
##################################
# For each array column adding to HTML table
ForEach($HTMLColumn in $ArrayColumns)
{
# Getting the column header template
$HTMLDataTableColumn = $HTMLCode | Where-Object {$_.SectionName -eq "TABLE1COLUMN"} | Select-Object -ExpandProperty HTMLCode
# Updating header
$HTMLDataTableColumn = $HTMLDataTableColumn.Replace("#HTMLColumn",$HTMLColumn)
# Adding to HTML
$HTMLDataTable += $HTMLDataTableColumn
}
# Getting end of columns
$HTMLDataTableColumnEnd = $HTMLCode | Where-Object {$_.SectionName -eq "TABLE1COLUMNEND"} | Select-Object -ExpandProperty HTMLCode
# Adding to HTML
$HTMLDataTable += $HTMLDataTableColumnEnd
# Sorting the array
IF($SortByColumnName -ne $null)
{
IF($ArrayColumns -contains $SortByColumnName){$SortByColumnNameExists = $TRUE}ELSE{$SortByColumnNameExists = $FALSE}
IF($SortByColumnNameExists -eq $TRUE)
{
# If set to sort by a specific column, doing so, and using descending switch if set
IF($SortDescending){$Array = $Array | Sort-Object $SortByColumnName -Descending}ELSE{$Array = $Array | Sort-Object $SortByColumnName}
}
}
# Selecting 1st column name
$1stColumn = $ArrayColumns | Select-Object -First 1
# For table row in the array
ForEach($Object in $Array)
{
# Getting row start
$HTMLDataTableRowStart = $HTMLCode | Where-Object {$_.SectionName -eq "TABLE1ROWSTART"} | Select-Object -ExpandProperty HTMLCode
# Adding to HTML
$HTMLDataTable += $HTMLDataTableRowStart
# Selecting URL column
$URLColumn = $ArrayColumns | Where-Object {$_ -eq "URL"}
# For each column on the object
ForEach($HTMLObjectColumn in $ArrayColumns)
{
# Selecting data
$HTMLRow = $Object | Select-Object -ExpandProperty $HTMLObjectColumn
# Getting row template
$HTMLDataTableRow = $HTMLCode | Where-Object {$_.SectionName -eq "TABLE1ROW"} | Select-Object -ExpandProperty HTMLCode
# If first column and contains URL column, updating both
IF(($ContainsURLColumn -eq $true) -and ($HTMLObjectColumn -eq $1stColumn))
{
# This is the 1st column, and a URL has been passed in the array, setting it to be a hyperlink in the table instead
$HTMLDataTableRow = $HTMLCode | Where-Object {$_.SectionName -eq "TABLE1ROW"} | Select-Object -ExpandProperty HTMLCode
$HTMLURL = $Object | Select-Object -ExpandProperty URL
$HTMLCombined = "<a href=`"" + $HTMLURL + "`" target=`"_blank`">" + $HTMLRow + "</a>"
$HTMLDataTableRow = $HTMLDataTableRow.Replace("#HTMLRow",$HTMLCombined)
}
ELSE
{
# Only need to update the column with the text for the object
$HTMLDataTableRow = $HTMLDataTableRow.Replace("#HTMLRow",$HTMLRow)
}
# Adding to HTML
$HTMLDataTable += $HTMLDataTableRow
}
# Getting row end
$HTMLDataTableRowEnd = $HTMLCode | Where-Object {$_.SectionName -eq "TABLE1ROWEND"} | Select-Object -ExpandProperty HTMLCode
# Adding to HTML
$HTMLDataTable += $HTMLDataTableRowEnd
}
# Getting table end
$HTMLDataTableEnd = $HTMLCode | Where-Object {$_.SectionName -eq "TABLE1END"} | Select-Object -ExpandProperty HTMLCode
# Adding to HTML
$HTMLDataTable += $HTMLDataTableEnd
##################################
# Creating Report
##################################
# Building HTML report:
$HTMLReport = [string]$HTMLStart + [string]$HTMLSummaryTable + [string]$HTMLDataTable + [string]$HTMLEnd
##################################
# Sending email using function
##################################
# Logging
Write-Host "----------------------------
SendingEmailTo: $EmailTo"
# Sending
Try
{
Send-RSCEmail -SMTPServer $SMTPServer -EmailTo $EmailTo -EmailFrom $EmailFrom -EmailBody $HTMLReport -EmailSubject $ReportName -Attachments $Attachments
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
