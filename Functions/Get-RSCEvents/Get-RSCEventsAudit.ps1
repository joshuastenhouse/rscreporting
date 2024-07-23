################################################
# Function - Get-RSCEventsAudit - Getting all RSC Audit events
################################################
Function Get-RSCEventsAudit {

<#
.SYNOPSIS
Returns all RSC audit events within the time frame specified, default is 24 hours with no parameters.

.DESCRIPTION
Makes the required GraphQL API calls to RSC via Invoke-RestMethod to get the data as described, then creates a usable array of the returned information, removing the need for the PowerShell user to understand GraphQL in order to interact with RSC.

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.PARAMETER DaysToCapture
The number of days to get events from, overrides all others, recommended to not go back too far without also specifying filters on LastActivityType, LastActivityStatus etc due to number of events.
.PARAMETER HoursToCapture
The number of hours to get events from, use instead of days if you want to be more granular.
.PARAMETER MinutesToCapture
The number of minutes to get events from, use instead of hours if you want to be even more granular.
.SWICTH DisableCountBack
This disables counting back to see how many failed login attempts for the user within the data collected, use if collecting multiple days to speed up collection.

.OUTPUTS
Returns an array of all the available information on the GraphQL endpoint in a uniform and usable format.

.EXAMPLE
Get-RSCEventsAudit
This example returns audit all events within a 24 hour period as no paramters were set.

.EXAMPLE
Get-RSCEventsAudit -DaysToCapture 30
This example returns all audit events within a 30 day period.

.NOTES
Author: Joshua Stenhouse
Date: 05/11/2023
#>

################################################
# Paramater Config
################################################
	Param
    (
        $DaysToCapture,$HoursToCapture,$MinutesToCapture
    )

################################################
# Importing Module & Running Required Functions
################################################
# Importing the module is it needs other modules
Import-Module RSCReporting
# Checking connectivity, exiting function with error if not connected
Test-RSCConnection
################################################
# Getting times required
################################################
$MachineDateTime = Get-Date
$UTCDateTime = [System.DateTime]::UtcNow
# If null, setting to 24 hours
IF(($MinutesToCapture -eq $null) -and ($HoursToCapture -eq $null))
{
$HoursToCapture = 24
}
# Calculating time range if minutes specified
IF($MinutesToCapture -ne $null)
{
$TimeRangeUTC = $UTCDateTime.AddMinutes(-$MinutesToCapture)
$TimeRange = $MachineDateTime.AddMinutes(-$MinutesToCapture)
}
# Calculating time range if hours specified
IF($HoursToCapture -ne $null)
{
$TimeRangeUTC = $UTCDateTime.AddHours(-$HoursToCapture)
$TimeRange = $MachineDateTime.AddHours(-$HoursToCapture)
}
# Overriding both if days to capture specified
IF($DaysToCapture -ne $null)
{
$TimeRangeUTC = $UTCDateTime.AddDays(-$DaysToCapture)
$TimeRange = $MachineDateTime.AddDays(-$DaysToCapture)	
}
# Converting to UNIX time format
$TimeRangeUNIX = $TimeRangeUTC.ToString("yyyy-MM-ddTHH:mm:ss.000Z")
# Logging
Write-Host "CollectingEventsFrom(UTC): $TimeRange
GraphQLAPI: EventSeriesListQuery"
################################################
# Getting RSC Events
################################################
# Creating array for events
$RSCEventsList = @()
# Building GraphQL query
$RSCGraphQL = @{"operationName"="AuditLogListQuery";

"variables" = @{
"filters" = @{
    "timeGt" = "$TimeRangeUNIX"
  }
"first" = 1000
"sortOrder" = "DESC"
};

"query"="query AuditLogListQuery(`$after: String, `$first: Int, `$filters: UserAuditFilter, `$sortOrder: SortOrder) 

{userAuditConnection(after: `$after, first: `$first, filters: `$filters, sortOrder: `$sortOrder) 

{
    edges {
        node {
            userNote
            userName
            id
            message
            time
            severity
            status
            cluster {
                id
                name
                __typename       
                }        
            __typename
            }
            cursor
            __typename
            }
            pageInfo {
                endCursor
                hasNextPage
                hasPreviousPage
                __typename   
                }
            __typename
            }
        }
"}
################################################
# API Call To RSC GraphQL URI
################################################
# Converting to JSON
$RSCEventsResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 32) -Headers $RSCSessionHeader
$RSCEventsList += $RSCEventsResponse.data.userAuditConnection.edges.node
# Getting all results from paginations
While ($RSCEventsResponse.data.userAuditConnection.pageInfo.hasNextPage) 
{
# Getting next set
$RSCGraphQL.variables.after = $RSCEventsResponse.data.userAuditConnection.pageInfo.endCursor
$RSCEventsResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
$RSCEventsList += $RSCEventsResponse.data.userAuditConnection.edges.node
}
# Counting
$RSCEventsCount = $RSCEventsList | Measure-Object | Select-Object -ExpandProperty Count
# Logging
Write-Host "EventsReturnedByAPI: $RSCEventsCount
Processing audit events..."
################################################
# Processing Events
################################################
# Creating array
$RSCEvents = [System.Collections.ArrayList]@()
# For Each Getting info
ForEach ($Event in $RSCEventsList)
{
# Setting variables
$EventID = $Event.id
$EventUserName = $Event.userName
$EventUserNote = $Event.userNote
$EventMessage = $Event.message
$EventTimeUNIX = $Event.time
$EventStatus = $Event.status
$EventSeverity = $Event.severity
# Counting failed login attemps if switch not used
IF($EventStatus -eq "Failure"){$EventFailedAttempts = $RSCEventsList | Where-Object {(($_.userName -eq $EventUserName) -and ($_.status -eq "Failure"))} | Measure-Object | Select-Object -ExpandProperty Count}ELSE{$EventFailedAttempts = 0}
# Converting event times
$EventDate = Convert-RSCUNIXTime $EventTimeUNIX
# Removing illegal SQL characters from user or message
IF($EventUserName -ne $null){$EventUserName = $EventUserName.Replace("'","");$EventUserName = $EventUserName.Replace(",","")}
IF($EventMessage -ne $null){$EventMessage = $EventMessage.Replace("'","");$EventMessage = $EventMessage.Replace(",","")
$EventMessage = $EventMessage.Replace("(","");$EventMessage = $EventMessage.Replace(")","")
$EventMessage = $EventMessage.Replace(":","");$EventMessage = $EventMessage -Replace ".$"}
# Parsing source
# IF($EventMessage -match "logged in from"){$EventSource = ($EventMessage -split 'from ',2)[-1]}ELSE{$EventSource = $null}
# Getting cluster
$EventCluster = $Event.cluster
$EventClusterID = $EventCluster.id
$EventClusterName = $EventCluster.name
# Overriding Polaris in cluster name
IF($EventClusterName -eq "Polaris"){$EventClusterName = "RSC";$EventSource = "RSC"}ELSE{$EventSource = "RubrikCluster"}
############################
# Adding To Array
############################
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
$Object | Add-Member -MemberType NoteProperty -Name "DateUTC" -Value $EventDate
$Object | Add-Member -MemberType NoteProperty -Name "Status" -Value $EventStatus
$Object | Add-Member -MemberType NoteProperty -Name "Severity" -Value $EventSeverity
$Object | Add-Member -MemberType NoteProperty -Name "UserName" -Value $EventUserName
$Object | Add-Member -MemberType NoteProperty -Name "Source" -Value $EventSource
$Object | Add-Member -MemberType NoteProperty -Name "RubrikCluster" -Value $EventClusterName
$Object | Add-Member -MemberType NoteProperty -Name "Message" -Value $EventMessage
# Always null so leaving out for now 08/29/22 # $Object | Add-Member -MemberType NoteProperty -Name "UserNote" -Value $EventUserNote
$Object | Add-Member -MemberType NoteProperty -Name "Failures" -Value $EventFailedAttempts
# IDs 
$Object | Add-Member -MemberType NoteProperty -Name "EventID" -Value $EventID
$Object | Add-Member -MemberType NoteProperty -Name "RubrikClusterID" -Value $EventClusterID
# Adding to array (optional, not needed)
$RSCEvents.Add($Object) | Out-Null
# End of for each event below
}
# End of for each event above

# Returning array
Return $RSCEvents
# End of function
}
