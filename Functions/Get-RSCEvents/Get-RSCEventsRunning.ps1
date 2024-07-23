################################################
# Function - Get-RSCEventsRunning - Getting all RSC Running events
################################################
Function Get-RSCEventsRunning {

<#
.SYNOPSIS
A Rubrik Security Cloud (RSC) Reporting Module Function for currently running events.

.DESCRIPTION
Makes the required GraphQL API calls to RSC via Invoke-RestMethod to get the data as described, then creates a usable array of the returned information, removing the need for the PowerShell user to understand GraphQL in order to interact with RSC.

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference
The ActivitySeriesConnection type: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference/activityseriesconnection.doc.html

.PARAMETER ObjectType
Set the required object type of the events, has to be be a valid object type from the schema link, you can also try not specifying this, then use ObjectType on the array to get a valid list of ObjectType.
.PARAMETER ObjectID
Set the ObjectID to only return running events for the object specified (pulls all running events then filters, as there's no API filter for object ID as of 08/15/23)

.OUTPUTS
Returns an array of all the available information on the GraphQL endpoint in a uniform and usable format.

.EXAMPLE
Get-RSCEventsRunning
This example returns all running events within a 24 hour period as no paramters were set.

.EXAMPLE
Get-RSCEventsRunning -DaysToCapture 30
This example returns all running events started within a 30 day period.


.NOTES
Author: Joshua Stenhouse
Date: 05/11/2023
#>

################################################
# Paramater Config
################################################
	Param
    (
        $ObjectType,$ObjectID,$DaysToCapture
    )

################################################
# Importing Module & Running Required Functions
################################################
# Importing the module is it needs other modules
Import-Module RSCReporting
# Checking connectivity, exiting function with error if not connected
Test-RSCConnection

# Setting default days to capture if not set
IF($DaysToCapture -eq $null){$DaysToCapture = 1}

# Using existing Get-RSCEvents function
$RSCEventsRunning = Get-RSCEvents -DaysToCapture $DaysToCapture -LastActivityStatus "RUNNING"

# Removing task failures, appear as running status even though they aren't!
$RSCEventsRunning = $RSCEventsRunning | Where-Object {$_.Status -eq "RUNNING"}

# Filtering for object type if set
IF($ObjectType -ne $null){$RSCEventsRunning = $RSCEventsRunning | Where-Object {$_.ObjectType -eq $ObjectType}}

# Filtering for object ID if set
IF($ObjectID -ne $null){$RSCEventsRunning = $RSCEventsRunning | Where-Object {$_.ObjectID -eq $ObjectID}}

# Returning array
Return $RSCEventsRunning
# End of function
}
