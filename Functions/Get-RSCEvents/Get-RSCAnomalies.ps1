################################################
# Function - Get-RSCAnomalies - Getting all RSC Anomaly events
################################################
Function Get-RSCAnomalies {

<#
.SYNOPSIS
Returns an array of all anomalies within the time frame specified.

.DESCRIPTION
Makes the required GraphQL API calls to RSC via Invoke-RestMethod to get the data as described, then creates a usable array of the returned information, removing the need for the PowerShell user to understand GraphQL in order to interact with RSC.

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference
The ActivitySeriesConnection type: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference/activityseriesconnection.doc.html

.PARAMETER DaysToCapture
Optional, use only 1 paramter, specify the number of days to collect events from. 

.OUTPUTS
Returns an array of all the available information on the GraphQL endpoint in a uniform and usable format.

.EXAMPLE
Get-RSCAnomalies
This returns an array of all anomalies within the last 24 hours, unless you specify a time frame with the HoursToCapture, MinutesToCapture or DaysToCapture paramters.

.EXAMPLE
Get-RSCAnomalies -DaysToCapture 30
This example returns all anomaly events within a 30 day period.

.NOTES
Author: Joshua Stenhouse
Date: 05/11/2023
#>

################################################
# Paramater Config
################################################
	Param
    (
        $DaysToCapture
    )

################################################
# Importing Module & Running Required Functions
################################################
# Importing the module is it needs other modules
Import-Module RSCReporting
# Checking connectivity, exiting function with error if not connected
Test-RSCConnection
################################################
# Same function as RSCEventsAnomalies - So just running that...
################################################
$RSCEvents = Get-RSCEventsAnomalies -DaysToCapture $DaysToCapture

# Returning array
Return $RSCEvents
# End of function
}
