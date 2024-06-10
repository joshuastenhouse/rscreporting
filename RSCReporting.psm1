$FunctionDirectory = Split-Path -parent $MyInvocation.MyCommand.Path

# $env:PSModulePath

$Functions = Get-ChildItem -Path $FunctionDirectory -Recurse | Where {$_.Name -match ".ps1"}
# Adding each function
ForEach ($Function in $Functions)
{
# Setting path
$FullFunctionPath = $Function.FullName
# Importing
. $FullFunctionPath
}