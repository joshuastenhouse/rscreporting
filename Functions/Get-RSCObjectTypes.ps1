################################################
# Function - Get-RSCObjectTypes - Getting all object types visible to the RSC instance
################################################
Function Get-RSCObjectTypes {

<#
.SYNOPSIS
A Rubrik Security Cloud (RSC) Reporting Module Function returning all object types visible to RSC. Don't use these for event filtering, they won't match, use Get-RSCEventObjectTypes instead.

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
# Paramater Config
################################################
Param
    (
        [Parameter(ParameterSetName="User")][switch]$GetLiveViaObjectQuery
    )
################################################
# Importing Module & Running Required Functions
################################################
# Importing the module is it needs other modules
Import-Module RSCReporting
# Checking connectivity, exiting function with error if not connected
Test-RSCConnection
################################################
# Getting All Objects 
################################################
# Using default list unless told to query all
IF($GetLiveViaObjectQuery)
{
# Creating array for objects
$RSCObjectsList = @()
# Building GraphQL query
$RSCGraphQL = @{"operationName" = "snappableConnection";

"variables" = @{
"first" = 1000
};

"query" = "query snappableConnection(`$after: String`$first: Int) {
  snappableConnection(after: `$after, first: `$first) {
    edges {
      node {
        archivalComplianceStatus
        archivalSnapshotLag
        archiveSnapshots
        archiveStorage
        awaitingFirstFull
        complianceStatus
        dataReduction
        fid
        id
        lastSnapshot
        latestArchivalSnapshot
        latestReplicationSnapshot
        localOnDemandSnapshots
        location
        localSnapshots
        logicalBytes
        logicalDataReduction
        missedSnapshots
        name
        objectType
        physicalBytes
        protectedOn
        protectionStatus
        pullTime
        replicaSnapshots
        replicaStorage
        replicationComplianceStatus
        slaDomain {
          id
          name
          version
        }
        replicationSnapshotLag
        totalSnapshots
        transferredBytes
        cluster {
          id
          name
        }
      }
    }
        pageInfo {
      endCursor
      hasNextPage
      hasPreviousPage
      __typename
    }
  }
}"
}
################################################
# API Call To RSC GraphQL URI
################################################
# Querying API
$RSCResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
# Setting variable
$RSCObjectsList += $RSCResponse.data.snappableConnection.edges.node
# Counters
$ObjectCount = 0
$ObjectCounter = $ObjectCount + 1000
# Getting all results from paginations
While ($RSCResponse.data.snappableConnection.pageInfo.hasNextPage) 
{
# Logging
Write-Host "GettingObjects: $ObjectCount-$ObjectCounter"
# Getting next set
$RSCGraphQL.variables.after = $RSCResponse.data.snappableConnection.pageInfo.endCursor
$RSCResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
$RSCObjectsList += $RSCResponse.data.snappableConnection.edges.node
# Incrementing
$ObjectCount = $ObjectCount + 1000
$ObjectCounter = $ObjectCounter + 1000
}

# Selecting unique objects
$RSCObjectTypes = $RSCObjectsList | Select-Object -ExpandProperty objectType -Unique | Sort-Object

}ELSE{$RSCObjectTypes = "ACTIVE_DIRECTORY_DOMAIN_CONTROLLER","AWS_NATIVE_S3_BUCKET","AwsNativeEbsVolume","AwsNativeRdsInstance","AZURE_AD_DIRECTORY","AZURE_SQL_DATABASE_DB","AzureNativeManagedDisk","AzureNativeVm","CLOUD_DIRECT_NAS_EXPORT","Db2Database","Ec2Instance","ExchangeDatabase","GcpNativeDisk","GcpNativeGCEInstance","HypervVirtualMachine","JIRA_FIXED_OBJECT","JIRA_PROJECT","K8S_PROTECTION_SET","LinuxFileset","ManagedVolume","MONGO_COLLECTION_SET","Mssql","NutanixVirtualMachine","O365File","O365Mailbox","O365Onedrive","O365Site","O365Teams","OracleDatabase","SapHanaDatabase","ShareFileset","VmwareVirtualMachine","WindowsFileset","WindowsVolumeGroup"}
# Returning array
Return $RSCObjectTypes
# End of function
}
