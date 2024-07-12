################################################
# Function - Get-RSCVMwareClusters - Getting all VMware clusters connected to the RSC instance
################################################
Function Get-RSCVMwareClusters {

<#
.SYNOPSIS
A Rubrik Security Cloud (RSC) Reporting Module Function returning a list of all VMware hosts (ESXi servers).

.DESCRIPTION
Makes the required GraphQL API calls to RSC via Invoke-RestMethod to get the data as described, then creates a usable array of the returned information, removing the need for the PowerShell user to understand GraphQL in order to interact with RSC.

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.OUTPUTS
Returns an array of all the available information on the GraphQL endpoint in a uniform and usable format.

.EXAMPLE
Get-RSCVMwareClusters
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
# Getting All VMware Hosts 
################################################
# Creating array for objects
$RSCList = @()
# Building GraphQL query
$RSCGraphQL = @{"operationName" = "vSphereComputeClusters";

"variables" = @{
"first" = 1000
};

"query" = "query vSphereComputeClusters(`$first: Int, `$after: String) {
  vSphereComputeClusters(first: `$first, after: `$after) {
    count
    edges {
      node {
        id
        ioFilterStatus
        name
        objectType
        slaAssignment
        slaPauseStatus
        effectiveSlaDomain {
          id
          name
        }
        drsStatus
        logicalPath {
          fid
          name
          objectType
        }
        numWorkloadDescendants
      }
    }
  }
}"
}
################################################
# API Call To RSC GraphQL URI
################################################
# Querying API
$RSCListResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
# Setting variable
$RSCList += $RSCListResponse.data.vSphereComputeClusters.edges.node
# Getting all results from paginations
While ($RSCListResponse.data.vSphereComputeClusters.pageInfo.hasNextPage) 
{
# Getting next set
$RSCGraphQL.variables.after = $RSCListResponse.data.vSphereComputeClusters.pageInfo.endCursor
$RSCListResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
$RSCList += $RSCListResponse.data.vSphereComputeClusters.edges.node
}
################################################
# Processing List
################################################
# Creating array
$RSCVMwareClusters = [System.Collections.ArrayList]@()
# For Each Object Getting Data
ForEach ($RSCObject in $RSCList)
{
# Setting variables
$ClusterName = $RSCObject.name
$ClusterID = $RSCObject.id
$SLADomain = $RSCObject.effectiveSlaDomain.name
$SLADomainID = $RSCObject.effectiveSlaDomain.id
$SLAAssignment = $RSCObject.slaAssignment
$SLAIsPaused = $RSCObject.slaPauseStatus
$DRSEnabled = $RSCObject.drsStatus
$IOFilterStatus = $RSCObject.ioFilterStatus
$ClusterVMs = $RSCObject.numWorkloadDescendants
$LogicalPath = $RSCObject.logicalPath
$DatacenterInfo = $LogicalPath | Where-Object {$_.objectType -eq "VSphereDatacenter"}
$Datacenter = $DatacenterInfo.name
$DatacenterID = $DatacenterInfo.fid
$vCenterInfo = $LogicalPath | Where-Object {$_.objectType -eq "VSphereVCenter"}
$vCenter = $vCenterInfo.name
$vCenterID = $vCenterInfo.fid
# Getting URL
$ClusterURL = Get-RSCObjectURL -ObjectType "vCenterCluster" -ObjectID $ClusterID
# Adding To Array
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
$Object | Add-Member -MemberType NoteProperty -Name "Cluster" -Value $ClusterName
$Object | Add-Member -MemberType NoteProperty -Name "ClusterID" -Value $ClusterID
$Object | Add-Member -MemberType NoteProperty -Name "Datacenter" -Value $Datacenter
$Object | Add-Member -MemberType NoteProperty -Name "DatacenterID" -Value $DatacenterID
$Object | Add-Member -MemberType NoteProperty -Name "vCenter" -Value $vCenter
$Object | Add-Member -MemberType NoteProperty -Name "vCenterID" -Value $vCenterID
$Object | Add-Member -MemberType NoteProperty -Name "VMs" -Value $ClusterVMs
$Object | Add-Member -MemberType NoteProperty -Name "IOFilter" -Value $IOFilterStatus
$Object | Add-Member -MemberType NoteProperty -Name "DRSEnabled" -Value $DRSEnabled
$Object | Add-Member -MemberType NoteProperty -Name "SLADomain" -Value $SLADomain
$Object | Add-Member -MemberType NoteProperty -Name "SLADomainID" -Value $SLADomainID
$Object | Add-Member -MemberType NoteProperty -Name "SLAAssignment" -Value $SLAAssignment
$Object | Add-Member -MemberType NoteProperty -Name "SLAIsPaused" -Value $SLAIsPaused
$Object | Add-Member -MemberType NoteProperty -Name "URL" -Value $ClusterURL
# Adding
$RSCVMwareClusters.Add($Object) | Out-Null
# End of for each vCenter below
}
# End of for each vCenter above

# Returning array
Return $RSCVMwareClusters
# End of function
}