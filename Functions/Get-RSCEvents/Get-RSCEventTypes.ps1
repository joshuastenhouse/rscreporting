################################################
# Function - Get-RSCEventTypes - Returning all event types in RSC 
################################################
Function Get-RSCEventTypes {

<#
.SYNOPSIS
A Rubrik Security Cloud (RSC) Reporting Module Function returning all event types in RSC.

.DESCRIPTION
Makes the required GraphQL API calls to RSC via Invoke-RestMethod to get the data as described, then creates a usable array of the returned information, removing the need for the PowerShell user to understand GraphQL in order to interact with RSC.

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.OUTPUTS
Returns an array of all the available information on the GraphQL endpoint in a uniform and usable format.

.EXAMPLE
Get-RSCObjectTypes
This example returns an array of all the information returned by the GraphQL endpoint for this object type.

.NOTES
Author: Joshua Stenhouse
Date: 05/11/2023
#>
################################################
# Creating list of all event types taken from event UI API call (last updated 06/17/2024)
################################################
$RSCEventTypes = "ANOMALY",
"RANSOMWARE_INVESTIGATION_ANALYSIS",
"ARCHIVE",
"AUTH_DOMAIN",
"BACKUP",
"CLASSIFICATION",
"CONFIGURATION",
"CONNECTION",
"CONVERSION",
"DIAGNOSTIC",
"DISCOVERY",
"DOWNLOAD",
"EMBEDDED_EVENT",
"ENCRYPTION_MANAGEMENT_OPERATION",
"FAILOVER",
"HARDWARE",
"LOCAL_RECOVERY",
"LOG_BACKUP",
"INDEX",
"INSTANTIATE",
"ISOLATED_RECOVERY",
"LEGAL_HOLD",
"LOCK_SNAPSHOT",
"MAINTENANCE",
"BULK_RECOVERY",
"OWNERSHIP",
"RECOVERY",
"REPLICATION",
"RESOURCE_OPERATIONS",
"SCHEDULE_RECOVERY",
"STORAGE",
"SUPPORT",
"SYNC",
"SYSTEM",
"TPR",
"TENANT_OVERLAP",
"TENANT_QUOTA",
"TEST_FAILOVER",
"THREAT_FEED",
"THREAT_HUNT",
"THREAT_MONITORING",
"UPGRADE"

# Returning array
Return $RSCEventTypes
# End of function
}
