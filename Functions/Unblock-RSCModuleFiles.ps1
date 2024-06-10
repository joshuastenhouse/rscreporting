################################################
# Creating the Unblock-RSCModuleFiles function
################################################
Function Unblock-RSCModuleFiles {

<#
.SYNOPSIS
A Rubrik Security Cloud (RSC) Reporting Module Function that unblocks all the files in the module if you downloaded and imported this module offline.

.DESCRIPTION
Specify the location where you installed the module and run as admin to unblock the module files. Make sure you run this as administrator otherwise it will not work!

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.PARAMETER ModulePath
The location where you manually copied the module to. I.E "C:\Users\joshu\OneDrive\Documents\WindowsPowerShell\Modules\RSCReporting"

.EXAMPLE
Unblock-RSCModuleFiles -ModulePath "C:\Users\joshu\OneDrive\Documents\WindowsPowerShell\Modules\RSCReporting"

.NOTES
Author: Joshua Stenhouse
Date: 05/11/2023
#>

################################################
# Paramater Config
################################################
[CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true)]
        [string]$ModulePath
    )

################################################
# Main Function
################################################
# Getting all files in the ModulePath specified
$Files = Get-ChildItem $ModulePath -Recurse
$RSCFileList = [System.Collections.ArrayList]@()
# Unblocking ps files
ForEach($File in $Files)
{
$FilePath = $File.FullName
$FileFullName = $File.Name
$FileExtension = $File.Extension
# Unblocking the file
Try
{
Unblock-File $FilePath -Confirm:$false
$FileUnblocked = $TRUE
}
Catch
{
$FileUnblocked = $FALSE
}
# Adding To Array
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "File" -Value $FileFullName
$Object | Add-Member -MemberType NoteProperty -Name "Unblocked" -Value $FileUnblocked
$Object | Add-Member -MemberType NoteProperty -Name "ModuleFolder" -Value $ModulePath
$Object | Add-Member -MemberType NoteProperty -Name "FilePath" -Value $FilePath
$Object | Add-Member -MemberType NoteProperty -Name "FileName" -Value $FileName
$Object | Add-Member -MemberType NoteProperty -Name "Type" -Value $FileExtension
# Adding
$RSCFileList.Add($Object) | Out-Null
}
# Returning data
Return $RSCFileList
}
################################################
# End of script
################################################