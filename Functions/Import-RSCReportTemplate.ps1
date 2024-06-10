################################################
# Creating the Import-RSCReportTemplate function
################################################
Function Import-RSCReportTemplate {
	
<#
.SYNOPSIS
A Rubrik Security Cloud (RSC) Reporting Module Function that imports the included HTML templates, used by Send-RSCReport functions only.

.DESCRIPTION
No API calls, an internal function.

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.PARAMETER Algorithm
Algorithm to generate key for.
.PARAMETER KeySize
Number of bits the generated key will have.
.PARAMETER AsPlainText
Returns a String instead of SecureString.

.OUTPUTS
Returns an array of all the available information on the GraphQL endpoint in a uniform and usable format.

.EXAMPLE
Connect-RSC -ScriptDirectory "C:\Scripts"
This example prompts for the RSC URL, user ID and secret, then connects to RSC and securely stores them for subsequent use in the script directory specified.

.NOTES
Author: Joshua Stenhouse
Date: 05/11/2023
#>
# Paramater Config
	Param
    (
        [Parameter(Mandatory=$true)][String]$Template
    )
# Loading template
$HTMLTemplate = Get-Content $Template
# Creating array
$HTMLCode = @()
# Creating Counter
$SectionCounter = 0
# Parsing HTML code
ForEach ($Line in $HTMLTemplate)
{
# Incrementing counter
$LineCounter ++
# Checking if split
IF ($Line -match "HTMLSPLIT")
{
# Incrementing section counter
$SectionCounter ++
# Selecting split name
$HTMLSectionName = $Line.Replace("<!--HTMLSPLIT-","").Replace("-->","").TrimStart().TrimEnd()
# Adding code to array
$HTMLCodeSection = New-Object PSObject
$HTMLCodeSection | Add-Member -MemberType NoteProperty -Name "Section" -Value $SectionCounter
$HTMLCodeSection | Add-Member -MemberType NoteProperty -Name "SectionName" -Value $HTMLSectionName
$HTMLCodeSection | Add-Member -MemberType NoteProperty -Name "HTMLCode" -Value $HTMLLine
$HTMLCode += $HTMLCodeSection
# Resetting HTML lines for next section
$HTMLLine = @()
}
ELSE
{
# Not at split yet, building rows
$HTMLLine += $Line
}
# End of processing HTML line below
}
# End of processing HTML line above

# Returning data
Return $HTMLCode
}
################################################
# End of script
################################################