$FunctionDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path

# $env:PSModulePath

$Functions = Get-ChildItem -Path $FunctionDirectory -Recurse | where { $_.Name -match ".ps1" }
# Adding each function
foreach ($Function in $Functions) {
    # Setting path
    $FullFunctionPath = $Function.FullName
    # Importing
    . $FullFunctionPath
}
