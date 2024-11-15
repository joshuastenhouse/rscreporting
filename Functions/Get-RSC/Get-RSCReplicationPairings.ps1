################################################
# Function - Get-RSCReplicationPairings - Getting Replication Pairings Configuered on RSC
################################################
Function Get-RSCReplicationPairings {

<#
.SYNOPSIS
A Rubrik Security Cloud (RSC) Reporting Module Function returning a list of all replication targets configured on all clusters.

.DESCRIPTION
Makes the required GraphQL API calls to RSC via Invoke-RestMethod to get the data as described, then creates a usable array of the returned information, removing the need for the PowerShell user to understand GraphQL in order to interact with RSC.

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.OUTPUTS
Returns an array of all the available information on the GraphQL endpoint in a uniform and usable format.

.EXAMPLE
Get-RSCReplicationPairings
This example returns an array of all the information returned by the GraphQL endpoint for this object type.

.NOTES
Author: Joshua Stenhouse
Date: 11/14/2024
#>

################################################
# Importing Module & Running Required Functions
################################################
# Importing the module is it needs other modules
Import-Module RSCReporting
# Checking connectivity, exiting function with error if not connected
Test-RSCConnection
################################################
# Querying RSC GraphQL API
################################################
# Creating array for objects
$RSCList = @()
# Building GraphQL query
$RSCGraphQL = @{"operationName" = "ReplicationTargetsListQuery";

"variables" = @{
"first" = 1000
};

"query" = "query ReplicationTargetsListQuery(`$after: String, `$before: String, `$first: Int) {
  replicationPairs(after: `$after, before: `$before, first: `$first) {
    edges {
      cursor
      node {
        configDetails {
          setupType
          sourceGateway {
            address
            ports
            __typename
          }
          targetGateway {
            address
            ports
            __typename
          }
          __typename
        }
        connectionDetails {
          sourceAndRubrik
          sourceAndTarget
          targetAndRubrik
          __typename
        }
        failedTasks
        isPaused
        networkThrottle {
          currentThrottleLimit
          defaultThrottleLimit
          isEnabled
          scheduledThrottles {
            throttleLimit
            daysOfWeek
            startHour
            endHour
            __typename
          }
          networkInterface
          __typename
        }
        runningTasks
        sourceCluster {
          id
          name
          version
          __typename
        }
        status
        storage
        targetCluster {
          id
          name
          version
          __typename
        }
        __typename
      }
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
}"
}
################################################
# API Call To RSC GraphQL URI
################################################
# Querying API
$RSCResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
# Setting variable
$RSCList += $RSCResponse.data.replicationPairs.edges.node
# Getting all results from paginations
While ($RSCResponse.data.replicationPairs.pageInfo.hasNextPage) 
{
# Getting next set
$RSCGraphQL.variables.after = $RSCResponse.data.replicationPairs.pageInfo.endCursor
$RSCResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
$RSCList += $RSCResponse.data.replicationPairs.edges.node
}
################################################
# Processing List
################################################
# Creating array
$RSCReplicationTargets = [System.Collections.ArrayList]@()
# For Each Object Getting Data
ForEach ($ListObject in $RSCList)
{
# Setting variables
$Connection = $ListObject.connectionDetails
$SourceClusterStatus = $Connection.sourceAndRubrik
$TargetClusterStatus = $Connection.targetAndRubrik
$ConnectionStatus = $Connection.sourceAndTarget
$ReplicationStatus = $ListObject.status
$IsPaused = $ListObject.isPaused
$Throttle = $ListObject.networkThrottle
$ThrottleEnabled = $Throttle.isEnabled
$RunningTasks = $ListObject.runningTasks
$SourceClusterName = $ListObject.sourceCluster.name
$SourceClusterID = $ListObject.sourceCluster.id
$TargetClusterName = $ListObject.targetCluster.name
$TargetClusterID = $ListObject.targetCluster.id
$UsedBytes = $ListObject.storage
# Converting bytes
IF($UsedBytes -ne $null){$UsedGB = $UsedBytes / 1000 / 1000 / 1000;$UsedGB = [Math]::Round($UsedGB,2)}ELSE{$UsedGB = $null}
# Creating URL
$RSCReplicationURL = $RSCURL + "/remote_configs/replication_targets"
# Adding To Array
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
$Object | Add-Member -MemberType NoteProperty -Name "SourceCluster" -Value $SourceClusterName
$Object | Add-Member -MemberType NoteProperty -Name "SourceClusterID" -Value $SourceClusterID
$Object | Add-Member -MemberType NoteProperty -Name "TargetCluster" -Value $TargetClusterName
$Object | Add-Member -MemberType NoteProperty -Name "TargetClusterID" -Value $TargetClusterID
$Object | Add-Member -MemberType NoteProperty -Name "ReplicationStatus" -Value $ReplicationStatus
$Object | Add-Member -MemberType NoteProperty -Name "ConnectionStatus" -Value $ConnectionStatus
$Object | Add-Member -MemberType NoteProperty -Name "SourceClusterStatus" -Value $SourceClusterStatus
$Object | Add-Member -MemberType NoteProperty -Name "TargetClusterStatus" -Value $TargetClusterStatus
$Object | Add-Member -MemberType NoteProperty -Name "UsedGB" -Value $UsedGB
$Object | Add-Member -MemberType NoteProperty -Name "IsPaused" -Value $IsPaused
$Object | Add-Member -MemberType NoteProperty -Name "ThrottleEnabled" -Value $ThrottleEnabled
$Object | Add-Member -MemberType NoteProperty -Name "URL" -Value $RSCReplicationURL
# Adding
$RSCReplicationTargets.Add($Object) | Out-Null
# End of for each object below
}
# End of for each object above
#
# Returning array
Return $RSCReplicationTargets
# End of function
}