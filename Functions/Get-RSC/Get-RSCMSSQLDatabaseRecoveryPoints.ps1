################################################
# Function - Get-RSCMSSQLDatabaseRecoveryPoints - Gets the recoverable time frame of an MSSQL database for recovery operations.
################################################
Function Get-RSCMSSQLDatabaseRecoveryPoints {
	
<#
.SYNOPSIS
Gets the recoverable time frame of an MSSQL database for recovery operations.

.DESCRIPTION
Specify the MSSQL database ID in order to get the recoverable range required.

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.PARAMETER DBID
The Database ID obtained from Get-RSCMSSQLDatabases, can also use ObjectID as DBID

.OUTPUTS
Returns an array with the status of the add host request.

.EXAMPLE
Get-RSCMSSQLDatabaseRecoveryPoints -DBID "f2c1a2e6-9d1c-5072-ae59-07e2ff102ebb"

.NOTES
Author: Joshua Stenhouse
Date: 10/10/2023
#>
################################################
# Paramater Config
################################################
[CmdletBinding()]
    Param (
        [Parameter(Mandatory=$true)]
        [string]$DBID,
        [switch]$RecoveryPointOnly
    )

################################################
# Importing Module & Running Required Functions
################################################
# Importing
Import-Module RSCReporting
# Checking connectivity, exiting function with error if not
Test-RSCConnection
################################################
# API Call To RSC GraphQL URI
################################################
# Building GraphQL query
$RSCGraphQL = @{"operationName" = "MssqlDatabaseRecoverableRangesQuery";

"variables" = @{
    "fid" = "$DBID"
};

"query" = "query MssqlDatabaseRecoverableRangesQuery(`$fid: String!) {
  mssqlRecoverableRanges(input: {id: `$fid}) {
    data {
      beginTime
      endTime
      __typename
    }
    __typename
  }
}"
}
# Querying API
$RSCResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
# Checking for permission errors
IF($RSCResponse.errors.message){$RSCResponse.errors.message}
# Setting timestamp
$UTCDateTime = [System.DateTime]::UtcNow
################################################
# Returing Job Info
################################################
# Creating array
$RecoveryPoints = [System.Collections.ArrayList]@()
# Setting variables
$RecoverableRangesList = $RSCResponse.data.mssqlRecoverableRanges.data
# Switching order of array to put most recent first
[array]::Reverse($RecoverableRangesList)
# Counter
$RecoverableRangeCounter = 0
# For each recoverable range adding to array
ForEach($RecoverableRange in $RecoverableRangesList)
{
# Incrementing counter
$RecoverableRangeCounter ++
# Deciding if first
IF($RecoverableRangeCounter -eq 1)
{
$MostRecentRecoveryPoint = $RecoverableRange.endTime
}
# Adding To Array
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
$Object | Add-Member -MemberType NoteProperty -Name "QueryTimeUTC" -Value $UTCDateTime
$Object | Add-Member -MemberType NoteProperty -Name "DBID" -Value $DBID
$Object | Add-Member -MemberType NoteProperty -Name "RecoveryPoint" -Value $MostRecentRecoveryPoint
$Object | Add-Member -MemberType NoteProperty -Name "RangeStart" -Value $RecoverableRange.beginTime
$Object | Add-Member -MemberType NoteProperty -Name "RangeEnd" -Value $RecoverableRange.endTime
# Adding
$RecoveryPoints.Add($Object) | Out-Null
# End of for each recoverable range below
}
# End of for each recoverable range above

# IF switch used, only returning the 1st recoverable range
IF($RecoveryPointOnly)
{
$RecoveryPoints = $RecoveryPoints | Select-Object -First 1
}

# Returning array
Return $RecoveryPoints
# End of function
}