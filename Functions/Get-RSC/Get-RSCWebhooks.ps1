################################################
# Function - Get-RSCWebhooks - Getting Webhooks configured in RSC
################################################
Function Get-RSCWebhooks {

<#
.SYNOPSIS
A Rubrik Security Cloud (RSC) Reporting Module Function returning a list of all configured webhooks.

.DESCRIPTION
Makes the required GraphQL API calls to RSC via Invoke-RestMethod to get the data as described, then creates a usable array of the returned information, removing the need for the PowerShell user to understand GraphQL in order to interact with RSC.

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.OUTPUTS
Returns an array of all the available information on the GraphQL endpoint in a uniform and usable format.

.EXAMPLE
Get-RSCWebhooks
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
# Building GraphQL query
$RSCGraphQL = @{"operationName" = "AllWebhooksQuery";

"variables" = @{
};

"query" = "query AllWebhooksQuery(`$name: String) {
  allWebhooks(name: `$name) {
    nodes {
      id
      name
      url
      authType
      status
      providerType
      subscriptionSeverity {
        eventSeverities
        auditSeverities
        __typename
      }
      subscriptionType {
        eventTypes
        auditTypes
        isSubscribedToAllEvents
        isSubscribedToAllAudits
        __typename
      }
      lastFailedErrorInfo {
        statusCode
        errorMessage
        __typename
      }
      serverCertificate
      __typename
      createdAt
      createdBy
      description
      updatedAt
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
# Setting variables
$RSCList += $RSCResponse.data.allWebhooks.nodes
################################################
# Processing List
################################################
# Creating array
$RSCWebhooks = [System.Collections.ArrayList]@()
# For Each Object Getting Data
ForEach ($Webhook in $RSCList)
{
# Setting variables
$ID = $Webhook.id
$Name = $Webhook.name
$URL = $Webhook.url
$Authtype = $Webhook.authType
$Status = $Webhook.status
$Provider = $Webhook.providerType
$Description = $Webhook.description
$CreatedUNIX = $Webhook.createdAt
$CreatedBy = $Webhook.createdBy
$LastUpdatedUNIX = $Webhook.updatedAt
$SubscriptionSeverity = $Webhook.subscriptionSeverity.eventSeverities
$SubscriptionAuditSeverity = $Webhook.subscriptionSeverity.auditSeverities
$SubscriptionType = $Webhook.subscriptionType.eventTypes
$SubscriptionAuditType = $Webhook.subscriptionType.auditTypes
$LastFailureInfo = $Webhook.lastFailedErrorInfo
# Converting dates
IF($LastUpdatedUNIX -ne $null){$LastUpdatedUTC = Convert-RSCUNIXTime $LastUpdatedUNIX}ELSE{$LastUpdatedUTC = $null}
IF($CreatedUNIX -ne $null){$CreatedUTC = Convert-RSCUNIXTime $CreatedUNIX}ELSE{$CreatedUTC = $null}
# Adding To Array
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
$Object | Add-Member -MemberType NoteProperty -Name "Webhook" -Value $Name
$Object | Add-Member -MemberType NoteProperty -Name "WebhookID" -Value $ID
$Object | Add-Member -MemberType NoteProperty -Name "URL" -Value $URL
$Object | Add-Member -MemberType NoteProperty -Name "AuthType" -Value $Authtype
$Object | Add-Member -MemberType NoteProperty -Name "Provider" -Value $Provider
$Object | Add-Member -MemberType NoteProperty -Name "Status" -Value $Status
$Object | Add-Member -MemberType NoteProperty -Name "Description" -Value $Description
$Object | Add-Member -MemberType NoteProperty -Name "LastUpdatedUTC" -Value $LastUpdatedUTC
$Object | Add-Member -MemberType NoteProperty -Name "CreatedUTC" -Value $CreatedUTC
$Object | Add-Member -MemberType NoteProperty -Name "CreatedBy" -Value $CreatedBy
$Object | Add-Member -MemberType NoteProperty -Name "SubscriptionSeverity" -Value $SubscriptionSeverity
$Object | Add-Member -MemberType NoteProperty -Name "SubscriptionType" -Value $SubscriptionType
$Object | Add-Member -MemberType NoteProperty -Name "AuditSeverity" -Value $SubscriptionAuditSeverity
$Object | Add-Member -MemberType NoteProperty -Name "AuditType" -Value $SubscriptionAuditType
$Object | Add-Member -MemberType NoteProperty -Name "LastFailureInfo" -Value $LastFailureInfo
# Adding
$RSCWebhooks.Add($Object) | Out-Null
# End of for each object below
}
# End of for each object above
#
# Returning array
Return $RSCWebhooks
# End of function
}