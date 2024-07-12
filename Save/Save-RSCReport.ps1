################################################
# Function - Save-RSCReport - Saving An RSC Report to the directory sepcified
################################################
Function Save-RSCReport {

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
.PARAMETER Directory
The directory to save the report to.

.OUTPUTS
Logs it's actions and the result of sending the email.

.EXAMPLE
$Array = Get-RSCUsers | Select Username,LastLoginUTC,TOTPEnabled,TOTPEnforced,HasDefaultAdminRole
Building an array of data to report on.

.EXAMPLE
$Array = Save-RSCReport -Array $Array -ReportName "RSCUserList" -Directory "C:\Reports" 
Creates a HTML report based on a list of user information and saves it to the directory specified

.NOTES
Author: Joshua Stenhouse
Date: 06/19/2024
#>
################################################
# Paramater Config
################################################
[CmdletBinding(DefaultParameterSetName = "List")]
Param([Parameter(Mandatory=$true)]
	  $Array,$ReportName,$Directory,$SortByColumnName,$ColumnOrder,[switch]$SSLRequired,[switch]$SortDescending
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
# Exporting Report
##################################
# Creating the file names
$ObjectReportFile = $Directory + $ReportName + "-" + $SystemDateTime.ToString("yyyy-MM-dd") + "@" + $SystemDateTime.ToString("HH-mm-ss") + ".html"
# Exporting the report, if enabled
IF($ExportReportHTML)
{
$HTMLReport | Out-File -FilePath $ObjectReportFile -Force
# Output to host
"----------------------------
CreatedReport: $ObjectReportFile"
}

# Returning status
Return $null
}
###############################################
# End of script
###############################################
