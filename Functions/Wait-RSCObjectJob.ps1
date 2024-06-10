################################################
# Function - Wait-RSCObjectJob - Waits for a job to finish on the object ID specified
################################################
Function Wait-RSCObjectJob {

<#
.SYNOPSIS
Function for waiting for a job to complete for the specified object ID by continously polling the EventSeriesAPI.

.DESCRIPTION
Will wait up to 5 minutes for the job to start before timing out, to change this use the MaxStartSeconds parameter.

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference
The ActivitySeriesConnection type: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference/activityseriesconnection.doc.html

.PARAMETER ObjectID
Mandatory ObjectID required
.PARAMETER MaxStartSeconds
Optional maximum time to wait for the job to start in seconds before timing out.
.PARAMETER LookBackSeconds
Optional configuration of how many seconds to look back to check the job didn't already finish, default is 60 if not specified. Useful if looking for a DB log backup, couldv'e completed by the time you check.

.OUTPUTS
Returns an array of all the available information on the GraphQL endpoint in a uniform and usable format.

.EXAMPLE
Wait-RSCObjectJob -ObjectID "4defd13e-eaf9-5be2-b026-1e6542d333e2"
This example waits for the default 5 minutes for a job to appear for the objectID before timing out, or looping until it finishes.

.EXAMPLE
Wait-RSCObjectJob -ObjectID "4defd13e-eaf9-5be2-b026-1e6542d333e2" -MaxStartSeconds 600
This example waits for the 10 minutes for a job to appear for the objectID before timing out, or looping until it finishes.

.NOTES
Author: Joshua Stenhouse
Date: 08/15/2023
#>

################################################
# Paramater Config
################################################
	Param
    (
        [Parameter(Mandatory=$true)]$ObjectID,$MaxStartSeconds,$LookBackSeconds
    )

################################################
# Importing Module & Running Required Functions
################################################
# Importing the module is it needs other modules
Import-Module RSCReporting
# Checking connectivity, exiting function with error if not connected
Test-RSCConnection
# Setting default MaxStartSeconds if not configured
IF($MaxStartSeconds -eq $null){$MaxStartSeconds = 300}
# Setting look back seconds (time to look back to check the job didn't already complete it was so fast, I.E log backup)
IF($LookBackSeconds -eq $null){$LookBackSeconds = 60}
################################################
# Running Main Function
################################################
# Starting timer for loop seconds
$StartLoopTime = Get-Date
# Getting from date in correct time format
$FromDate = [System.DateTime]::UtcNow
# Removing LookBackSeconds to compensate for jobs that might run so fast they already completed
$FromDate = $FromDate.AddSeconds(-$LookBackSeconds)
# Starting loop
Do{
# Getting running events
$ObjectRunningEvents = Get-RSCEventsRunning -ObjectID $ObjectID -Silent
$ObjectRunningEventsCount = $ObjectRunningEvents | Measure-Object | Select-Object -ExpandProperty Count
# Getting any event for the object 1 minute before starting this function
$ObjectEvents = Get-RSCEvents -ObjectID $ObjectID -FromDate $FromDate -Silent
$ObjectEventsCount = $ObjectEvents | Measure-Object | Select-Object -ExpandProperty Count
# Timing
$CurrentLoopTime = Get-Date
# Timespan
$LoopTimespan = New-TimeSpan -Start $StartLoopTime -End $CurrentLoopTime
$LoopSeconds = $LoopTimespan | Select-Object -ExpandProperty TotalSeconds
$LoopSeconds = [Math]::Round($LoopSeconds)
# If job found, removing $MaxStartSeconds by setting it to 2 days
IF(($ObjectRunningEventsCount -gt 0) -or ($ObjectEventsCount -gt 0)){$MaxStartSeconds = 172800}
# Getting job info, selecting existing first, already running always takes precidence
IF($ObjectEventsCount -gt 0){$ObjectJobInfo = $ObjectEvents | Select-Object -First 1}
IF($ObjectRunningEventsCount -gt 0){$ObjectJobInfo = $ObjectRunningEvents | Select-Object -First 1}
$ObjectJobStatus = $ObjectJobInfo.Status
$ObjectJobType = $ObjectJobInfo.Type
$ObjectJobStartUTC = $ObjectJobInfo.StartUTC
$ObjectJobEndUTC = $ObjectJobInfo.EndUTC
$ObjectJobDuration = $ObjectJobInfo.Duration
$ObjectJobID = $ObjectJobInfo.EventID
$ObjectJobMessage = $ObjectJobInfo.Message
# Calculating duration on the fly, not always consistent from the API, disabled for now
# $UTCDateTime = [System.DateTime]::UtcNow
# $ObjectJobTimeSpan = New-TimeSpan -Start $ObjectJobStartUTC -End $UTCDateTime
# $ObjectJobDuration = "{0:g}" -f $ObjectJobTimeSpan
# IF ($ObjectJobDuration -match "."){$ObjectJobDuration = $ObjectJobDuration.split('.')[0]}
# If null setting to waiting
IF($ObjectJobStatus -eq $null){$ObjectJobStatus = "WaitingForJobToStart"}
# Logging if job not running yet
IF($ObjectJobStatus -eq "WaitingForJobToStart")
{
# Write-Host "JobStatus:$ObjectJobStatus WaitSeconds:$LoopSeconds MaxWaitSeconds:$MaxStartSeconds ObjectID:$ObjectID"
Write-Host "JobStatus:" -NoNewline
Write-Host "$ObjectJobStatus " -ForegroundColor Cyan -NoNewline
Write-Host "WaitSeconds:" -NoNewline
Write-Host "$LoopSeconds " -ForegroundColor Cyan -NoNewline
Write-Host "MaxWaitSeconds:" -NoNewline
Write-Host "$MaxStartSeconds " -ForegroundColor Cyan -NoNewline
Write-Host "LookBackSeconds:" -NoNewline
Write-Host "$LookBackSeconds " -ForegroundColor Cyan
Write-Host "ObjectID:" -NoNewline
Write-Host "$ObjectID " -ForegroundColor Cyan
}
# Logging if job running
IF($ObjectJobStatus -ne "WaitingForJobToStart")
{
# Write-Host "JobStatus:$ObjectJobStatus Type:$ObjectJobType Duration:$ObjectJobDuration StartUTC:$ObjectJobStartUTC JobID:$ObjectJobID"
Write-Host "JobStatus:" -NoNewline
Write-Host "$ObjectJobStatus " -ForegroundColor Cyan -NoNewline
Write-Host "Type:" -NoNewline
Write-Host "$ObjectJobType " -ForegroundColor Cyan -NoNewline
Write-Host "Duration:" -NoNewline
Write-Host "$ObjectJobDuration " -ForegroundColor Cyan -NoNewline
Write-Host "StartUTC:" -NoNewline
Write-Host "$ObjectJobStartUTC " -ForegroundColor Cyan -NoNewline
Write-Host "JobID:" -NoNewline
Write-Host "$ObjectJobID " -ForegroundColor Cyan
}
# Sleeping between each query to avoid overload of UI/API
Start-Sleep 15
# End of loop below
}Until(($ObjectJobStatus -ne "Running") -and ($ObjectJobStatus -ne "WaitingForJobToStart") -or ($MaxStartSeconds -lt $LoopSeconds))
################################################
# Summarizing Result
################################################
# Deciding if job status timed out or not
IF($MaxStartSeconds -lt $LoopSeconds){$ObjectJobStatus = "TimedOutWaitingForJobStart"}ELSE{$MaxStartSeconds = $null}
# Returning array of useful info
$Return = New-Object PSObject
$Return | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
$Return | Add-Member -MemberType NoteProperty -Name "ObjectID" -Value $ObjectID
$Return | Add-Member -MemberType NoteProperty -Name "Status" -Value $ObjectJobStatus
$Return | Add-Member -MemberType NoteProperty -Name "StartUTC" -Value $ObjectJobStartUTC
$Return | Add-Member -MemberType NoteProperty -Name "EndUTC" -Value $ObjectJobEndUTC
$Return | Add-Member -MemberType NoteProperty -Name "Duration" -Value $ObjectJobDuration
$Return | Add-Member -MemberType NoteProperty -Name "Message" -Value $ObjectJobMessage
$Return | Add-Member -MemberType NoteProperty -Name "JobID" -Value $ObjectJobID
$Return | Add-Member -MemberType NoteProperty -Name "WaitSeconds" -Value $LoopSeconds

# Returning array
Return $Return
# End of function
}
