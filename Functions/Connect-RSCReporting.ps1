################################################
# Creating the Connect-RSCReporting function
################################################
Function Connect-RSCReporting {

<#
.SYNOPSIS
A Rubrik Security Cloud (RSC) Reporting Module Function that connects you to RSC and sets global variables used by all other functions for subsequent GraphQL API calls.
.DESCRIPTION
Connects to your RSC instance using the URL, UserID and Secret you enter when prompted. Be sure to not include client| in the username field, this is hard coded. Credentials are encrypted and stored in the script directory specified for subsequent headless runs, hence script directory is the only mandatory parameter.

This function creates the below global variables used by every other function when using Invoke-RestMethod:

$RSCSessionURL
$RSCSessionHeader
$RSCInstance (RSC URL without HTTPs://)
$RSCSessionStatus ("Connected" or "Disconnected")

.LINK
GraphQL schema reference: https://rubrikinc.github.io/rubrik-api-documentation/schema/reference

.PARAMETER ScriptDirectory
The directory required to store encrypted userID and secret for a service account on RSC, if not already connected using the official SDK.
.PARAMETER JSONFile
Specify the absolute path of the JSON file downloaded from RSC to pre-populate all the required variables of RSCURL, UserID and Secret.
.PARAMETER RSCURL
Set the URL of your RSC instance, if not entered will be prompted unless you specified a JSON file to load it from, I.E https://my.rubrik.com

.OUTPUTS
Returns an array of the connection information and global variables used for all subsequent RSC Reporting functions.

.EXAMPLE
Connect-RSCReporting
This example will automatically connect using the credentials stored by the official SDK if it's already connected.
.EXAMPLE
Connect-RSCReporting -ScriptDirectory "C:\Scripts"
This example prompts for the RSC URL, user ID and secret, then connects to RSC and securely stores them for subsequent use in the script directory specified. Use this thereafter for new connections as it will rememeber all your settings from the script directory.
.EXAMPLE
Connect-RSCReporting -ScriptDirectory "C:\Scripts" -RSCURL "https://my.rubrik.com"
This example prompts for the user ID and secret only, then connects to RSC and securely stores them for subsequent use in the script directory specified.
.EXAMPLE
Connect-RSCReporting -ScriptDirectory "C:\Scripts" -JSONFile "C:\Downloads\RSCServiceAccount.json"
This example will import the URL, client ID and secret from the JSON file you downloaded from RSC. DELETE THE JSON WHEN FINISHED! It connects to RSC and securely stores them for subsequent use in the script directory specified, the JSON isn't needed thereafter.  
.EXAMPLE
Connect-RSCReporting -ScriptDirectory "C:\Scripts" -EncryptionKey $EncryptionKey
If using the module on linux you have the option to specify your own encryption key for storing and re-using credentials. To generate your own key use: '`$EncryptionKey = New-Object Byte[] 32
[Security.Cryptography.RNGCryptoServiceProvider]::Create().GetBytes(`$EncryptionKey)' and be sure to specify the same key on subsequent runs otherwise it won't be able to decrypt the credentials.
.EXAMPLE
Connect-RSCReporting -ScriptDirectory "C:\Scripts" -Quiet 
Same as the first example, but returns the minimal amount of data required to ascertain connectivity status.

.NOTES
Author: Joshua Stenhouse
Date: 05/11/2023
Updated: 09/11/2025
#>

################################################
# Paramater Config
################################################
[CmdletBinding(DefaultParameterSetName = "List")]
Param(
    [String]$ScriptDirectory,$Credentials,$JSONFile,$RSCURL,$EncryptionKey,[switch]$Quiet
  )

##################################
# If already connected using official SDK using it's access token
##################################
# Ensuring null RSC credentials for import later
$RSCCredentials = $null
# Detecting global variable used by official SDK
IF($Global:RscConnectionClient -ne $null)
{
# Setting RscServiceAccountFile directory
IF(($IsLinux -eq $FALSE) -or ($IsLinux -eq $null))
{
$UserDir = Split-Path $PROFILE
$RscServiceAccountFile = $UserDir + "\rubrik-powershell-sdk\rsc_service_account_default.xml"
}ELSE{$RscServiceAccountFile = $PROFILE + "/rubrik-powershell-sdk/rsc_service_account_default.xml"}
# Importing credentials
$RSCCredentialsImport = IMPORT-CLIXML $RscServiceAccountFile
# Setting the username and password from the credential file (run at the start of each script)
$RSCClientID = $RSCCredentialsImport.client_id
$RSCSecret = $RSCCredentialsImport.client_secret
# Creating credentials objects
[pscredential]$RSCCredentialClientID = New-Object System.Management.Automation.PSCredential ("ClientID", $RSCClientID)
[pscredential]$RSCCredentialSecret = New-Object System.Management.Automation.PSCredential ("Secret", $RSCSecret)
# Setting the username and password from the credential file (run at the start of each script)
$RSCClientID = $RSCCredentialClientID.GetNetworkCredential().Password
$RSCSecret = $RSCCredentialSecret.GetNetworkCredential().Password
# Removing client string
$RSCClientID = $RSCClientID.Replace("client|","")
# Getting RSC URL from file too
$RSCURL = $RSCCredentialsImport.access_token_uri
# Creating combined credentials object
[pscredential]$Credentials = New-Object System.Management.Automation.PSCredential ($RSCClientID, $RSCCredentialSecret.Password)
}
ELSE
{
##################################
# Handling if no RSC URL is specificed
##################################
# Setting URL file
$RSCURLFile = $ScriptDirectory + "RSCURL.bin"
# Testing if file exists
$RSCURLFileTest =  Test-Path $RSCURLFile
# If exists pulling it
IF (($RSCURLFileTest -eq $TRUE) -and ($RSCURL -eq $null))
{
$RSCURL = Get-Content $RSCURLFile
}
ELSE
{
# If the user didn't specify the required params by variable or string, prompting for the string to be entered manually
IF($RSCURL -eq $null){$RSCURL = Read-Host "Enter RSC URL, don't use a variable, if you want to use a variable pass it on the function"}
# Exporting URL file
$RSCURL | Out-File $RSCURLFile -Force
}
}
##################################
# Getting last character of script path, if not / or \ adding it for the credentials path
##################################
IF($ScriptDirectory -eq $null){$ScriptDirectory = Read-Host "Enter a script directory, don't use a variable, if you want to use a variable pass it on the function"}
# Fixing Script Directory Based on OS
IF(($IsLinux -eq $FALSE) -or ($IsLinux -eq $null))
{
# Fixing directory if required
IF($LastScriptDirectoryChar -ne "\"){$ScriptDirectory += "\"}
}
IF ($IsLinux -eq $TRUE)
{
# Fixing directory if required
IF($LastScriptDirectoryChar -ne "/"){$ScriptDirectory += "/"}
}
$LastScriptDirectoryChar = $ScriptDirectory.Substring($ScriptDirectory.Length - 1)
##################################
# Importing JSON file if specified
##################################
IF($JSONFile -ne $null)
{
# Testing if JSON file exists
$JSONFileTest = Test-Path $JSONFile
# If exists, importing
IF($JSONFileTest -eq $TRUE)
{
$JSONFileImport = Get-Content $JSONFile | ConvertFrom-Json
$RSCURL = $JSONFileImport.access_token_uri
$RSCClientID = $JSONFileImport.client_id
$RSCClientSecret = $JSONFileImport.client_secret
# Removing client string
$RSCClientID = $RSCClientID.Replace("client|","")
# Converting secret to secure string
[securestring]$RSCClientSecretSecureString = ConvertTo-SecureString $RSCClientSecret -AsPlainText -Force
# Creating credentials object, if objects exist
IF(($RSCClientID -ne $null) -and ($RSCClientSecret -ne $null))
{
[pscredential]$RSCCredentials = New-Object System.Management.Automation.PSCredential ($RSCClientID, $RSCClientSecretSecureString)
}
}
}
##################################
# Fixing Common URL Mistakes & Getting URL file name for encrypted token export
##################################
# Correcting common URL mistakes
IF($RSCURL -match "/api/graphql"){$RSCURL = $RSCURL.Replace("/api/graphql","")}
IF($RSCURL -match "/api/client_token"){$RSCURL = $RSCURL.Replace("/api/client_token","")}
$LastRSCURLChar = $RSCURL.Substring($RSCURL.Length - 1)
IF($LastRSCURLChar -eq "/")
{
# Setting URLS
$RSCGraphqlURL = $RSCURL + "api/graphql"
$RSCSessionURL = $RSCURL + "api/client_token"
}
ELSE
{
# Setting URLS
$RSCGraphqlURL = $RSCURL + "/api/graphql"
$RSCSessionURL = $RSCURL + "/api/client_token"
}
# Getting file & friendly instance names
$RSCInstance = $RSCURL.Replace("https://","").Replace("/","")
##################################
# Adding Assembley for System Account to be able to decrypt using machine key & SSL/TLS versions
##################################
Add-Type -AssemblyName System.Security
$PSVersion = $PSVersionTable.values | Sort-Object Major -Desc | Where-Object {$_.Major -ne 10} | Select-Object -ExpandProperty Major -First 1
IF($PSVersion -lt 6)
{
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]'Ssl3,Tls12'
}
###############################################
# Accepting Credentials Object Workflow - Added 08/05/2025
###############################################
IF($Credentials)
{
# Setting credentials
$RSCClientID = $Credentials.UserName
$RSCSecret = $Credentials.GetNetworkCredential().Password
# Removing string from client ID if present as hard coded in API call further down
IF($RSCClientID -ne $null){$RSCClientID = $RSCClientID.Replace("client|","")}
}
ELSE
{
# Credentials have not been passed to the function, running workflows to encrypt and store credentials
#
###############################################
# Windows Host Workflow ($IsLinux is a global variable in PowerShell 6.0 onwards to indicate if OS is Linux, if running PS 5.1 on Windows it will be null)
###############################################
IF(($IsLinux -eq $FALSE) -or ($IsLinux -eq $null))
{
# Setting credential file
$RSCCredentialsFile = $ScriptDirectory + $env:COMPUTERNAME + "-" + $env:USERNAME + "-" + $RSCInstance + "-RSC.xml"
# Testing if file exists
$RSCCredentialsFileTest =  Test-Path $RSCCredentialsFile
# IF doesn't exist, prompting and saving credentials
IF ($RSCCredentialsFileTest -eq $False)
{
# Only prompting if credentials object doesn't already exist (could've been created by importing the JSON)
IF ($JSONFile -eq $null)
{
$RSCCredentials = Get-Credential -Message "Enter RSC client ID in user (without client|) and client secret in password" -ErrorAction Stop
}
# Exporting credentials
$RSCCredentials | EXPORT-CLIXML $RSCCredentialsFile -Force
}
# Importing credentials
$RSCCredentials = IMPORT-CLIXML $RSCCredentialsFile
# Setting the username and password from the credential file (run at the start of each script)
$RSCClientID = $RSCCredentials.UserName
$RSCSecret = $RSCCredentials.GetNetworkCredential().Password
# End of windows workflow below
}
# End of windows workflow above
###############################################
# Non-Windows Host Workflow (I.E Linux)
###############################################
IF ($IsLinux -eq $TRUE)
{
# Setting hostname
$Hostname = hostname
# Setting credential file
$RSCCredentialsFile = [string]$ScriptDirectory + $Hostname + "-" + $RSCInstance + "-RSC.bin"
# Testing if file exists
$RSCCredentialsFileTest =  Test-Path $RSCCredentialsFile
# Creating encryption key (as you can't use CLIXML in Linux etc) - Customize by passing a key instead, or don't use linux!
IF($EncryptionKey -eq $null)
{
$EncryptionKey = (9,4,7,2,6,1,11,2,8,19,9,6,1,17,11,11,12,23,22,20,9,3,8,24)
}
# IF doesn't exist, prompting and saving credentials
IF ($RSCCredentialsFileTest -eq $False)
{
# Only prompting if credentials object doesn't already exist (could've been created by importing the JSON)
IF ($RSCCredentials -eq $null)
{
$RSCCredentials = Get-Credential -Message "Enter RSC client ID in user (without client|) and client secret in password"
}
$RSCCredentials.Username | Out-File $RSCCredentialsFile -Force
$RSCCredentials.Password | ConvertFrom-SecureString -Key $EncryptionKey | Out-File $RSCCredentialsFile -Append
}
# Importing credentials
$RSCCredentialsImport = Get-Content $RSCCredentialsFile
$RSCClientID = $RSCCredentialsImport[0]
$RSCSecretStr = $RSCCredentialsImport[1] | ConvertTo-SecureString -Key $EncryptionKey 
$RSCSecret = [System.Net.NetworkCredential]::new("",$RSCSecretStr).password
# End of Linux workflow below
}
# End of Linux workflow above
#
# End of bypass if credentials passed to function below
}
# End of bypass if credentials passed to function above
###########################
# Building RSC URLs & Headers
###########################
# Creating Auth Header
$RSCAuthHeader = @{
        'Content-Type' = 'application/json';
        'Accept' = 'application/json';
    }
# Creating Auth Body
$RSCAuthBody = 
"{
  ""client_secret"": ""$RSCSecret"",
  ""client_id"": ""client|$RSCClientID""
}"
##########################
# Connecting to RSC Instance
##########################
Try 
{
$RSCSessionResponse = Invoke-RestMethod -Uri $RSCSessionURL -Headers $RSCAuthHeader -Body $RSCAuthBody -Method POST
$RSCSessionStatus = "Connected"
$RSCErrorMessage = "Nice work!"
}
Catch 
{
$RSCSessionStatus = "Disconnected"
$RSCErrorMessage = $_.ErrorDetails.Message
}
# If failed, waiting 2 seconds and trying again for redundancy, sometimes see a login fail for no reason, trying again immediatley fixes this.
IF($RSCSessionStatus -ne "Connected")
{
Start-Sleep 2
Try 
{
$RSCSessionResponse = Invoke-RestMethod -Uri $RSCSessionURL -Headers $RSCAuthHeader -Body $RSCAuthBody -Method POST
$RSCSessionStatus = "Connected"
$RSCErrorMessage = "Nice work!"
}
Catch 
{
$RSCSessionStatus = "Disconnected"
$RSCErrorMessage = $_.ErrorDetails.Message
}	
}
# Extracting the token from the JSON response
$RSCSessionToken = $RSCSessionResponse.access_token
# Creating session header
$RSCSessionHeader = @{
        'Content-Type' = 'application/json';
        'Accept' = 'application/json';
        'Authorization' = $('Bearer '+ $RSCSessionToken);
    }
##########################
# Deleting credentials file if required
##########################
IF($RSCCredentialsFile -ne $null){$RSCCredentialsFileTest =  Test-Path $RSCCredentialsFile}
# If it failed to connect, and the credentials file was just created
IF(($RSCCredentialsFileTest -eq $False) -and ($RSCSessionStatus -ne "Connected"))
{
Remove-Item -Path $RSCCredentialsFile -Force -Confirm:$false
}
# If it failed to connect, but the credentials file already exists, deleting if ping is succesful (as it must be credential related)
IF($RSCSessionStatus -ne "Connected")
{
$RSCPingTest = Test-Connection $RSCInstance -Count 2 -Quiet 
# If ping fails, deleting the URL as it could be wrong
IF ($RSCPingTest -eq $False)
{
Remove-Item -Path $RSCURLFile -Force -Confirm:$false
$RSCErrorMessage = "Ping test failed, check the RSC URL specified (I.E https://my.rubrik.com) and your connectivity then try again.."
}
}
ELSE
{
$RSCPingTest = "N/A"
}
##########################
# Friendly error message overrirdes
##########################
# Overriding error message for specific error condition when not in IP whitelist
IF($RSCErrorMessage -match "cannot process audit object")
{
$RSCErrorMessage = "IP address of host not in RSC IP Allow list, add the IP address from an allowed IP and try again.."
}
# Overridng error message for simpler explanation of invalid credentials
IF($RSCErrorMessage -match "PERMISSION_DENIED:")
{
$RSCErrorMessage = "Invalid client_id (username) and client_secret (password) specified. Ensure correct service account credentials, no client| in username and try again.."
}
##########################
# Setting Global Variables
##########################
$Global:RSCSessionStatus = $RSCSessionStatus
$Global:RSCSessionHeader = $RSCSessionHeader
$Global:RSCGraphqlURL = $RSCGraphqlURL
$Global:RSCURL = $RSCURL
$Global:RSCInstance = $RSCInstance
$Global:RSCScriptDirectory = $ScriptDirectory
# Global variable to combine RSCReporting with Official RSC SDK
$Global:RSCReportingModule = $TRUE
# Getting PowerShell version
$PSVersion = $PSVersionTable.values | Sort-Object Major -Desc | Where-Object {$_.Major -ne 10} | Select-Object -ExpandProperty Major -First 1
$Global:PSVersion = $PSVersion
# If greater than 7, use Parallel
IF($PSVersion -ge 7){$UseParallel = $TRUE}ELSE{$UseParallel = $FALSE}
$Global:UseParallel = $UseParallel
# If running on Josh PC, hard coding some defaults to make my life easier
$hostname = hostname 
IF($hostname -eq "Studio2Plus")
{
$Global:EmailTo = "joshua@rubrik.local"
$Global:EmailFrom = "reporting@rubrik.local"
$Global:SMTPServer = "localhost"
}
# Overriding message if using RSC SDK connection file
IF($Global:RscConnectionClient -ne $null)
{
$RSCErrorMessage = "Connected using XML file from Rubrik Security Cloud SDK Set-RSCServiceAccountFile function"
}
##########################
# Returning All Data Unless Quiet Switch
##########################
IF($Quiet)
{
$Return = New-Object PSObject
$Return | Add-Member -MemberType NoteProperty -Name "RSCURL" -Value $RSCURL
$Return | Add-Member -MemberType NoteProperty -Name "Status" -Value $RSCSessionStatus
}
ELSE
{
$Return = New-Object PSObject
$Return | Add-Member -MemberType NoteProperty -Name "RSCInstance" -Value $RSCInstance
$Return | Add-Member -MemberType NoteProperty -Name "RSCURL" -Value $RSCURL
$Return | Add-Member -MemberType NoteProperty -Name "Status" -Value $RSCSessionStatus
$Return | Add-Member -MemberType NoteProperty -Name "Message" -Value $RSCErrorMessage
$Return | Add-Member -MemberType NoteProperty -Name "PingSuccess" -Value $RSCPingTest
$Return | Add-Member -MemberType NoteProperty -Name "ScriptDirectory" -Value $ScriptDirectory
$Return | Add-Member -MemberType NoteProperty -Name "CredentialsFile" -Value $RSCCredentialsFile
$Return | Add-Member -MemberType NoteProperty -Name "URLFile" -Value $RSCURLFile
$Return | Add-Member -MemberType NoteProperty -Name "PowerShellVersion" -Value $PSVersion
$Return | Add-Member -MemberType NoteProperty -Name "UseParallel" -Value $UseParallel
$Return | Add-Member -MemberType NoteProperty -Name "GlobalVariableForRSCInstance" -Value "RSCInstance"
$Return | Add-Member -MemberType NoteProperty -Name "GlobalVariableForSessionStatus" -Value "RSCSessionStatus"
$Return | Add-Member -MemberType NoteProperty -Name "GlobalVariableForSessionHeader" -Value "RSCSessionHeader"
$Return | Add-Member -MemberType NoteProperty -Name "GlobalVariableForAPICalls" -Value "RSCGraphqlURL"
$Return | Add-Member -MemberType NoteProperty -Name "GlobalVariableForScriptDirectory" -Value "RSCScriptDirectory"
}
# Returning data
Return $Return
# End of function below
}
# End of function above

################################################
# End of script
################################################