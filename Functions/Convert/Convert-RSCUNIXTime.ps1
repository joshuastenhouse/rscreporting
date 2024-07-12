################################################
# Function - Convert-RSCUnixTime - Converting time from UNIX to RSC format, only needed for PowerShell version 5
################################################
Function Convert-RSCUNIXTime {
	
<#
.SYNOPSIS
Converts the UNIX time format to a PowerShell time format object if needed (I.E older versions of PowerShell)

.DESCRIPTION
Used to convert the responses from the RSC API whenever it gives a timestamp and PowerShell treats it as a string. 

.PARAMETER UNIXTime
The UNIX time zone format returned by RSC GraphQL API calls.

.OUTPUTS
Returns an array of all the available information on the GraphQL endpoint in a uniform and usable format.

.EXAMPLE
Convert-RSCUNIXTime $UNIXTimeUTC
Returns the date time in an usable PowerShell object in the correct format.

.NOTES
Author: Joshua Stenhouse
Date: 05/11/2023
#>

# Paramater Config
Param ($UNIXTime)

# Main function
#$PSVersion = $PSVersionTable.values | Sort-Object Major -Desc | Where-Object {$_.Major -ne 10} | Select-Object -ExpandProperty Major -First 1

# Checking it hasn't been passed a datetime already (I.E if running a newer version of PowerShell)
$ParamType = $UNIXTime.GetType().Name

# Passing through or converting depending on outcome
IF($ParamType -eq "DateTime")
{
# Nothing to convert!
$UTCTime = $UNIXTime
}
ELSE
{
# Attempting to convert manually if not null
IF($UNIXTime -ne $null)
{
$Step1 = $UNIXTime.Replace("T"," ").Replace("Z"," ").TrimEnd();$Step2 = $Step1.Substring(0,$Step1.Length-4);$UTCTime = ([datetime]::ParseExact($Step2,"yyyy-MM-dd HH:mm:ss",$null))
}ELSE{$UTCTime = $null}
}

Return $UTCTime
}
