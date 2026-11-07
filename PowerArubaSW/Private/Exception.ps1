#
# Copyright 2018, Alexis La Goutte <alexis dot lagoutte at gmail dot com>
#
# SPDX-License-Identifier: Apache-2.0
#

function Show-ArubaSWException() {
    [CmdletBinding()]
    Param(
        [parameter(Mandatory = $true)]
        $Exception
    )

    #Check if certificate is valid
    if ($Exception.Exception.InnerException) {
        $exceptiontype = $Exception.Exception.InnerException.GetType()
        if ("AuthenticationException" -eq $exceptiontype.name) {
            Write-Warning "Invalid certificat (Untrusted, wrong date, invalid name...)"
            Write-Warning "Try to use Connect-ArubaSW -SkipCertificateCheck for connection"
            throw "Unable to connect (certificate)"
        }
    }

    # Verbindungsfehler (z. B. abgelehnt, Zeitueberschreitung) haben keine Response-Eigenschaft; Strict Mode darf hier nicht werfen.
    If ($Exception.Exception.PSObject.Properties['Response'] -and $Exception.Exception.Response) {
        # Nur unter Desktop gesetzt; unter Core (Strict Mode) darf das Lesen unten nicht werfen.
        $responseBody = $null
        $responseJson = $null
        if ("Desktop" -eq $PSVersionTable.PSEdition) {
            $result = $Exception.Exception.Response.GetResponseStream()
            $reader = New-Object System.IO.StreamReader($result)
            $responseBody = $reader.ReadToEnd()
            $responseJson = $responseBody | ConvertFrom-Json
        }

        # StatusDescription gibt es nur unter Desktop; unter Core heisst es ReasonPhrase.
        $response = $Exception.Exception.Response
        $statusDescription = if ($response.PSObject.Properties['StatusDescription']) { $response.StatusDescription } else { $response.ReasonPhrase }

        Write-Warning "The Switch API sends an error message:"
        Write-Warning "Error description (code): $statusDescription ($($response.StatusCode.Value__))"
        if ($responseBody) {
            if ($responseJson.message) {
                Write-Warning "Error details: $($responseJson.message)"
            }
            else {
                Write-Warning "Error details: $($responseBody)"
            }
        }
        elseif ($Exception.ErrorDetails -and $Exception.ErrorDetails.Message) {
            Write-Warning "Error details: $($Exception.ErrorDetails.Message)"
        }
    }
}
