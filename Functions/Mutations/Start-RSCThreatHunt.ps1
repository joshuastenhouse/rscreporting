################################################
# Function - Start-RSCThreatHunt - Start a threat hunt for the specified objects & IOCs
################################################
Function Start-RSCThreatHunt {

<#
.SYNOPSIS
A Rubrik Security Cloud (RSC) Reporting Module Function that starts a threat hunt using the variables configured.

.DESCRIPTION
This function validates all the ObjectIDs specified are valid, then starts a threat hunt using the IOCs and variables configured.

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.PARAMETER ObjectIDs
A single ObjectID or list in the format "ObjectID1,ObjectID2,ObjectID3"
.PARAMETER ThreatHuntName
The name of your threat hunt, ensure it is unique, check using Get-RSCThreatHunts.
.PARAMETER IOCs
The indicatorsOfCompromise to hunt for. For an example use Get-RSCSampleYARARules
.PARAMETER IOCType
Enter or select IOC_YARA or IOC_HASH depending on whether you specified a yara rule in IOCs or hashes.
.PARAMETER UseDemoIOCs
Use this if you just want to search for the Rubrik backup agent as a demonstration and don't want to enter any IOCs.
.PARAMETER FileExclude
Optional, leave as null for the default which is none.
.PARAMETER FileException
Optional, leave as null for the default which is none.
.PARAMETER IOCMaxSizeBytes
Optional, leave as null for the default which is 10000000 bytes (10MB).
.PARAMETER IOCMinSizeBytes
Optional, leave as null for the default which is 256000 bytes (256KB).
.PARAMETER MaxSnapshotsPerObject
Optional, leave as null for the default which is 1, just the last backup.
.PARAMETER MaxMatchesPerSnapshot
Optional, leave as null for the default which is 100.
.PARAMETER FileInclude
Optional, leave as null for the default which is all files.

.OUTPUTS
Returns an array of all the available information on the GraphQL endpoint in a uniform and usable format.

.EXAMPLE
Start-RSCThreatHunt -ObjectIDs "ObjectID1,ObjectID2,ObjectID3" -ThreatHuntName "Test From SDK" -IOCType IOC_YARA -UseDemoIOCs
This example starts a threat hunt for the objects IDs specified with the built-in YARA sample.

.NOTES
Author: Joshua Stenhouse
Date: 05/11/2023
#>
################################################
# Paramater Config
################################################
Param 
  (
  [Parameter(Mandatory=$true)]
  $ObjectIDs,
  [Parameter(Mandatory=$true)]
  [String]$ThreatHuntName,
  [Parameter(Mandatory=$false)]
  [String]$IOCs,
  [Parameter(Mandatory=$false)]
  [ValidateSet("IOC_YARA","IOC_HASH")]
  $IOCType,
  [switch]$UseDemoIOCs,
  $FileExclude,
  $FileException,
  $IOCMaxSizeBytes,
  $IOCMinSizeBytes,
  $MaxSnapshotsPerObject,
  $MaxMatchesPerSnapshot,
  $FileInclude
  )

# Setting defaults if null
IF($FileExclude -eq $null){$FileExclude = ""}
IF($FileException -eq $null){$FileException = ""}
IF($IOCMaxSizeBytes -eq $null){$IOCMaxSizeBytes = 10000000}
IF($IOCMinSizeBytes -eq $null){$IOCMinSizeBytes = 256000}
IF($MaxSnapshotsPerObject -eq $null){$MaxSnapshotsPerObject = 1}
IF($MaxMatchesPerSnapshot -eq $null){$MaxMatchesPerSnapshot = 100}
IF($FileInclude -eq $null){$FileInclude = "**"}

# Checking function hasn't been passed multiple To ObjectIs in a string, formatting if so
IF($ObjectIDs -match ","){$ObjectIDs = $ObjectIDs.Split(",")}

# Getting RSC Protected Object list
$RSCObjects = Get-RSCProtectedObjects

# Verifying all object IDs are valid
$ObjectIDCheck = [System.Collections.ArrayList]@()
ForEach($ObjectID in $ObjectIDs)
{
# Checking if exists in list
$ObjectIDList = $RSCObjects | Where-Object {$_.ObjectID -eq $ObjectID}
# Validating
IF($ObjectIDList -eq $null){$ObjectIDInList = $FALSE}ELSE{$ObjectIDInList = $TRUE}
# Getting Rubrik cluster ID
$RubrikClusterID = $ObjectIDList.RubrikClusterID 
# Adding To Array
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "ObjectID" -Value $ObjectID
$Object | Add-Member -MemberType NoteProperty -Name "ObjectIDInList" -Value $ObjectIDInList
$Object | Add-Member -MemberType NoteProperty -Name "RubrikClusterID" -Value $RubrikClusterID
$ObjectIDCheck.Add($Object) | Out-Null
}

# Exiting if not objects found
$ObjectIDCheckCount = $ObjectIDCheck | Where-Object {$_.ObjectIDInList -eq $FALSE} | Measure-Object | Select-Object -ExpandProperty Count
IF($ObjectIDCheckCount -gt 0)
{
Write-Error "ERROR: One or more ObjectIDs not found in Get-RSCProtectedObjects, check and try again.."
Start-Sleep 2
Break
}

# Exiting if all objects not on same Rubrik cluster
$RubrikClusterID = $ObjectIDCheck | Select-Object -ExpandProperty RubrikClusterID -Unique
$RubrikClusterIDCheckCount = $RubrikClusterID | Measure-Object | Select-Object -ExpandProperty Count
IF($RubrikClusterIDCheckCount -gt 0)
{
Write-Error "ERROR: One or more ObjectIDs not on the same RubrikClusterID, ensure all ObjectIDs specified are on the same Rubrik cluster and try again.."
Start-Sleep 2
Break
}

# Creating demo has
IF($UseDemoIOCs)
{$IOCType = "IOC_YARA"
$IOCs = "import `"hash`"

rule StringMatch : Example Rubrik {
  meta:
    description = `"string and regular expression matching`"

  strings:
    `$wide_and_ascii_string = `"Borland`" wide ascii
    `$re = /state: (on|off)/

  condition:
   `$re and `$wide_and_ascii_string and filesize > 200KB
}

rule MatchByHash : Example Rubrik {
  meta:
    description = `"hash matching`"

  condition:
    filesize == 12345 and
        hash.md5(0, filesize) == `"e30299799c4ece3b53f4a7b8897a35b6`"
}"
}

# Validating an IOC is specified by this point otherwise exiting
IF($IOCs -eq $null)
{
Write-Error "ERROR: No IOCs specified, check your variables and try again.."
Start-Sleep 2
Break
}

################################################
# Importing Module & Running Required Functions
################################################
Import-Module RSCReporting
# Checking connectivity, exiting function with error if not
Test-RSCConnection
################################################
# Requesting Generic On Demand Snapshot
################################################
# Building GraphQL query
$RSCGraphQL = @{"operationName" = "StartThreatHuntMutation";

"variables" = @{
    "input" = @{
        "clusterUuid" = "$RubrikClusterID"
        "indicatorsOfCompromise" = @{
               "iocKind" = "$IOCType"
               "iocValue" = "$IOCs"
               }
        "objectFids" = $ObjectIDs
        "maxMatchesPerSnapshot" = $MaxMatchesPerSnapshot
        "shouldTrustFilesystemTimeInfo" = $true
        "name" = "$ThreatHuntName"
        "fileScanCriteria" = @{
                "fileSizeLimits" = @{
                "maximumSizeInBytes" = $IOCMaxSizeBytes
                }
                "pathFilter"= @{
                "includes" = "**"
                "excludes"= "$FileExclude"
                "exceptions" = "$FileException "
                }
                }
        "snapshotScanLimit" = @{
            "maxSnapshotsPerObject" = $MaxSnapshotsPerObject
                }
      }
};

"query" = "mutation StartThreatHuntMutation(`$input: StartThreatHuntInput!) {
  startThreatHunt(input: `$input) {
    huntId
    isSyncSuccessful
  }
}"
}
# Querying API
Try
{
$RSCResponse = Invoke-RestMethod -Method POST -Uri $RSCGraphqlURL -Body $($RSCGraphQL | ConvertTo-JSON -Depth 20) -Headers $RSCSessionHeader
$RSCRequest = "SUCCESS"
}
Catch
{
$RSCRequest = "FAILED"
}
# Checking for errors
IF($RSCResponse.errors.message){$RSCResponse.errors.message}
# Getting result
$ThreatHuntStarted = $RSCResponse.data.startThreatHunt.isSyncSuccessful
$ThreatHuntID = $RSCResponse.data.startThreatHunt.huntId
################################################
# Returing array
################################################
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
$Object | Add-Member -MemberType NoteProperty -Name "Mutation" -Value "StartThreatHuntMutation"
$Object | Add-Member -MemberType NoteProperty -Name "RequestStatus" -Value $RSCRequest
$Object | Add-Member -MemberType NoteProperty -Name "RubrikClusterID" -Value $RubrikClusterID
$Object | Add-Member -MemberType NoteProperty -Name "ObjectIDs" -Value $ObjectIDs
$Object | Add-Member -MemberType NoteProperty -Name "ThreatHuntStarted" -Value $ThreatHuntStarted
$Object | Add-Member -MemberType NoteProperty -Name "ThreatHuntID" -Value $ThreatHuntID
$Object | Add-Member -MemberType NoteProperty -Name "Errors" -Value $RSCResponse.errors.message
# Returning array
Return $Object
# End of function
}