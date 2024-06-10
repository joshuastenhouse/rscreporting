########################################################################################################################
# Start of the script - Displaying a welcome message when importing the module
########################################################################################################################
# Only displaying if not already shown in the current session
IF($RSCDoNotShowWelcomeMessage -ne $TRUE)
{
# Global variable to combine RSCReporting with Official RSC SDK
$Global:RSCReportingModule = $TRUE
# Friendly UI banner on module load
Write-Host "------------------------------------------------------------------------------------------
Welcome to the Rubrik Security Cloud (RSC) PowerShell Module For Reporting
------------------------------------------------------------------------------------------
To get started use Connect-RSCReporting and follow the below instructions:
------------------------------------------------------------------------------------------
    1. This function requires a ScriptDirectory parameter as a valid directory is required for storing encrypted credentials. 
    2. You can utilize the JSON file you downloaded from RSC with the JSONFile parameter to automatically populate all the required fields.
    3. Alternatively, specify the RSCURL parameter and wait for the prompt for ClientID (User) and ClientSecret (Password).
    4. When entering the clientID in user be sure to not include 'client|', only the characters after, the pipe isn't supported by PowerShell.
    5. Credentials will be encrypted and stored securely in the ScriptDirectory (encrypted by user account in Windows and encryption key in Linux). 
    6. If it fails to connect, and the RSC domain is pingable, it will delete the credentails file and prompt again as this is likely an auth issue.
    7. If you intend to use Windows scheduled tasks, login & run as the same user running the task, otherwise it won't be able to decrypt the creds.
    8. The RSCURL is also stored in the ScriptDirectory for subsequent runs of Connect-RSCReporting, unless the RSCURL parameter is specified.
    9. WARNING! If you downloaded the JSON file of creds from RSC, delete it once you have succesfully connected. Do not store creds in plain text.
------------------------------------------------------------------------------------------
Note for Linux users: if you don't specify an encryption key parameter it uses a default key. To generate use and store your own:
'`$EncryptionKey = New-Object Byte[] 32
[Security.Cryptography.RNGCryptoServiceProvider]::Create().GetBytes(`$EncryptionKey)'
------------------------------------------------------------------------------------------
Example 1 - Using the JSON downloaded from RSC:
    1. Run: Connect-RSCReporting -ScriptDirectory 'C:\Scripts\' -JSONFile 'C:\Scripts\RSC.json'
    2. Subsequent connections, use: Connect-RSCReporting 'C:\Scripts\'
------------------------------------------------------------------------------------------
Example 2 - Sepcify the RSCURL, paste in ClientID & Secret:
    1. Run: Connect-RSCReporting -ScriptDirectory 'C:\Scripts\' -RSCURL 'https://yourcompany.my.rubrik.com' then paste ClientID in User and Secrect in password.
    2. Subsequent connections, use: Connect-RSCReporting -ScriptDirectory 'C:\Scripts\'
------------------------------------------------------------------------------------------
Example 3 - Paste in the RSCURL, ClientID & Secret, just pass the Script directory going forward
    1. Run: Connect-RSCReporting -ScriptDirectory '/home/rubrik/scripts/' then paste your RSC URL, ClientID in User and Secrect in password.
    2. Subsequent connections, use: Connect-RSCReporting '/home/rubrik/scripts/'
------------------------------------------------------------------------------------------
Once connected, type 'Get-Command -Module RSCReporting' to sell all available functions...
------------------------------------------------------------------------------------------" -ForegroundColor Cyan 
# Setting Global Variable to prevent being shown twice
$Global:RSCDoNotShowWelcomeMessage = $TRUE
}
################################################
# End of script
################################################