################################################
# Function - Get-RSCFilesetTemplates - Getting all Filesets on the RSC instance
################################################
Function Get-RSCFilesetTemplates {

<#
.SYNOPSIS
A Rubrik Security Cloud (RSC) Reporting Module Function returning all fileset templates.

.DESCRIPTION
Makes the required GraphQL API calls to RSC via Invoke-RestMethod to get the data as described, then creates a usable array of the returned information, removing the need for the PowerShell user to understand GraphQL in order to interact with RSC.

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.OUTPUTS
Returns an array of all the available information on the GraphQL endpoint in a uniform and usable format.

.EXAMPLE
Get-RSCFilesetTemplates
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
# Getting All Filesets
################################################
# Creating array for objects
$RSCFilesetList = @()
# Fileset types
$RSCFilesetTypes = "LINUX_HOST_ROOT","WINDOWS_HOST_ROOT","NAS_HOST_ROOT"
# Building GraphQL query
ForEach($RSCFilesetType in $RSCFilesetTypes)
{
$RSCGraphQL = @{"operationName" = "FilesetTemplates";

"variables" = @{
"first" = 1000
"hostRoot" = $RSCFilesetType
};

"query" = "query FilesetTemplates(`$hostRoot: HostRoot!, `$first: Int, `$after: String) {
  filesetTemplates(hostRoot: `$hostRoot, first: `$first, after: `$after) {
    edges {
      node {
        id
        name
        includes
        isArrayEnabled  
	    allowBackupHiddenFoldersInNetworkMounts
        allowBackupNetworkMounts
        backupScriptErrorHandling
        exceptions
        excludes
        effectiveSlaDomain {
          id
          name
        }
        latestUserNote {
          objectId
          time
          userNote
          userName
        }
        numWorkloadDescendants
        objectType
        osType
        shareType
        physicalPath {
          objectType
          name
          fid
        }
        postBackupScript
        preBackupScript
        primaryClusterLocation {
          clusterUuid
          name
          id
        }
        replicatedObjectCount
        shareType
        slaAssignment
        slaPauseStatus
 
      }
    }
    pageInfo {
      endCursor
      hasNextPage
      hasPreviousPage
      startCursor
    }
  }
}"
}
################################################
# API Call To RSC GraphQL URI
################################################
# Querying API
$RSCFilesetListResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
# Setting variable
$RSCFilesetList += $RSCFilesetListResponse.data.filesetTemplates.edges.node
# Getting all results from paginations
While ($RSCFilesetListResponse.data.filesetTemplates.pageInfo.hasNextPage) 
{
# Getting next set
$RSCGraphQL.variables.after = $RSCFilesetListResponse.data.filesetTemplates.pageInfo.endCursor
$RSCFilesetListResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
$RSCFilesetList += $RSCFilesetListResponse.data.filesetTemplates.edges.node
}

# End of for each host type below
}
# End of for each host type above
################################################
# Processing Fileset Templates
################################################
# Creating array
$RSCFilesetTemplates = [System.Collections.ArrayList]@()
# For Each Object Getting Data
ForEach ($RSCFileset in $RSCFilesetList)
{
# Setting variables
$FilesetID = $RSCFileset.id
$FilesetName = $RSCFileset.name
$FilesetIncludes = $RSCFileset.includes
$FilesetExcludes = $RSCFileset.excludes
$FilesetExceptions = $RSCFileset.exceptions
$FilesetType = $RSCFileset.objectType
$FilesetOSType = $RSCFileset.osType
$FilesetShareType = $RSCFileset.shareType
$FilesetIsArrayEnabled = $RSCFileset.isArrayEnabled
$FilesetBackupHiddenFolders = $RSCFileset.allowBackupHiddenFoldersInNetworkMounts
$FilesetBackupNetworkMounts = $RSCFileset.allowBackupNetworkMounts
# Adding To Array
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
$Object | Add-Member -MemberType NoteProperty -Name "FilesetTemplate" -Value $FilesetName
$Object | Add-Member -MemberType NoteProperty -Name "FilesetTemplateID" -Value $FilesetID
$Object | Add-Member -MemberType NoteProperty -Name "Includes" -Value $FilesetIncludes
$Object | Add-Member -MemberType NoteProperty -Name "Excludes" -Value $FilesetExcludes
$Object | Add-Member -MemberType NoteProperty -Name "Exceptions" -Value $FilesetExceptions
$Object | Add-Member -MemberType NoteProperty -Name "Type" -Value $FilesetType
$Object | Add-Member -MemberType NoteProperty -Name "OSType" -Value $FilesetOSType
$Object | Add-Member -MemberType NoteProperty -Name "ShareType" -Value $FilesetShareType
$Object | Add-Member -MemberType NoteProperty -Name "IsArrayEnabled" -Value $FilesetIsArrayEnabled
$Object | Add-Member -MemberType NoteProperty -Name "BackupNetworkMounts" -Value $FilesetBackupHiddenFolders
$Object | Add-Member -MemberType NoteProperty -Name "BackupHiddenFolders" -Value $FilesetBackupNetworkMounts
$RSCFilesetTemplates.Add($Object) | Out-Null
# End of for each object below
}
# End of for each object above

# Returning array
Return $RSCFilesetTemplates
# End of function
}