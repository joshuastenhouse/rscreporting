################################################
# Function - Test-RSCConnection - Testing RSC Connectivity, writing error if not connected
################################################
Function Test-RSCConnection {

<#
.SYNOPSIS
A function used by all other functions to verify an RSC session has been established on the global variable RSCSessionStatus.

.DESCRIPTION
Checks for a Connected RSCSessionStatus and if not breaks the function.

.EXAMPLE
Test-RSCConnection
Valiates there is a valid RSC session and breaks the script if not.

.NOTES
Author: Joshua Stenhouse
Date: 05/11/2023
#>

################################################
# Breaking if no session connected
################################################
IF($RSCSessionStatus -ne "Connected")
{
Write-Error "ERROR: RSC is not connected, run Connect-RSCReporting and try again.."
Start-Sleep 2
Break
}

# Returning null
Return $null
# End of function
}