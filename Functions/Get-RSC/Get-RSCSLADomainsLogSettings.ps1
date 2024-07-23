################################################
# Creating the Get-RSCSLADomainsLogSettings function
################################################
Function Get-RSCSLADomainsLogSettings {
	
<#
.SYNOPSIS
A Rubrik Security Cloud (RSC) Reporting Module Function for obtaining database log backup settings of an SLA domain ID.

.DESCRIPTION
Makes the required GraphQL API calls to RSC via Invoke-RestMethod to get the data as described, then creates a usable array of the returned information, removing the need for the PowerShell user to understand GraphQL in order to interact with RSC.
.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.PARAMETER SLADomainID
A valid SLADomainID for the SLADomain on which you want to get log settings. Use Get-RSCSLADomains to obtain.

.OUTPUTS
Returns an array of all the available information on the GraphQL endpoint in a uniform and usable format.

.EXAMPLE
Connect-RSCReporting -SLADomainID = "00000-000000-00000-000002"
This example returns the database log config for the SLADomainID specified.

.NOTES
Author: Joshua Stenhouse
Date: 05/11/2023
#>
################################################
# Paramater Config
################################################
Param (
    [Parameter(Mandatory=$true)]
    [String]$SLADomainID
  )

################################################
# Importing Module & Running Required Functions
################################################
# Importing the module is it needs other modules
Import-Module RSCReporting
# Checking connectivity, exiting function with error if not connected
Test-RSCConnection
################################################
# Running Main Function
################################################
$RSCGraphQL = @{"operationName" = "LogBackupPropertiesSlaQuery";

"variables" = @{
"id" = "$SLADomainID"
};

"query" = "query LogBackupPropertiesSlaQuery(`$id: UUID!) {
  slaDomain(id: `$id) {
    id
    name
    objectSpecificConfigs {
      mssqlConfig {
        frequency {
          duration
          unit
          __typename
        }
        logRetention {
          duration
          duration
          unit
          __typename
        }
        __typename
      }
      oracleConfig {
        frequency {
          duration
          unit
          __typename
        }
        logRetention {
          duration
          duration
          unit
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
################################################
# API Call To RSC GraphQL URI
################################################
# Querying API
Try
{
$RSCResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Headers $RSCSessionHeader -Body $($RSCGraphQL | ConvertTo-JSON -Depth 10)
$RSCSLADomain = $RSCResponse.data.slaDomain
}
Catch
{
$ErrorMessage = $_.ErrorDetails; "ERROR: $ErrorMessage"
}
# Creating array
$Array = [System.Collections.ArrayList]@()
# Processing Response
ForEach ($SLADomain in $RSCSLADomain)
{
# Setting variables
$SLAObjectConfigs = $SLADomain.objectSpecificConfigs
# MSSQL config
$MSSQLConfig = $SLAObjectConfigs.mssqlConfig
IF($MSSQLConfig -ne $null){$MSSQLConfigured = $TRUE}ELSE{$MSSQLConfigured = $FALSE}
$MSSQLLogFrequency = $MSSQLConfig.frequency
$MSSQLLogFrequencyDuration = $MSSQLLogFrequency.duration
$MSSQLLogFrequencyUnit = $MSSQLLogFrequency.unit
$MSSQLLogRetention = $MSSQLConfig.logRetention
$MSSQLLogRetentionDuration = $MSSQLLogRetention.duration
$MSSQLLogRetentionUnit = $MSSQLLogRetention.unit
# Converting log retention to days if minutes equal or greater than 1 day
IF(($MSSQLLogRetentionUnit -eq "MINUTES") -and ($MSSQLLogRetentionDuration -ge 1440))
{
$MSSQLLogRetentionDuration = $MSSQLLogRetentionDuration / 1440; $MSSQLLogRetentionDuration = [Math]::Round($MSSQLLogRetentionDuration,0)
$MSSQLLogRetentionUnit = "DAYS"
}
# Oracle config
$OracleConfig = $SLAObjectConfigs.oracleConfig
IF($OracleConfig -ne $null){$OracleConfigured = $TRUE}ELSE{$OracleConfigured = $FALSE}
$OracleLogFrequency = $OracleConfig.frequency
$OracleLogFrequencyDuration = $OracleLogFrequency.duration
$OracleLogFrequencyUnit = $OracleLogFrequency.unit
$OracleLogRetention = $OracleConfig.logRetention
$OracleLogRetentionDuration = $OracleLogRetention.duration
$OracleLogRetentionUnit = $OracleLogRetention.unit
# Converting log retention to days if minutes equal or greater than 1 day
IF(($OracleLogRetentionUnit -eq "MINUTES") -and ($OracleLogRetentionDuration -ge 1440))
{
$OracleLogRetentionDuration = $OracleLogRetentionDuration / 1440; $OracleLogRetentionDuration = [Math]::Round($OracleLogRetentionDuration,0)
$OracleLogRetentionUnit = "DAYS"
}
# Adding
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
$Object | Add-Member -MemberType NoteProperty -Name "SLADomainID" -Value $SLADomainID
# MSSQL specific SLA configurations
$Object | Add-Member -MemberType NoteProperty -Name "MSSQLConfigured" -Value $MSSQLConfigured
$Object | Add-Member -MemberType NoteProperty -Name "MSSQLLogFrequency" -Value $MSSQLLogFrequencyDuration
$Object | Add-Member -MemberType NoteProperty -Name "MSSQLLogFrequencyUnit" -Value $MSSQLLogFrequencyUnit
$Object | Add-Member -MemberType NoteProperty -Name "MSSQLLogRetention" -Value $MSSQLLogRetentionDuration
$Object | Add-Member -MemberType NoteProperty -Name "MSSQLLogRetentionUnit" -Value $MSSQLLogRetentionUnit
# Oracle specific SLA configurations
$Object | Add-Member -MemberType NoteProperty -Name "OracleConfigured" -Value $OracleConfigured
$Object | Add-Member -MemberType NoteProperty -Name "OracleLogFrequency" -Value $OracleLogFrequencyDuration
$Object | Add-Member -MemberType NoteProperty -Name "OracleLogFrequencyUnit" -Value $OracleLogFrequencyUnit
$Object | Add-Member -MemberType NoteProperty -Name "OracleLogRetention" -Value $OracleLogRetentionDuration
$Object | Add-Member -MemberType NoteProperty -Name "OracleLogRetentionUnit" -Value $OracleLogRetentionUnit
$Array.Add($Object) | Out-Null
}

# Returning Result
Return $Array
}