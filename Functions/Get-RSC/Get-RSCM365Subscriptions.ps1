################################################
# Function - Get-RSCM365Subscriptions - Getting o365 subscriptions connected to RSC
################################################
Function Get-RSCM365Subscriptions {

<#
.SYNOPSIS
A Rubrik Security Cloud (RSC) Reporting Module Function returning a list of all M365 subscriptions.

.DESCRIPTION
Makes the required GraphQL API calls to RSC via Invoke-RestMethod to get the data as described, then creates a usable array of the returned information, removing the need for the PowerShell user to understand GraphQL in order to interact with RSC.

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.OUTPUTS
Returns an array of all the available information on the GraphQL endpoint in a uniform and usable format.

.EXAMPLE
Get-RSCM365Subscriptions
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
# Getting All o365 Subscriptions 
################################################
# Creating array for objects
$o365SubscriptionList = @()
# Building GraphQL query
$o365SubscriptionGraphql = @{"operationName" = "o365Orgs";

"variables" = @{
"first" = 100
};

"query" = "query o365Orgs(`$first: Int, `$after: String) {
  o365Orgs(first: `$first, after: `$after) {
    edges {
      node {
        status
        past1DayMailboxComplianceCount
        past1DayMailboxOutOfComplianceCount
        past1DayOnedriveComplianceCount
        past1DayOnedriveOutOfComplianceCount
        past1DaySharepointComplianceCount
        past1DaySharepointOutOfComplianceCount
        past1DayTeamsComplianceCount
        past1DayTeamsOutOfComplianceCount
        past1DaySpListComplianceCount
        past1DaySpListOutOfComplianceCount
        past1DaySpSiteCollectionComplianceCount
        past1DaySpSiteCollectionOutOfComplianceCount
        id
        unprotectedUsersCount
        name
        objectType
        slaAssignment
        searchDescendantConnection {
          edges {
            node {
              id
              name
              objectType
              slaAssignment
              effectiveSlaDomain {
                id
                name
              }
            }
          }
          }
        effectiveSlaDomain {
          id
          name
        }
        numWorkloadDescendants
      }
    }
              pageInfo {
      endCursor
      hasNextPage
      hasPreviousPage
    }
  }
}
"
}
################################################
# API Call To RSC GraphQL URI
################################################
# Querying API
$o365SubscriptionResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($o365SubscriptionGraphql | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
# Setting variable
$o365SubscriptionList += $o365SubscriptionResponse.data.o365Orgs.edges.node
# Getting all results from paginations
While ($o365SubscriptionResponse.data.o365Orgs.pageInfo.hasNextPage) 
{
# Getting next set
$o365SubscriptionGraphql.variables.after = $o365SubscriptionResponse.data.o365Orgs.pageInfo.endCursor
$o365SubscriptionResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($o365SubscriptionGraphql | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
$o365SubscriptionList += $o365SubscriptionResponse.data.o365Orgs.edges.node
}
################################################
# Processing 
################################################
# Creating array
$o365Subscriptions = [System.Collections.ArrayList]@()
# Time for refresh since
$UTCDateTime = [System.DateTime]::UtcNow
# For Each Object Getting Data
ForEach ($o365Sub in $o365SubscriptionList)
{
# Setting variables
$o365SubName = $o365Sub.name
$o365SubID = $o365Sub.id
$o365SubUnprotectedUsers = $o365Sub.unprotectedUsersCount
$o365SubStatus = $o365Sub.status
$o365SubSLAAssignment = $o365Sub.slaAssignment
$o365SubSLADomain = $o365Sub.effectiveSlaDomain.name
$o365SubSLADomainID = $o365Sub.effectiveSlaDomain.id
# Selecting oject types
$O365Objects = $o365Sub.searchDescendantConnection.edges.node
$o365SubMailboxes = $O365Objects | Where-Object {$_.objectType -eq "O365Mailbox"} 
$o365SubOneDrives = $O365Objects | Where-Object {$_.objectType -eq "O365Onedrive"} 
$o365SubSharepointDrives = $O365Objects | Where-Object {$_.objectType -eq "O365SharePointDrive"}
$o365SubSharepointLists = $O365Objects | Where-Object {$_.objectType -eq "O365SharePointList"} 
$o365SubSharepointSites = $O365Objects | Where-Object {$_.objectType -eq "O365Site"} 
$o365SubTeams = $O365Objects | Where-Object {$_.objectType -eq "O365Teams"}
# Totalling objects
$o365SubTotalMailboxes = $o365SubMailboxes | Measure-Object | Select-Object -ExpandProperty Count
$o365SubTotalOneDrives = $o365SubOneDrives | Measure-Object | Select-Object -ExpandProperty Count
$o365SubTotalSharepointDrives = $o365SubSharepointDrives | Measure-Object | Select-Object -ExpandProperty Count
$o365SubTotalSharepointLists = $o365SubSharepointLists | Measure-Object | Select-Object -ExpandProperty Count
$o365SubTotalSharepointSites = $o365SubSharepointSites | Measure-Object | Select-Object -ExpandProperty Count
$o365SubTotalTeams = $o365SubTeams | Measure-Object | Select-Object -ExpandProperty Count
# Filtering per object type
$o365SubProtectedMailboxes = $o365SubMailboxes | Where-Object {(($_.effectiveSlaDomain.name -ne "UNPROTECTED") -and ($_.effectiveSlaDomain.name -ne "DO_NOT_PROTECT"))} | Measure-Object | Select-Object -ExpandProperty Count
$o365SubUnprotectedMailboxes = $o365SubMailboxes | Where-Object {$_.effectiveSlaDomain.name -eq "UNPROTECTED"} | Measure-Object | Select-Object -ExpandProperty Count
$o365SubDoNotProtectMailboxes = $o365SubMailboxes | Where-Object {$_.effectiveSlaDomain.name -eq "DO_NOT_PROTECT"} | Measure-Object | Select-Object -ExpandProperty Count
$o365SubProtectedOneDrives = $o365SubOneDrives | Where-Object {(($_.effectiveSlaDomain.name -ne "UNPROTECTED") -and ($_.effectiveSlaDomain.name -ne "DO_NOT_PROTECT"))} | Measure-Object | Select-Object -ExpandProperty Count
$o365SubUnprotectedOneDrives = $o365SubOneDrives | Where-Object {$_.effectiveSlaDomain.name -eq "UNPROTECTED"} | Measure-Object | Select-Object -ExpandProperty Count
$o365SubDoNotProtectOneDrives = $o365SubOneDrives | Where-Object {$_.effectiveSlaDomain.name -eq "DO_NOT_PROTECT"} | Measure-Object | Select-Object -ExpandProperty Count
$o365SubProtectedSharepointDrives = $o365SubSharepointDrives | Where-Object {(($_.effectiveSlaDomain.name -ne "UNPROTECTED") -and ($_.effectiveSlaDomain.name -ne "DO_NOT_PROTECT"))} | Measure-Object | Select-Object -ExpandProperty Count
$o365SubUnprotectedSharepointDrives = $o365SubSharepointDrives | Where-Object {$_.effectiveSlaDomain.name -eq "UNPROTECTED"} | Measure-Object | Select-Object -ExpandProperty Count
$o365SubDoNotProtectSharepointDrives = $o365SubSharepointDrives | Where-Object {$_.effectiveSlaDomain.name -eq "DO_NOT_PROTECT"} | Measure-Object | Select-Object -ExpandProperty Count
$o365SubSharepointLists | Where-Object {(($_.effectiveSlaDomain.name -ne "UNPROTECTED") -and ($_.effectiveSlaDomain.name -ne "DO_NOT_PROTECT"))} | Measure-Object | Select-Object -ExpandProperty Count
$o365SubUnprotectedSharepointLists = $o365SubSharepointLists | Where-Object {$_.effectiveSlaDomain.name -eq "UNPROTECTED"} | Measure-Object | Select-Object -ExpandProperty Count
$o365SubDoNotProtectSharepointLists = $o365SubSharepointLists | Where-Object {$_.effectiveSlaDomain.name -eq "DO_NOT_PROTECT"} | Measure-Object | Select-Object -ExpandProperty Count
$o365SubProtectedSharepointSites = $o365SubSharepointSites | Where-Object {(($_.effectiveSlaDomain.name -ne "UNPROTECTED") -and ($_.effectiveSlaDomain.name -ne "DO_NOT_PROTECT"))} | Measure-Object | Select-Object -ExpandProperty Count
$o365SubUnprotectedSharepointSites = $o365SubSharepointSites | Where-Object {$_.effectiveSlaDomain.name -eq "UNPROTECTED"} | Measure-Object | Select-Object -ExpandProperty Count
$o365SubDoNotProtectSharepointSites = $o365SubSharepointSites | Where-Object {$_.effectiveSlaDomain.name -eq "DO_NOT_PROTECT"} | Measure-Object | Select-Object -ExpandProperty Count
$o365SubProtectedTeams = $o365SubTeams | Where-Object {(($_.effectiveSlaDomain.name -ne "UNPROTECTED") -and ($_.effectiveSlaDomain.name -ne "DO_NOT_PROTECT"))} | Measure-Object | Select-Object -ExpandProperty Count
$o365SubUnprotectedTeams = $o365SubTeams | Where-Object {$_.effectiveSlaDomain.name -eq "UNPROTECTED"} | Measure-Object | Select-Object -ExpandProperty Count
$o365SubDoNotProtectTeams = $o365SubTeams | Where-Object {$_.effectiveSlaDomain.name -eq "DO_NOT_PROTECT"} | Measure-Object | Select-Object -ExpandProperty Count
# All objects
$o365SubProtectedObjects = $o365SubProtectedMailboxes + $o365SubProtectedOneDrives + $o365SubProtectedSharepointDrives + $o365SubProtectedSharepointLists + $o365SubProtectedSharepointSites + $o365SubProtectedTeams
$o365SubUnprotectedObjects = $o365SubUnprotectedMailboxes + $o365SubUnprotectedOneDrives + $o365SubUnprotectedSharepointDrives + $o365SubUnprotectedSharepointLists + $o365SubUnprotectedSharepointSites + $o365SubUnprotectedTeams
$o365SubDoNotProtectObjects = $o365SubDoNotProtectMailboxes + $o365SubDoNotProtectOneDrives + $o365SubDoNotProtectSharepointDrives + $o365SubDoNotProtectSharepointLists + $o365SubDoNotProtectSharepointSites + $o365SubDoNotProtectTeams
# Combining the above, using the direct object list doesn't work as it counts users twice (as you can protect a user)
$o365SubTotalObjects = $o365SubProtectedObjects + $o365SubUnprotectedObjects + $o365SubDoNotProtectObjects
# Compliance 
$o365Subpast1DayMailboxComplianceCount = $o365Sub.past1DayMailboxComplianceCount
$o365Subpast1DayMailboxOutOfComplianceCount = $o365Sub.past1DayMailboxOutOfComplianceCount
$o365Subpast1DayOnedriveComplianceCount = $o365Sub.past1DayOnedriveComplianceCount
$o365Subpast1DayOnedriveOutOfComplianceCount = $o365Sub.past1DayOnedriveOutOfComplianceCount
$o365Subpast1DaySharepointComplianceCount = $o365Sub.past1DaySharepointComplianceCount 
$o365Subpast1DaySharepointOutOfComplianceCount = $o365Sub.past1DaySharepointOutOfComplianceCount
$o365Subpast1DaySpListComplianceCount = $o365Sub.past1DaySpListComplianceCount
$o365Subpast1DaySpListOutOfComplianceCount = $o365Sub.past1DaySpListOutOfComplianceCount
$o365Subpast1DaySpSiteCollectionComplianceCount = $o365Sub.past1DaySpSiteCollectionComplianceCount
$o365Subpast1DaySpSiteCollectionOutOfComplianceCount = $o365Sub.past1DaySpSiteCollectionOutOfComplianceCount
$o365Subpast1DayTeamsComplianceCount = $o365Sub.past1DayTeamsComplianceCount
$o365Subpast1DayTeamsOutOfComplianceCount = $o365Sub.past1DayTeamsOutOfComplianceCount
# All
$o365SubTotalObjectsInCompliance = $o365Subpast1DayMailboxComplianceCount + $o365Subpast1DayOnedriveComplianceCount + $o365Subpast1DaySharepointComplianceCount + $o365Subpast1DayTeamsComplianceCount + $o365Subpast1DaySpListComplianceCount + $SharepointSitesCompliance
$o365SubTotalObjectsOutofCompliance = $o365Subpast1DayMailboxOutOfComplianceCount + $o365Subpast1DayOnedriveOutOfComplianceCount + $o365Subpast1DaySharepointOutOfComplianceCount + $o365Subpast1DayTeamsOutOfComplianceCount + $o365Subpast1DaySpListOutOfComplianceCount + $o365Subpast1DaySpSiteCollectionOutOfComplianceCount
# Calculating unprotected
$o365SubTotalUnProtectedObjects = $o365SubTotalObjects - $o365SubTotalProtectedObjects
$o365SubTotalUnProtectedMailboxes = $TotalMailboxes - $ProtectedMailboxes
$o365SubTotalUnProtectedOneDrives = $TotalOneDrives - $ProtectedOneDrives
$o365SubTotalUnProtectedSharepointDrives = $TotalSharepointDrives - $ProtectedSharepointDrives
$o365SubTotalUnProtectedSharepointLists = $TotalSharepointLists - $ProtectedSharepointLists
$o365SubTotalUnProtectedSharepointSites = $TotalSharepointSites - $ProtectedSharepointSites
$o365SubTotalUnProtectedTeams = $TotalTeams - $ProtectedTeams
# Creating URL
# https://rubrik-gaia.my.rubrik.com/inventory_hierarchy/o365/org/f62800ad-1c84-418e-9b77-38d422941a62/users
# https://rubrik-gaia.my.rubrik.com/inventory_hierarchy/o365?subscriptionId=f62800ad-1c84-418e-9b77-38d422941a62
$ObjectURL = $RSCURL + "/inventory_hierarchy/o365?subscriptionId=" + $o365SubID
# Adding To Array
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
$Object | Add-Member -MemberType NoteProperty -Name "Subscription" -Value $o365SubName
$Object | Add-Member -MemberType NoteProperty -Name "SubscriptionID" -Value $o365SubID
$Object | Add-Member -MemberType NoteProperty -Name "SLAAssignment" -Value $o365SubSLAAssignment
$Object | Add-Member -MemberType NoteProperty -Name "SLADomain" -Value $o365SubSLADomain
$Object | Add-Member -MemberType NoteProperty -Name "SLADomainID" -Value $o365SubSLADomainID
$Object | Add-Member -MemberType NoteProperty -Name "Status" -Value $o365SubStatus
# Totals
$Object | Add-Member -MemberType NoteProperty -Name "TotalObjects" -Value $o365SubTotalObjects
$Object | Add-Member -MemberType NoteProperty -Name "TotalMailboxes" -Value $o365SubTotalMailboxes
$Object | Add-Member -MemberType NoteProperty -Name "TotalOneDrives" -Value $o365SubTotalOneDrives
$Object | Add-Member -MemberType NoteProperty -Name "TotalSharepointDrives" -Value $o365SubTotalSharepointDrives
$Object | Add-Member -MemberType NoteProperty -Name "TotalSharepointLists" -Value $o365SubTotalSharepointLists
$Object | Add-Member -MemberType NoteProperty -Name "TotalSharepointSites" -Value $o365SubTotalSharepointSites
$Object | Add-Member -MemberType NoteProperty -Name "TotalTeams" -Value $o365SubTotalTeams
# Protected
$Object | Add-Member -MemberType NoteProperty -Name "ProtectedObjects" -Value $o365SubProtectedObjects
$Object | Add-Member -MemberType NoteProperty -Name "ProtectedMailboxes" -Value $o365SubProtectedMailboxes
$Object | Add-Member -MemberType NoteProperty -Name "ProtectedOneDrives" -Value $o365SubProtectedOneDrives
$Object | Add-Member -MemberType NoteProperty -Name "ProtectedSharepointDrives" -Value $o365SubProtectedSharepointDrives
$Object | Add-Member -MemberType NoteProperty -Name "ProtectedSharepointLists" -Value $o365SubProtectedSharepointLists
$Object | Add-Member -MemberType NoteProperty -Name "ProtectedSharepointSites" -Value $o365SubProtectedSharepointSites
$Object | Add-Member -MemberType NoteProperty -Name "ProtectedTeams" -Value $o365SubProtectedTeams
# Unprotected
$Object | Add-Member -MemberType NoteProperty -Name "UnprotectedObjects" -Value $o365SubUnprotectedObjects
$Object | Add-Member -MemberType NoteProperty -Name "UnprotectedMailboxes" -Value $o365SubUnprotectedMailboxes
$Object | Add-Member -MemberType NoteProperty -Name "UnprotectedOneDrives" -Value $o365SubUnprotectedOneDrives
$Object | Add-Member -MemberType NoteProperty -Name "UnprotectedSharepointDrives" -Value $o365SubUnprotectedSharepointDrives
$Object | Add-Member -MemberType NoteProperty -Name "UnprotectedSharepointLists" -Value $o365SubUnprotectedSharepointLists
$Object | Add-Member -MemberType NoteProperty -Name "UnprotectedSharepointSites" -Value $o365SubUnprotectedSharepointSites
$Object | Add-Member -MemberType NoteProperty -Name "UnprotectedTeams" -Value $o365SubUnprotectedTeams
# Do not protect
$Object | Add-Member -MemberType NoteProperty -Name "DoNotProtectedObjects" -Value $o365SubDoNotProtectObjects
$Object | Add-Member -MemberType NoteProperty -Name "DoNotProtectedMailboxes" -Value $o365SubDoNotProtectMailboxes
$Object | Add-Member -MemberType NoteProperty -Name "DoNotProtectedOneDrives" -Value $o365SubDoNotProtectOneDrives
$Object | Add-Member -MemberType NoteProperty -Name "DoNotProtectedSharepointDrives" -Value $o365SubDoNotProtectSharepointDrives
$Object | Add-Member -MemberType NoteProperty -Name "DoNotProtectedSharepointLists" -Value $o365SubDoNotProtectSharepointLists
$Object | Add-Member -MemberType NoteProperty -Name "DoNotProtectedSharepointSites" -Value $o365SubDoNotProtectSharepointSites
$Object | Add-Member -MemberType NoteProperty -Name "DoNotProtectedTeams" -Value $o365SubDoNotProtectTeams
# Compliance
$Object | Add-Member -MemberType NoteProperty -Name "TotalObjectsInCompliance" -Value $o365SubTotalObjectsInCompliance
$Object | Add-Member -MemberType NoteProperty -Name "TotalObjectsOutofCompliance" -Value $o365SubTotalObjectsOutofCompliance
# Per object
$Object | Add-Member -MemberType NoteProperty -Name "MailboxCompliance" -Value $o365Subpast1DayMailboxComplianceCount
$Object | Add-Member -MemberType NoteProperty -Name "MailboxOutOfCompliance" -Value $o365Subpast1DayMailboxOutOfComplianceCount
$Object | Add-Member -MemberType NoteProperty -Name "OnedriveCompliance" -Value $o365Subpast1DayOnedriveComplianceCount
$Object | Add-Member -MemberType NoteProperty -Name "OnedriveOutOfCompliance" -Value $o365Subpast1DayOnedriveOutOfComplianceCount
$Object | Add-Member -MemberType NoteProperty -Name "SharepointDrivesCompliance" -Value $o365Subpast1DaySharepointComplianceCount
$Object | Add-Member -MemberType NoteProperty -Name "SharepointDrivesOutOfCompliance" -Value $o365Subpast1DaySharepointOutOfComplianceCount
$Object | Add-Member -MemberType NoteProperty -Name "SharepointListCompliance" -Value $o365Subpast1DaySpListComplianceCount
$Object | Add-Member -MemberType NoteProperty -Name "SharepointListOutofCompliance" -Value $o365Subpast1DaySpListOutOfComplianceCount
$Object | Add-Member -MemberType NoteProperty -Name "SharepointSitesCompliance" -Value $o365Subpast1DaySpSiteCollectionComplianceCount
$Object | Add-Member -MemberType NoteProperty -Name "SharepointSitesOutofCompliance" -Value $o365Subpast1DaySpSiteCollectionOutOfComplianceCount
$Object | Add-Member -MemberType NoteProperty -Name "TeamsCompliance" -Value $o365Subpast1DayTeamsComplianceCount
$Object | Add-Member -MemberType NoteProperty -Name "TeamsOutOfCompliance" -Value $o365Subpast1DayTeamsOutOfComplianceCount
$Object | Add-Member -MemberType NoteProperty -Name "URL" -Value $ObjectURL
# Adding
$o365Subscriptions.Add($Object) | Out-Null
# End of for each o365 subscription below
}
# End of for each o365 subscription above
# Returning array
Return $o365Subscriptions
# End of function
}