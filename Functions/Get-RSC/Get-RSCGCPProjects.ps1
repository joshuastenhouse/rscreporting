################################################
# Function - Get-RSCGCPProjects - Getting GCP Projects connected to RSC
################################################
Function Get-RSCGCPProjects {

<#
.SYNOPSIS
A Rubrik Security Cloud (RSC) Reporting Module Function returning all Google Cloud Projects.

.DESCRIPTION
Makes the required GraphQL API calls to RSC via Invoke-RestMethod to get the data as described, then creates a usable array of the returned information, removing the need for the PowerShell user to understand GraphQL in order to interact with RSC.

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.OUTPUTS
Returns an array of all the available information on the GraphQL endpoint in a uniform and usable format.

.EXAMPLE
Get-GCPProjects
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
# Getting All RSCGCPProjects 
################################################
# Creating array for objects
$GCPProjectList = @()
# Building GraphQL query
$RSCGraphQL = @{"operationName" = "GCPProjectsListQuery";

"variables" = @{
"first" = 1000
};

"query" = "query GCPProjectsListQuery(`$first: Int!, `$after: String) {
  gcpNativeProjects(first: `$first, after: `$after) {
    edges {
      cursor
      node {
        id
        status
        name
        ...GcpProjectNumberColumnFragment
        ...GcpProjectIdColumnFragment
        slaAssignment
        lastRefreshedAt
        organizationName
        ...EffectiveSlaColumnFragment
        ...GcpVmcountColumnFragment
        diskCount
        authorizedOperations
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
}
fragment GcpProjectNumberColumnFragment on GcpNativeProject {
  projectNumber
  __typename
}
fragment GcpProjectIdColumnFragment on GcpNativeProject {
  nativeId
  __typename
}
fragment EffectiveSlaColumnFragment on HierarchyObject {
  id
  effectiveSlaDomain {
    ...EffectiveSlaDomainFragment
    ... on GlobalSlaReply {
      description
      __typename
    }
    __typename
  }
  ... on CdmHierarchyObject {
    pendingSla {
      ...SLADomainFragment
      __typename
    }
    __typename
  }
  __typename
}
fragment EffectiveSlaDomainFragment on SlaDomain {
  id
  name
  ... on GlobalSlaReply {
    isRetentionLockedSla
    __typename
  }
  ... on ClusterSlaDomain {
    fid
    cluster {
      id
      name
      __typename
    }
    isRetentionLockedSla
    __typename
  }
  __typename
}
fragment SLADomainFragment on SlaDomain {
  id
  name
  ... on ClusterSlaDomain {
    fid
    cluster {
      id
      name
      __typename
    }
    __typename
  }
  __typename
}
fragment GcpVmcountColumnFragment on GcpNativeProject {
  vmCount
  __typename
}"
}
################################################
# API Call To RSC GraphQL URI
################################################
# Querying API
$GCPProjectListResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
# Setting variable
$GCPProjectList += $GCPProjectListResponse.data.gcpNativeProjects.edges.node
# Getting all results from paginations
While ($GCPProjectListResponse.data.gcpNativeProjects.pageInfo.hasNextPage) 
{
# Getting next set
$RSCGraphQL.variables.after = $GCPProjectListResponse.data.gcpNativeProjects.pageInfo.endCursor
$GCPProjectListResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
$GCPProjectList += $GCPProjectListResponse.data.gcpNativeProjects.edges.node
}
################################################
# Processing
################################################
# Creating array
$GCPProjects = [System.Collections.ArrayList]@()
# Time for refresh since
$UTCDateTime = [System.DateTime]::UtcNow
# For Each Object Getting Data
ForEach ($GCPProject in $GCPProjectList)
{
# Setting variables
$GCPProjectName = $GCPProject.name
$GCPProjectID = $GCPProject.id
$GCPProjectNumber = $GCPProject.projectNumber
$GCPProjectNativeID = $GCPProject.nativeId
$GCPProjectVMCount = $GCPProject.vmCount
$GCPProjectDiskCount = $GCPProject.diskCount
$GCPProjectSLADomainInfo = $GCPProject.effectiveSlaDomain
$GCPProjectSLADomain = $GCPProjectSLADomainInfo.name
$GCPProjectSLADomainID = $GCPProjectSLADomainInfo.id
$GCPProjectStatus = $GCPProject.status
$GCPProjectLastRefreshedUNIX = $GCPProject.lastRefreshedAt
# Converting to UTC
Try
{
IF($GCPProjectLastRefreshedUNIX -ne $null){$GCPProjectLastRefreshedUTC = Convert-RSCUNIXTime $GCPProjectLastRefreshedUNIX}ELSE{$GCPProjectLastRefreshedUTC = $null}
}Catch{$GCPProjectLastRefreshedUTC = $null}
# Getting URL
$GCPProjectURL = Get-RSCObjectURL -ObjectType "gcpProject" -ObjectID $GCPProjectID
# Adding To Array
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
$Object | Add-Member -MemberType NoteProperty -Name "Project" -Value $GCPProjectName
$Object | Add-Member -MemberType NoteProperty -Name "ProjectID" -Value $GCPProjectID
$Object | Add-Member -MemberType NoteProperty -Name "VMCount" -Value $GCPProjectVMCount
$Object | Add-Member -MemberType NoteProperty -Name "DiskCount" -Value $GCPProjectDiskCount
$Object | Add-Member -MemberType NoteProperty -Name "SLADomain" -Value $GCPProjectSLADomain
$Object | Add-Member -MemberType NoteProperty -Name "SLADomainID" -Value $GCPProjectSLADomainID
$Object | Add-Member -MemberType NoteProperty -Name "Status" -Value $GCPProjectStatus
$Object | Add-Member -MemberType NoteProperty -Name "LastRefreshed" -Value $GCPProjectLastRefreshedUTC
$Object | Add-Member -MemberType NoteProperty -Name "ProjectNumber" -Value $GCPProjectNumber
$Object | Add-Member -MemberType NoteProperty -Name "ProjectNativeID" -Value $GCPProjectNativeID
$Object | Add-Member -MemberType NoteProperty -Name "URL" -Value $GCPProjectURL
# Adding
$GCPProjects.Add($Object) | Out-Null
# End of for each object below
}
# End of for each object above
# Returning array
Return $GCPProjects
# End of function
}