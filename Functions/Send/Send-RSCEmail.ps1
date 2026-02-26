################################################
# Function - Send-RSCEmail - Sending emails from the RSC Reporting module
################################################
function Send-RSCEmail {

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
    param
    (
        $EmailTo, $EmailFrom, $EmailBody, $EmailSubject, $SMTPServer, $Attachments, [switch]$SSLRequired
    )

    # Checking function hasn't been passed multiple To emails in a string, formatting if so
    if ($EmailTo -match ",") {
        $EmailTo = $EmailTo.Split(",")
    }
    #####################
    # With SSL 
    #####################
    if ($SSLRequired) {
        # Checking whether attachment has been specified
        if ($Attachments -ne $null) {
            # Sending email with attachments
            try {
                Send-MailMessage -To $EmailTo -BodyAsHtml -Body $EmailBody -Subject $EmailSubject -From $EmailFrom -Attachments $Attachments -SmtpServer $SMTPServer -UseSsl -ErrorAction:SilentlyContinue
                $EmailSent = $TRUE
            }
            catch { $EmailSent = $FALSE }
        }
        else {
            # Sending email without attachments
            Send-MailMessage -To $EmailTo -BodyAsHtml -Body $EmailBody -Subject $EmailSubject -From $EmailFrom -SmtpServer $SMTPServer -UseSsl -ErrorAction:SilentlyContinue
            $EmailSent = $TRUE
        }
        Catch { $EmailSent = $FALSE }
    }
    else {
        #####################
        # No SSL
        #####################
        # Checking whether attachment has been specified
        if ($Attachments -ne $null) {
            # Sending email with attachments
            try {
                Send-MailMessage -To $EmailTo -BodyAsHtml -Body $EmailBody -Subject $EmailSubject -From $EmailFrom -Attachments $Attachments -SmtpServer $SMTPServer
                $EmailSent = $TRUE
            }
            catch { $EmailSent = $FALSE }
        }
        else {
            # Sending email without attachments
            try {
                Send-MailMessage -To $EmailTo -BodyAsHtml -Body $EmailBody -Subject $EmailSubject -From $EmailFrom -SmtpServer $SMTPServer
                $EmailSent = $TRUE
            }
            catch { $EmailSent = $FALSE }
        }
    }

    # Writing status
    $EmailStatus = "EmailSent: $EmailSent"

    # Returning status
    return $EmailStatus
    # End of function
}

