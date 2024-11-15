################################################
# Function - Start-RSCMSSQLLiveMount - Requests a live mount for an MSSQL database
################################################
Function Start-RSCMSSQLLiveMount {
	
<#
.SYNOPSIS
Requests a live mount for an MSSQL database, make sure you use a unique TargetDBName everytime to avoid conflicts on DB mount or when unmounting.

.DESCRIPTION
The user has to specify the source database ID, target instance ID on which to mount, and the target DB name which is the name of the SQL database on the target instance (make sure it's unique otherwise the mount will fail)

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.PARAMETER DBID
The ID of the database to be live mounted, use Get-RSCMSSQLDatabases to get a valid DBID, can also use the ObjectID of the SQL database (same thing).
.PARAMETER TargetInstanceID
The ID of a valid instance to mount the SQL database to, use Get-RSCMSSQLInstances for a list of all available. You can also use the UI to validate if it's compatible with the database chosen. You can also pull it from the URL in the UI by navigating to the instance you want to mount to, I.E
https://rubrik-gaia.my.rubrik.com/inventory_hierarchy/mssql/hosts_instances/instance/c152e0d1-78e0-515d-9008-1129657b7f5e?object_status=%7B%22listedOptions%22%3A%5B%5D%2C%22selectedIds%22%3A%5B%22PROTECTED%22%2C%22UNPROTECTED%22%5D%7D
From the above the instance ID is c152e0d1-78e0-515d-9008-1129657b7f5e
.PARAMETER TargetDBName
The name for the SQL database when mounted on the target instance ID, make sure it's unique otherwise MSSQL will fail to mount the database and the job will fail.

.OUTPUTS
Returns an array with the status of the on-demand snapshot request.

.EXAMPLE
Start-RSCMSSQLLiveMount -DBID "71c0820a-3fbd-5e91-878f-42da723aa371" -InstanceID "b9aa64d6-5967-5c4c-80aa-938db39857f0" -TargetDBName "DemoLiveMount"
This example prompts for the RSC URL, user ID and secret, then connects to RSC and securely stores them for subsequent use in the script directory specified.

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
        [Parameter(Mandatory=$true)]
        [string]$TargetInstanceID,
        [Parameter(Mandatory=$true)]
        [string]$TargetDBName
    )
################################################
# Importing Module & Running Required Functions
################################################
# Importing module
Import-Module RSCReporting
# Checking connectivity, exiting function with error if not
Test-RSCConnection
# Getting list of instances
$SQLInstanceList = Get-RSCMSSQLInstances
# Getting list of databases
$SQLDatabaseList = Get-RSCMSSQLDatabases
# Validating DBID
IF($SQLDatabaseList.DBID -match $DBID){$DBIDFound = $TRUE}ELSE{$DBIDFound = $FALSE;Write-Warning "Specified DBID $DBID not found on Get-MSSQLDatabases"}
# Validating TargetInstanceID
IF($SQLDatabaseList.InstanceID -match $TargetInstanceID){$TargetInstanceIDFound = $TRUE}ELSE{$TargetInstanceIDFound = $FALSE;Write-Warning "Specified TargetInstanceID $TargetInstanceID not found on Get-MSSQLInstances"}
# Getting latest recovery point for the DB
IF($DBIDFound -eq $TRUE){$SQLDBRecoveryPoint = Get-RSCMSSQLDatabaseRecoveryPoints -DBID $DBID -RecoveryPointOnly | Select-Object -ExpandProperty RecoveryPoint}
# Showing error if no recovery point
IF($SQLDBRecoveryPoint -eq $null){Write-Warning "No valid RecoveryPoint found for DBID $DBID using Get-MSSQLDatabaseRecoveryPoints, ensure the DB is actually protected and being succesfully backed up"}
################################################
# Requesting Live Mount IF Valid Settings
################################################
# $DBID = "71c0820a-3fbd-5e91-878f-42da723aa371"
# $TargetInstanceID = "b9aa64d6-5967-5c4c-80aa-938db39857f0"
# $TargetDBName = "LateNightJSDemo"
# RP: 2023-10-10T07:45:36.000Z
IF(($DBIDFound -eq $TRUE) -and ($TargetInstanceIDFound -eq $TRUE) -and ($SQLDBRecoveryPoint -ne $null))
{
# Getting DB friendly name
$DBName = $SQLDatabaseList | Where-Object {$_.DBID -eq $DBID} | Select-Object -ExpandProperty DB
# Building GraphQL query
$RSCGraphQL = @{"operationName" = "MssqlDatabaseMountMutation";

"variables" = @{
    "input" = @{
        "id" = "$DBID"
        "config" = @{
               "targetInstanceId" = "$TargetInstanceID"
               "mountedDatabaseName" = "$TargetDBName"
               "recoveryPoint" = @{
                                "date" = "$SQLDBRecoveryPoint"
                                 }
                    }
                }
};

"query" = "mutation MssqlDatabaseMountMutation(`$input: CreateMssqlLiveMountInput!) {
  createMssqlLiveMount(input: `$input) {
    id
    links {
      href
      rel
      __typename
    }
    __typename
  }
}"
}
# Querying API
Try
{
$RSCResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
$RequestStatus = "SUCCESS"
}
Catch
{
$RequestStatus = "FAILED"
}
# Checking for permission errors
IF($RSCResponse.errors.message){$RSCResponse.errors.message}
# Getting response
$JobURL = $RSCResponse.data.createMssqlLiveMount.links.href
$JobID = $RSCResponse.data.createMssqlLiveMount.id
################################################
# Returing Job Info
################################################
# Adding To Array
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
$Object | Add-Member -MemberType NoteProperty -Name "Mutation" -Value "MssqlDatabaseMountMutation"
$Object | Add-Member -MemberType NoteProperty -Name "RequestStatus" -Value $RSCRequest
$Object | Add-Member -MemberType NoteProperty -Name "DBID" -Value $DBID
$Object | Add-Member -MemberType NoteProperty -Name "TargetInstanceID" -Value $TargetInstanceID
$Object | Add-Member -MemberType NoteProperty -Name "TargetDBName" -Value $TargetDBName
$Object | Add-Member -MemberType NoteProperty -Name "RecoveryPoint" -Value $SQLDBRecoveryPoint
$Object | Add-Member -MemberType NoteProperty -Name "RequestStatus" -Value $RequestStatus
$Object | Add-Member -MemberType NoteProperty -Name "JobID" -Value $JobID
$Object | Add-Member -MemberType NoteProperty -Name "ErrorMessage" -Value $RSCResponse.errors.message
# Returning array
Return $Object
# Not returning anything if didn't pass validation below
}
# Not returning anything if didn't pass validation above

# End of function
}