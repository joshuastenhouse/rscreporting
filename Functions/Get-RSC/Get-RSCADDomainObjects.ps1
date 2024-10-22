################################################
# Function - Get-RSCADDomainObjects - Getting All Active Directory Domain Objects For the AD Domain Specified
################################################
Function Get-RSCADDomainObjects {

<#
.SYNOPSIS
A Rubrik Security Cloud (RSC) Reporting Module Function returning a list of all protected Active Directory Domain Controllers.

.DESCRIPTION
Makes the required GraphQL API calls to RSC via Invoke-RestMethod to get the data as described, then creates a usable array of the returned information, removing the need for the PowerShell user to understand GraphQL in order to interact with RSC.

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.OUTPUTS
Returns an array of all the available information on the GraphQL endpoint in a uniform and usable format.

.EXAMPLE
Get-RSCADDomainObjects
This example returns an array of all the information returned by the GraphQL endpoint for this object type.

.NOTES
Author: Joshua Stenhouse
Date: 07/08/2024
#>

################################################
# Paramater Config
################################################	
	Param
    (
    [Parameter(Mandatory=$true)]
    [String]$ADDomainID
    )
################################################
# Importing Module & Running Required Functions
################################################
# Importing the module is it needs other modules
Import-Module RSCReporting
# Checking connectivity, exiting function with error if not connected
Test-RSCConnection
# Getting list of Domain controllers
$DomainControllers = Get-RSCADDomainControllers | Where-Object {$_.ADDomainID -eq $ADDomainID}
# Selecting first DC that's online
$DomainController = $DomainControllers | Where-Object {$_.Status -eq "CONNECTED"} | Select-Object -First 1
$DomainControllerID = $DomainController.DomainControllerID
$ADDomain = $DomainController.ADDomain
$ADDomainID = $DomainController.ADDomainID
# Getting latest snapshot ID
$Snapshots = Get-RSCObjectSnapshots -ObjectID $DomainControllerID
$SnapshotID = $Snapshots | Select -ExpandProperty SnapshotID -First 1
################################################
# Querying RSC GraphQL API For All Containers
################################################
# Resetting (from testing in-line)
$Query1 = $null;$Query2 = $null;$Query3 = $null;$Query4 = $null;$Query5 = $null
# Query 1
$Query1 = Get-RSCADDomainDNT -SnapshotID $SnapshotID -DNT 2043;$Query1Count = $Query1 | Measure-Object | Select-Object -ExpandProperty Count
Write-Host "Query1Containers:"$Query1Count
# Query 2
$Query2 = @()
ForEach($_ in $Query1){$Query2 += Get-RSCADDomainDNT -SnapshotID $SnapshotID -DNT $_.dnt -ListContainers}
$Query2 = $Query2 | Where-Object {$_.dnt -ne 2043};$Query2Count = $Query2 | Measure-Object | Select-Object -ExpandProperty Count
Write-Host "Query2Containers:"$Query2Count
# Query 3
$Query3 = @()
ForEach($_ in $Query2){$Query3 += Get-RSCADDomainDNT -SnapshotID $SnapshotID -DNT $_.dnt -ListContainers}
$Query3 = $Query3 | Where-Object {$_.dnt -ne 2043};$Query3Count = $Query3 | Measure-Object | Select-Object -ExpandProperty Count
Write-Host "Query3Containers:"$Query3Count
# Query 4
$Query4 = @()
ForEach($_ in $Query3){$Query4 += Get-RSCADDomainDNT -SnapshotID $SnapshotID -DNT $_.dnt -ListContainers}
$Query4 = $Query4 | Where-Object {$_.dnt -ne 2043};$Query4Count = $Query4 | Measure-Object | Select-Object -ExpandProperty Count
Write-Host "Query4Containers:"$Query4Count
# Query 5
$Query5 = @()
ForEach($_ in $Query4){$Query5 += Get-RSCADDomainDNT -SnapshotID $SnapshotID -DNT $_.dnt -ListContainers}
$Query5 = $Query5 | Where-Object {$_.dnt -ne 2043};$Query5Count = $Query5 | Measure-Object | Select-Object -ExpandProperty Count
Write-Host "Query5Containers:"$Query5Count
# Putting together
$AllContainersList = $Query1 + $Query2 + $Query3 + $Query4 + $Query5
$AllContainersList = $AllContainersList | Where-Object {$_.dnt -ne $null}
$AllContainersListCount = $AllContainersList | Measure-Object | Select-Object -ExpandProperty Count
Write-Host "TotalContainers:"$AllContainersListCount
################################################
# Querying RSC GraphQL API For Each Containers Objects
################################################
$AllObjectsList = @()
$ContainerCounter = 0
ForEach($Container in $AllContainersList)
{
$ContainerCounter++
Write-Host "QueryingContainer:$ContainerCounter/$AllContainersListCount"
$AllObjectsList += Get-RSCADDomainDNT -SnapshotID $SnapshotID -DNT $Container.dnt
}
# Total objects
$AllObjectsList = $AllObjectsList | Where-Object {$_.dnt -ne $null}
$AllObjectsListCount = $AllObjectsList | Measure-Object | Select-Object -ExpandProperty Count
$ObjectCounter = 0
# Creating array for all objects
$AllADObjects = [System.Collections.ArrayList]@()
# Processing objects
ForEach ($ADObject in $AllObjectsList)
{
$ObjectCounter++
Write-Host "ProcessingObject:$ObjectCounter/$AllObjectsListCount"
# Setting variables
$ADObjectDNT = $ADObject.dnt
$ADObjectName = $ADObject.name
$ADObjectDescription = $ADObject.description
$ADObjectType = $ADObject.activeDirectoryObjectType
# Adding To Array
$Object = New-Object PSObject
$Object | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
$Object | Add-Member -MemberType NoteProperty -Name "ObjectName" -Value $ADObjectName
$Object | Add-Member -MemberType NoteProperty -Name "ObjectType" -Value $ADObjectType
$Object | Add-Member -MemberType NoteProperty -Name "Description" -Value $ADObjectDescription
$Object | Add-Member -MemberType NoteProperty -Name "ADDomain" -Value $ADDomain
$Object | Add-Member -MemberType NoteProperty -Name "ADDomainID" -Value $ADDomainID
$Object | Add-Member -MemberType NoteProperty -Name "DNTID" -Value $ADObjectDNT
$AllADObjects.Add($Object) | Out-Null
}
# Removing nulls
$AllADObjects = $AllADObjects | Where-Object {$_.DNTID -ne $null}

# Returning array
Return $AllADObjects
# End of function
}