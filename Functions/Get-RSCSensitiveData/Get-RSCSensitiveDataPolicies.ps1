################################################
# Function - Get-RSCSensitiveDataPolicies - Getting All Sensitive Data Policies in RSC
################################################
Function Get-RSCSensitiveDataPolicies {

<#
.SYNOPSIS
A Rubrik Security Cloud (RSC) Reporting Module Function returns a list of all sensitive data discovery policies.

.DESCRIPTION
Makes the required GraphQL API calls to RSC via Invoke-RestMethod to get the data as described, then creates a usable array of the returned information, removing the need for the PowerShell user to understand GraphQL in order to interact with RSC.

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.OUTPUTS
Returns an array of all the available information on the GraphQL endpoint in a uniform and usable format.

.EXAMPLE
Get-RSCSensitiveDataPolicies
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
# Querying RSC GraphQL API
################################################
# Creating array for objects
$RSCList = @()
# Getting date in correct format
$UTCDate = [System.DateTime]::UtcNow.ToString("yyyy-MM-dd")
# Building GraphQL query
$RSCGraphQL = @{"operationName" = "Policies";

"query" = "query Policies {
  policies {
    count
    nodes {
      analyzers {
        analyzerRiskInstance {
          analyzerId
          risk
          riskVersion
        }
        analyzerType
        dictionary
        dictionaryCsv
        id
        name
        regex
      }
      colorEnum
      createdTime
      creator {
        email
        domain
        id
        username
      }
      deletable
      description
      id
      lastUpdatedTime
      mode
      name
      numAnalyzers
      objectStatuses {
        id
        latestSnapshotResult {
          snapshotTime
          snapshotFid
        }
        policyStatuses {
          status
          policyId
        }
      }
      totalObjects
      whitelists {
        nativePath
        snappable {
          id
          name
          objectType
        }
        stdPath
        updateTs
        updateUsername
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
$RSCObjectListResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
# Setting variable
$RSCObjectList += $RSCObjectListResponse.data.policies.nodes
################################################
# Processing List
################################################
# Creating array
$RSCSDDPolicies = [System.Collections.ArrayList]@()
$RSCSDDPolicyObjects = [System.Collections.ArrayList]@()
$RSCSDDPolicyAnalyzers = [System.Collections.ArrayList]@()
# For Each Object Getting Data
ForEach ($SDDPolicy in $RSCObjectList)
{
# Setting variables
$ID = $SDDPolicy.id
$Name = $SDDPolicy.name
$Description = $SDDPolicy.description
$AnalyzersCount = $SDDPolicy.numAnalyzers
$Analyzers = $SDDPolicy.analyzers
$TotalObjects = $SDDPolicy.totalObjects
$Objects = $SDDPolicy.objectStatuses
# Iterating through objects
$ObjectsUptoDateCounter = 0
ForEach($ObjectID in $Objects)
{
$ObjectStatus = $ObjectID.policyStatuses | Select-Object -ExpandProperty status -First 1
IF($ObjectStatus -eq "UP_TO_DATE"){$ObjectsUptoDateCounter++}
# Adding To Array
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
$Object | Add-Member -MemberType NoteProperty -Name "Policy" -Value $Name
$Object | Add-Member -MemberType NoteProperty -Name "PolicyID" -Value $ID
$Object | Add-Member -MemberType NoteProperty -Name "ObjectID" -Value $ObjectID.id
$Object | Add-Member -MemberType NoteProperty -Name "Status" -Value $ObjectStatus
# Adding
$RSCSDDPolicyObjects.Add($Object) | Out-Null
}
# Iterating through Analyzers
ForEach($Analyzer in $Analyzers)
{
$AnalyzerID = $Analyzer.id
$AnalyzerName = $Analyzer.name
$AnalyzerType = $Analyzer.type
$AnalyzerRegex = $Analyzer.regex
$AnalyzerDictionary = $Analyzer.dictionary
$AnalyzerDictionaryCSV = $Analyzer.dictionaryCSV
$AnalyzerRiskInstance = $Analyzer.riskInstance
# Adding To Array
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
$Object | Add-Member -MemberType NoteProperty -Name "Policy" -Value $Name
$Object | Add-Member -MemberType NoteProperty -Name "PolicyID" -Value $ID
$Object | Add-Member -MemberType NoteProperty -Name "Analyzer" -Value $AnalyzerName
$Object | Add-Member -MemberType NoteProperty -Name "AnalyzerID" -Value $AnalyzerID
$Object | Add-Member -MemberType NoteProperty -Name "Type" -Value $AnalyzerType
$Object | Add-Member -MemberType NoteProperty -Name "Regex" -Value $AnalyzerRegex
$Object | Add-Member -MemberType NoteProperty -Name "Dictionary" -Value $AnalyzerDictionary
$Object | Add-Member -MemberType NoteProperty -Name "DictionaryCSV" -Value $AnalyzerDictionaryCSV
$Object | Add-Member -MemberType NoteProperty -Name "Risk" -Value $AnalyzerRiskInstance
# Adding
$RSCSDDPolicyAnalyzers.Add($Object) | Out-Null
}
# Deciding status
IF($ObjectsUptoDateCounter -eq $TotalObjects){$Status = "UP_TO_DATE"}ELSE{$Status = "STALE"}
# Getting URL
$PolicyURL = Get-RSCObjectURL -ObjectType "SDDPolicy" -ObjectID $ID
# Adding To Array
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
$Object | Add-Member -MemberType NoteProperty -Name "Policy" -Value $Name
$Object | Add-Member -MemberType NoteProperty -Name "PolicyID" -Value $ID
$Object | Add-Member -MemberType NoteProperty -Name "Objects" -Value $TotalObjects
$Object | Add-Member -MemberType NoteProperty -Name "ObjectsUptoDate" -Value $ObjectsUptoDateCounter
$Object | Add-Member -MemberType NoteProperty -Name "Status" -Value $Status
$Object | Add-Member -MemberType NoteProperty -Name "Analyzers" -Value $AnalyzersCount
$Object | Add-Member -MemberType NoteProperty -Name "Description" -Value $Description
$Object | Add-Member -MemberType NoteProperty -Name "URL" -Value $PolicyURL
# Adding
$RSCSDDPolicies.Add($Object) | Out-Null
# End of for each object below
}
# End of for each object above
#
# Returning array
Return $RSCSDDPolicies
# End of function
}