################################################
# Function - Test-RSCEmail - Sending test emails from the RSC Reporting module
################################################
Function Test-RSCEmail {

<#
.SYNOPSIS
Tests the ability for you to be able to send emails via a local SMTP server given the parameters you specify.

.DESCRIPTION
A wrapper that sends a test email using the PowerShell Send-MailMessage default function.

.PARAMETER EmailTo
Specify the email to send to I.E recipient@lab.local
.PARAMETER EmailFrom
Specify the email to send from I.E reporting@lab.local
.PARAMETER SMTPServer
Specify your local SMTP server name or IP address which will accept you relaying/sending emails through it from the host/user running your script.
.PARAMETER SSLRequired
Switch to enable or disable SSL on the SMTP connection, only enable if required.

.OUTPUTS
Returns the result of the attempt to send an email.

.EXAMPLE
Test-RSCEmail -SMTPServer "localhost" -EmailTo "recipient@lab.local" -EmailFrom "reporting@lab.local"
This sends the email to a locally installed SMTP server relay on the host running the script (I.E hMailServer with basic Windows Mail Client)

.NOTES
Author: Joshua Stenhouse
Date: 05/11/2023
#>
################################################
# Paramater Config
################################################
	Param
    (
        $EmailTo,$EmailFrom,$SMTPServer,[switch]$SSLRequired
    )

# Hard coding test
$EmailBody = "This is a test email from the Rubrik RSC Reporting reporting PowerShell module.."
$EmailSubject = "PowerShell Test Email"
$Attachments = $null

# Checking function hasn't been passed multiple To emails in a string, formatting if so
IF($EmailTo -match ",")
{
$EmailTo = $EmailTo.Split(",")
}
#####################
# With SSL 
#####################
IF ($SSLRequired)
{
# Checking whether attachment has been specified
IF ($Attachments -ne $null)
{
# Sending email with attachments
Try
{
Send-MailMessage -To $EmailTo -BodyAsHtml -Body $EmailBody -Subject $EmailSubject -From $EmailFrom -Attachments $Attachments -SmtpServer $SMTPServer -UseSSL
$EmailSent = $TRUE
}
Catch{$EmailSent = $FALSE}
}
ELSE
{
# Sending email without attachments
Send-MailMessage -To $EmailTo -BodyAsHtml -Body $EmailBody -Subject $EmailSubject -From $EmailFrom -SmtpServer $SMTPServer -UseSSL
$EmailSent = $TRUE
}
Catch{$EmailSent = $FALSE}
}
ELSE
{
#####################
# No SSL
#####################
# Checking whether attachment has been specified
IF ($Attachments -ne $null)
{
# Sending email with attachments
Try
{
Send-MailMessage -To $EmailTo -BodyAsHtml -Body $EmailBody -Subject $EmailSubject -From $EmailFrom -Attachments $Attachments -SmtpServer $SMTPServer
$EmailSent = $TRUE
}
Catch{$EmailSent = $FALSE}
}
ELSE
{
# Sending email without attachments
Try
{
Send-MailMessage -To $EmailTo -BodyAsHtml -Body $EmailBody -Subject $EmailSubject -From $EmailFrom -SmtpServer $SMTPServer
$EmailSent = $TRUE
}
Catch{$EmailSent = $FALSE}
}
}

# Writing status
$EmailStatus = "EmailSent: $EmailSent"

# Returning status
Return $EmailStatus
# End of function
}
