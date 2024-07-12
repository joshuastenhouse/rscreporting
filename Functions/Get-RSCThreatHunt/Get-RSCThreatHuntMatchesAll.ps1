################################################
# Function - Get-RSCThreatHuntMatchesAll - Getting All RSC Threat Hunt Matches
################################################
Function Get-RSCThreatHuntMatchesAll {

<#
.SYNOPSIS
Returns an array of every threat hunt match within the last 7 days, unless you specify otherwise with the DaysToCapture parameter.

.DESCRIPTION
Makes the required GraphQL API calls to RSC via Invoke-RestMethod to get the data as described, then creates a usable array of the returned information, removing the need for the PowerShell user to understand GraphQL in order to interact with RSC.

.PARAMETER DaysToCapture
The number of days to collect all threat hunt matches for, default if null is 30.

.OUTPUTS
Returns an array of all the available information on the GraphQL endpoint in a uniform and usable format.

.EXAMPLE
$ThreatHuntMatches = Get-RSCAllThreatHuntMatches
This returns an array of every threat hunt match within the last 30 days, unless you specify otherwise with the DaysToCapture parameter.

.NOTES
Author: Joshua Stenhouse
Date: 05/11/2023
#>

################################################
# Paramater Config
################################################
	Param
    (
        $HoursToCapture,$DaysToCapture
    )

################################################
# Importing Module & Running Required Functions
################################################
# Importing the module is it needs other modules
Import-Module RSCReporting
# Checking connectivity, exiting function with error if not connected
Test-RSCConnection
# Fixing nulls
IF($DaysToCapture -eq 0){$DaysToCapture = $null}
IF($HoursToCapture -eq 0){$HoursToCapture = $null}
IF(($HoursToCapture -eq $null) -and ($DaysToCapture -eq $null)){$DaysToCapture = 7}
################################################
# Getting RSC Threat Hunts
################################################
$AllThreatHuntMatches = @()
# Running correct command
IF($HoursToCapture -ne $null){$AllThreatHunts = Get-RSCThreatHunts -HoursToCapture $HoursToCapture}
IF($DaysToCapture -ne $null){$AllThreatHunts = Get-RSCThreatHunts -DaysToCapture $DaysToCapture}
# Removing nulls
$AllThreatHunts = $AllThreatHunts | Where {$_.ThreatHuntID -ne $null}
# For each threat hunt getting 
ForEach($ThreatHunt in $AllThreatHunts)
{
# Setting ID
$ThreatHuntID = $ThreatHunt.ThreatHuntID
# Getting Matches
$ThreatHuntMatches = Get-RSCThreatHuntMatches -ThreatHuntID $ThreatHuntID
# Adding to array
$AllThreatHuntMatches += $ThreatHuntMatches
}

# Returning array
Return $AllThreatHuntMatches
# End of function
}
