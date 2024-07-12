################################################
# Function - Get-RSCHostFilesetObjects - Getting all Objects on Physical hosts filesets connected to the RSC instance, used by the Get-RSCFilesets function
################################################
Function Get-RSCHostFilesetObjects {

<#
.SYNOPSIS
A Rubrik Security Cloud (RSC) Reporting Module Function, primarily used for Get-RSCFilesets, as they are assigned per host, not designed to be used on its own.

.DESCRIPTION
Makes the required GraphQL API calls to RSC via Invoke-RestMethod to get the data as described, then creates a usable array of the returned information, removing the need for the PowerShell user to understand GraphQL in order to interact with RSC.

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.OUTPUTS
Returns an array of all the available information on the GraphQL endpoint in a uniform and usable format.

.EXAMPLE
Get-RSCHostFilesetObjects
This example returns an array of all the information returned by the GraphQL endpoint for this object type.

.NOTES
Author: Joshua Stenhouse
Date: 05/11/2023
#>

################################################
# Importing Module & Running Required Functions
################################################
# Importing the module is it needs other modules
Import-Module RSCReporting
# Checking connectivity, exiting function with error if not connected
Test-RSCConnection
################################################
# Getting All RSC Hosts
################################################
# Creating array for objects
$RSCHostList = @()
# Fileset types
$RSCHostTypes = "LINUX_HOST_ROOT","WINDOWS_HOST_ROOT","NAS_HOST_ROOT" # "EXCHANGE_ROOT"
# Building GraphQL query
ForEach($RSCHostType in $RSCHostTypes)
{
$RSCGraphQL = @{"operationName" = "PhysicalHosts";

"variables" = @{
"first" = 1000
"hostRoot" = $RSCHostType
};

"query" = "query PhysicalHosts(`$hostRoot: HostRoot!, `$first: Int, `$after: String) {
  physicalHosts(hostRoot: `$hostRoot, first: `$first, after: `$after) {
    edges {
      node {
        cdmId
        id
        objectType
        name
        osName
        osType
        primaryClusterLocation {
                  clusterUuid
                  id
                  name
                }
        descendantConnection {
          edges {
            node {
              ... on LinuxFileset {
                id
                name
                cdmId
                effectiveSlaDomain {
                  id
                  name
                }
                isRelic
                isPassThrough
                hardlinkSupportEnabled
                newestArchivedSnapshot {
                  id
                  date
                }
                newestReplicatedSnapshot {
                  id
                  date
                }
                newestSnapshot {
                  id
                  date
                }
                objectType
                numWorkloadDescendants
                symlinkResolutionEnabled
                slaPauseStatus
                slaAssignment
                pathIncluded
                pathExcluded
                pathExceptions
                onDemandSnapshotCount
                oldestSnapshot {
                  id
                  date
                }
                latestUserNote {
                  objectId
                  time
                  userNote
                  userName
                }
                physicalPath {
                  fid
                  name
                  objectType
                }
              }
              ... on ShareFileset {
                cdmId
                id
                name
                effectiveSlaDomain {
                  id
                  name
                }
                isPassThrough
                isRelic
                hardlinkSupportEnabled
                nasMigrationInfo
                latestUserNote {
                  objectId
                  time
                  userName
                  userNote
                }
                newestArchivedSnapshot {
                  date
                  id
                }
                newestReplicatedSnapshot {
                  date
                  id
                }
                newestSnapshot {
                  id
                  date
                }
                numWorkloadDescendants
                objectType
                pathExcluded
                pathExceptions
                onDemandSnapshotCount
                physicalPath {
                  fid
                  name
                  objectType
                }
                pathIncluded
                share {
                  name
                  id
                  objectType
                }
                shareType
                slaAssignment
                slaPauseStatus
                symlinkResolutionEnabled
                primaryClusterLocation {
                  clusterUuid
                  id
                  name
                }
                replicatedObjectCount
                oldestSnapshot {
                  id
                  date
                }
              }
              ... on WindowsFileset {
                cdmId
                name
                effectiveSlaDomain {
                  id
                  name
                }
                hardlinkSupportEnabled
                isPassThrough
                isRelic
                latestUserNote {
                  time
                  userNote
                  userName
                }
                newestArchivedSnapshot {
                  id
                  date
                }
                newestReplicatedSnapshot {
                  id
                  date
                }
                newestSnapshot {
                  date
                  id
                }
                numWorkloadDescendants
                onDemandSnapshotCount
                objectType
                pathExcluded
                pathExceptions
                slaAssignment
                pathIncluded
                slaPauseStatus
                symlinkResolutionEnabled
                oldestSnapshot {
                  id
                  date
                }
                id
              }
              ... on HostShare {
                id
                name
                objectType
                nasMigrationInfo
                nasShareType
                numWorkloadDescendants
                physicalPath {
                  objectType
                  fid
                  name
                }
                effectiveSlaDomain {
                  id
                  name
                }
                slaPauseStatus
                slaAssignment
                isChangelistEnabled
                latestUserNote {
                  objectId
                  userNote
                  userName
                  time
                }
              }
            }
          }
        }
      }
    }
  }
}"
}
################################################
# API Call To RSC GraphQL URI
################################################
# Querying API
$RSCHostListResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
# Setting variable
$RSCHostList += $RSCHostListResponse.data.physicalhosts.edges.node
# Getting all results from paginations
While ($RSCHostListResponse.data.physicalhosts.pageInfo.hasNextPage) 
{
# Getting next set
$RSCGraphQL.variables.after = $RSCHostListResponse.data.physicalhosts.pageInfo.endCursor
$RSCHostListResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
$RSCHostList += $RSCHostListResponse.data.physicalhosts.edges.node
}

# End of for each host type below
}
# End of for each host type above
################################################
# Processing Objects
################################################
# Creating array
$RSCObjects = [System.Collections.ArrayList]@()
# For Each Object Getting Data
ForEach ($RSCHost in $RSCHostList)
{
# Setting variables
$HostName = $RSCHost.name
$HostID = $RSCHost.id
$HostCDMID = $RSCHost.cdmId
$HostOSType = $RSCHost.osType
$HostOSName = $RSCHost.osName
$HostType = $RSCHost.objectType
# Getting primary cluster info
$HostRubrikCluster = $RSCHost.primaryClusterLocation.name
$HostRubrikClusterID = $RSCHost.primaryClusterLocation.id
# Getting descendants
$HostDescendants = $RSCHost.descendantConnection.edges.node
ForEach($HostDescendant in $HostDescendants)
{
$ObjectType = $HostDescendant.objectType
$ObjectName = $HostDescendant.name
$ObjectID = $HostDescendant.id
$ObjectCDMID = $HostDescendant.cdmId
# Adding To Array
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
$Object | Add-Member -MemberType NoteProperty -Name "ObjectType" -Value $ObjectType
$Object | Add-Member -MemberType NoteProperty -Name "Object" -Value $ObjectName
$Object | Add-Member -MemberType NoteProperty -Name "ObjectID" -Value $ObjectID
$Object | Add-Member -MemberType NoteProperty -Name "ObjectCDMID" -Value $ObjectCDMID
$Object | Add-Member -MemberType NoteProperty -Name "Host" -Value $HostName
$Object | Add-Member -MemberType NoteProperty -Name "HostID" -Value $HostID
$Object | Add-Member -MemberType NoteProperty -Name "HostCDMID" -Value $HostCDMID
$Object | Add-Member -MemberType NoteProperty -Name "HostType" -Value $HostType
$Object | Add-Member -MemberType NoteProperty -Name "OSType" -Value $HostOSType
$Object | Add-Member -MemberType NoteProperty -Name "OSName" -Value $HostOSName
$Object | Add-Member -MemberType NoteProperty -Name "ObjectData" -Value $HostDescendant
$Object | Add-Member -MemberType NoteProperty -Name "RubrikCluster" -Value $HostRubrikCluster
$Object | Add-Member -MemberType NoteProperty -Name "RubrikClusterID" -Value $HostRubrikClusterID
$RSCObjects.Add($Object) | Out-Null
}
# End of for each host below
}
# End of for each host above

# Removing entries where not object ID, as it must be a host with no fileset
$RSCObjects = $RSCObjects | Where-Object {$_.ObjectID -ne $null}

# Returning array
Return $RSCObjects
# End of function
}