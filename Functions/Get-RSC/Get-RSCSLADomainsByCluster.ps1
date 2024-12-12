################################################
# Function - Get-RSCSLADomainsByCluster - Getting all global SLA domains in use by each cluster in RSC
################################################
Function Get-RSCSLADomainsByCluster {

<#
.SYNOPSIS
A Rubrik Security Cloud (RSC) Reporting Module Function returns a list of all SLA domains in use by each cluster in RSC.

.DESCRIPTION
Makes the required GraphQL API calls to RSC via Invoke-RestMethod to get the data as described, then creates a usable array of the returned information, removing the need for the PowerShell user to understand GraphQL in order to interact with RSC.

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.OUTPUTS
Returns an array of all the available information on the GraphQL endpoint in a uniform and usable format.

.EXAMPLE
Get-RSCSLADomains
This example returns an array of all the information returned by the GraphQL endpoint for this object type.

.NOTES
Author: Joshua Stenhouse
Date: 12/03/2024
#>

################################################
# Importing Module & Running Required Functions
################################################
# Importing the module is it needs other modules
Import-Module RSCReporting
# Checking connectivity, exiting function with error if not connected
Test-RSCConnection
################################################
# Getting Global SLA Domains
################################################
$RSCSLADomainList = Get-RSCSLADomains
# Filtering for only SLAs with protected objects, otherwise it cannot have any clusters because nothing is using it
$RSCSLADomainList = $RSCSLADomainList | Where-Object {$_.ProtectedObjects -gt 0}
################################################
# Processing Global RSC SLA Domains
################################################
# Building array to store SLAs
$RSCSLADomains = [System.Collections.ArrayList]@()
# Cycling through each global SLA to get the settings required
ForEach ($GlobalSLA in $RSCSLADomainList)
{
# Setting variables
$SLADomainID = $GlobalSLA.SLADomainID
$SLADomainName = $GlobalSLA.SLADomain
$SLADomainDescription = $GlobalSLA.Description
# Creating graphql query
$RSCGraphQL = @{"operationName" = "ProtectedClustersForGlobalSlaQuery";

"variables" = @{
"slaId" = "$SLADomainID"
};

"query" = "query ProtectedClustersForGlobalSlaQuery(`$slaId: UUID!, `$first: Int, `$last: Int, `$after: String, `$before: String) {
  protectedClustersForGlobalSla(slaId: `$slaId, first: `$first, last: `$last, before: `$before, after: `$after) {
    edges {
      node {
        id
        name
        status
        version
        state {
          connectedState
          __typename
        }
        __typename
      }
      __typename
    }
    __typename
  }
}"
}
# Querying API
Try
{
$RSCResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Headers $RSCSessionHeader -Body $($RSCGraphQL | ConvertTo-JSON -Depth 10)
$RSCSLADomainClusters = $RSCResponse.data.protectedClustersForGlobalSla.edges.node
}
Catch
{
$ErrorMessage = $_.ErrorDetails; "ERROR: $ErrorMessage"
$SLADomainID
}
# Adding each cluster to the array
ForEach ($RSCSLADomainCluster in $RSCSLADomainClusters)
{
# Setting variables
$ClusterName = $RSCSLADomainCluster.name
$ClusterID = $RSCSLADomainCluster.id
$ClusterStatus = $RSCSLADomainCluster.status
$ClusterVersion = $RSCSLADomainCluster.version
# Getting SLA domainURL
$SLADomainURL = Get-RSCObjectURL -ObjectType "SlaDomain" -ObjectID $SLADomainID
# Adding to array
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
$Object | Add-Member -MemberType NoteProperty -Name "RubrikCluster" -Value $ClusterName
$Object | Add-Member -MemberType NoteProperty -Name "RubrikClusterID" -Value $ClusterID
$Object | Add-Member -MemberType NoteProperty -Name "Status" -Value $ClusterStatus
$Object | Add-Member -MemberType NoteProperty -Name "Version" -Value $ClusterVersion
$Object | Add-Member -MemberType NoteProperty -Name "SLADomain" -Value $SLADomainName
$Object | Add-Member -MemberType NoteProperty -Name "SLADomainID" -Value $SLADomainID
$Object | Add-Member -MemberType NoteProperty -Name "Description" -Value $SLADomainDescription
$Object | Add-Member -MemberType NoteProperty -Name "URL" -Value $SLADomainURL
# Adding to array
$RSCSLADomains.Add($Object) | Out-Null
# 
# End of for each cluster SLA below
}
# End of for each cluster SLA above
#
# End of for each SLA below
}
# End of for each SLA above
#
# Returning array
Return $RSCSLADomains
# End of function
}