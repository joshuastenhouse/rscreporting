################################################
# Creating the Get-RSCReportTemplates function
################################################
Function Get-RSCReportTemplates {

<#
.SYNOPSIS
A Rubrik Security Cloud (RSC) Reporting Module Function returning a list of .html files included with the module.

.DESCRIPTION
Builds a list of all the report templates included with the SDK, no API calls made.

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.OUTPUTS
Returns an array of all the available information on the GraphQL endpoint in a uniform and usable format.

.EXAMPLE
Get-RSCReportTemplates
This example returns an array of all the information returned by the GraphQL endpoint for this object type.

.NOTES
Author: Joshua Stenhouse
Date: 05/11/2023
#>

# Importing Module 
Import-Module RSCReporting
# Creating array
$RSCReportTemplates = [System.Collections.ArrayList]@()
# Checking connectivity, exiting function with error if not connected
$HTMLReportTemplates = Get-Module -Name RSCReporting -All | Select-Object -ExpandProperty FileList
# Filtering for HTML files on
$HTMLReportTemplates = $HTMLReportTemplates | Where-Object {$_ -match ".html"}
# Getting report names
ForEach($HTMLReportTemplate in $HTMLReportTemplates)
{
$ReportFileName = Get-ChildItem $HTMLReportTemplate | Select-Object -ExpandProperty Name
$ReportName = $ReportFileName.Replace(".html","")
# Adding To Array
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "Report" -Value $ReportName
$Object | Add-Member -MemberType NoteProperty -Name "FileName" -Value $ReportFileName
$Object | Add-Member -MemberType NoteProperty -Name "FilePath" -Value $HTMLReportTemplate
# Adding
$RSCReportTemplates.Add($Object) | Out-Null

}
# Returning data
Return $RSCReportTemplates
}
################################################
# End of script
################################################