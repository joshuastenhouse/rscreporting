################################################
# Function - Send-RSCEmail - Sending emails from the RSC Reporting module
################################################
Function Send-RSCEmail {

<#
.SYNOPSIS
A Rubrik Security Cloud (RSC) Reporting Module Function that sends emails to a local SMTP server of your choosing.

.DESCRIPTION
Sends a test email to the local SMTP server specified.

.OUTPUTS
Result of test email.

.EXAMPLE
Send-RSCEmail -EmailTo "test@test.com" -EmailFrom "test@test.com" -SMTPServer "localhost" -EmailBody "Hello" -EmailSubject "Test Email"

.NOTES
Author: Joshua Stenhouse
Date: 05/11/2023
#>
################################################
# Paramater Config
################################################
	Param
    (
        $EmailTo,$EmailFrom,$EmailBody,$EmailSubject,$SMTPServer,$Attachments,[switch]$SSLRequired
    )

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
Send-MailMessage -To $EmailTo -BodyAsHtml -Body $EmailBody -Subject $EmailSubject -From $EmailFrom -Attachments $Attachments -SmtpServer $SMTPServer -UseSSL -ErrorAction:SilentlyContinue
$EmailSent = $TRUE
}
Catch{$EmailSent = $FALSE}
}
ELSE
{
# Sending email without attachments
Send-MailMessage -To $EmailTo -BodyAsHtml -Body $EmailBody -Subject $EmailSubject -From $EmailFrom -SmtpServer $SMTPServer -UseSSL -ErrorAction:SilentlyContinue
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
