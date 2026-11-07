
#
# Copyright 2018, Alexis La Goutte <alexis dot lagoutte at gmail dot com>
#
# SPDX-License-Identifier: Apache-2.0
#

function Connect-ArubaSW {

    <#
      .SYNOPSIS
      Connect to an ArubaOS Switches (Provision)

      .DESCRIPTION
      Connect to an ArubaOS Switches
      Support connection to HTTPS (default) or HTTP

      .EXAMPLE
      Connect-ArubaSW -Server 192.0.2.1

      Connect to an ArubaOS Switch using HTTPS with IP 192.0.2.1 using (Get-)credential

      .EXAMPLE
      Connect-ArubaSW -Server 192.0.2.1 -SkipCertificateCheck

      Connect to an ArubaOS Switch using HTTPS (without check certificate validation) with IP 192.0.2.1 using (Get-)credential

      .EXAMPLE
      Connect-ArubaSW -Server 192.0.2.1 -httpOnly -Force

      Connect to an ArubaOS Switch using HTTP (UNSECURE -- credentials are sent in cleartext)
      with IP 192.0.2.1. -Force is required since I7 (2026-05-27) so the cleartext-credential
      choice has to be confirmed explicitly. Without -Force the call throws.

      .EXAMPLE
      Connect-ArubaSW -Server 192.0.2.1 -port 4443

      Connect to an ArubaOS Switch using HTTPS (with port 4443) with IP 192.0.2.1 using (Get-)credential

      .EXAMPLE
      $cred = get-credential
      Connect-ArubaSW -Server 192.0.2.1 -credential $cred

      Connect to an ArubaOS Switch with IP 192.0.2.1 and passing (Get-)credential

      .EXAMPLE
      $mysecpassword = ConvertTo-SecureString aruba -AsPlainText -Force
      Connect-ArubaSW -Server 192.0.2.1 -Username manager -Password $mysecpassword

      Connect to an ArubaOS Switch with IP 192.0.2.1 using Username and Password

      .EXAMPLE
      Save-ArubaSWCredential -Server 192.0.2.1
      Connect-ArubaSW -Server 192.0.2.1

      Store the credentials once in the Windows Credential Manager (Windows only); Connect-ArubaSW
      then finds them by itself (target PowerArubaSW_192.0.2.1) and does not prompt

      .EXAMPLE
      Connect-ArubaSW -Server 192.0.2.1 -CredentialTarget SwitchLab

      Connect with credentials stored under the target name SwitchLab (Save-ArubaSWCredential -CredentialTarget).
      Order: -Password, -Credentials, -CredentialTarget, -SecretName, default target PowerArubaSW_<server>, Get-Credential prompt

      .EXAMPLE
      Connect-ArubaSW -Server 192.0.2.1 -SecretName SwitchLab -Vault LabVault

      Connect with credentials from a SecretManagement vault (module Microsoft.PowerShell.SecretManagement, not a dependency of this module;
      the secret is a PSCredential, or a SecureString together with -Username)

      .EXAMPLE
      $sw1 = Connect-ArubaSW -Server 192.0.2.1

      Connect to an ArubaOS Switch with IP 192.0.2.1 and store connection info to $sw1 variable

      .EXAMPLE
      $sw2 = Connect-ArubaSW -Server 192.0.2.1 -DefaultConnection:$false

      Connect to an ArubaOS Switch with IP 192.0.2.1 and store connection info to $sw2 variable
      and don't store connection on global ($DefaultArubaSWConnection) variable

     .EXAMPLE
      Connect-ArubaSW -Server 192.0.2.1 -api_version 2

      Connect to an ArubaOS Switch with IP 192.0.2.1 using v2 API
  #>

    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingPlainTextForPassword", "CredentialTarget", Justification = "CredentialTarget is the NAME of a Credential Manager entry, not a secret.")]
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true, position = 1)]
        [String]$Server,
        [Parameter(Mandatory = $false)]
        [String]$Username,
        [Parameter(Mandatory = $false)]
        [SecureString]$Password,
        [Parameter(Mandatory = $false)]
        [PSCredential]$Credentials,
        [Parameter(Mandatory = $false)]
        [String]$CredentialTarget,
        [Parameter(Mandatory = $false)]
        [String]$SecretName,
        [Parameter(Mandatory = $false)]
        [String]$Vault,
        [Parameter(Mandatory = $false)]
        [switch]$httpOnly = $false,
        [Parameter(Mandatory = $false)]
        [switch]$SkipCertificateCheck = $false,
        [Parameter(Mandatory = $false)]
        [switch]$Force = $false,
        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 65535)]
        [int]$port,
        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 10)]
        [int]$api_version,
        [Parameter(Mandatory = $false)]
        [boolean]$DefaultConnection = $true
    )

    Begin {
    }

    Process {

        # I7: -httpOnly sendet Username + Password im Klartext-JSON-Body ueber HTTP.
        # Diese Wahl muss seit Inkrement I7 mit -Force explizit bestaetigt werden,
        # damit niemand sie versehentlich (z.B. aus Copy-Paste eines alten Snippets) trifft.
        # Check passiert vor dem interaktiven Credential-Prompt, damit der User nicht
        # erst sein Passwort eintippt und DANN abgebrochen wird.
        if ($httpOnly -and -not $Force) {
            Write-Warning "Connect-ArubaSW -httpOnly sendet Username UND Password im Klartext (JSON-POST-Body ueber HTTP)."
            Write-Warning "Wer das Netzsegment mitliest, erhaelt die Switch-Admin-Credentials."
            Write-Warning "Bestaetige diese Wahl explizit mit -Force, oder nutze HTTPS (Default; ggf. mit -SkipCertificateCheck bei Self-Signed-Zertifikat)."
            throw "Refused -httpOnly without -Force: cleartext credential transmission over HTTP requires explicit -Force."
        }

        $version = @{min = ""; cur = ""; max = "" }
        $connection = @{server = ""; session = ""; cookie = ""; httpOnly = $false; port = ""; invokeParams = ""; switch_type = "" ; api_version = $version ; product_number = "" }

        #Credentials: -Password (+ -Username), -Credentials, -CredentialTarget / default target in the
        #Windows Credential Manager (I26), -SecretName from a SecretManagement vault (I34), last resort the interactive Get-Credential prompt
        $Credentials = Resolve-ArubaSWCredential -Server $Server -Username $Username -Password $Password -Credentials $Credentials -CredentialTarget $CredentialTarget -SecretName $SecretName -Vault $Vault

        $postParams = @{userName = $Credentials.username; password = $Credentials.GetNetworkCredential().Password }
        $invokeParams = Get-ArubaSWLoginInvokeParameter -SkipCertificateCheck:$SkipCertificateCheck -Edition $PSVersionTable.PsEdition

        #for PowerShell (<=) 5 (Desktop), Enable TLS 1.1, 1.2 and Disable SSL chain trust; HTTP needs no TLS
        if (-not $httpOnly) {
            Initialize-ArubaSWDesktopSSL -Edition $PSVersionTable.PsEdition -SkipCertificateCheck:$SkipCertificateCheck
        }

        $loginParams = @{ Server = $Server; Port = $port; HttpOnly = $httpOnly }
        if ($PsBoundParameters.ContainsKey('api_version')) {
            $loginParams.ApiVersion = $api_version
        }
        $target = Get-ArubaSWLoginTarget @loginParams
        $uri = $target.Uri
        $port = $target.Port
        if ($httpOnly) {
            $connection.httpOnly = $true
        }

        try {
            $response = Invoke-WebRequest -uri $uri -Method POST -Body ($postParams | ConvertTo-Json ) -SessionVariable arubasw @invokeParams
        }
        catch {
            Show-ArubaSWException -Exception $_
            throw "Unable to connect"
        }
        $cookie = ($response.content | ConvertFrom-Json).cookie
        $smallcookie = $cookie.split("=")[1]
        $arubasw.Cookies.Add((Set-Cookie -name "sessionId" -value $smallcookie -domain $server));

        $connection.server = $server
        $connection.cookie = $cookie
        $connection.session = $arubasw
        $connection.port = $port
        $connection.invokeParams = $invokeParams

        if ( $DefaultConnection ) {
            Set-Variable -name DefaultArubaSWConnection -value $connection -scope Global
        }

        $restversion = Get-ArubaSWRestversion -connection $connection
        $range = Get-ArubaSWApiVersionRange -RestVersion $restversion

        $connection.api_version.min = $range.Min
        $connection.api_version.max = $range.Max

        if ($PsBoundParameters.ContainsKey('api_version')) {
            $connection.api_version.cur = $api_version
        }
        else {
            #use by default the high version release supported
            $connection.api_version.cur = $connection.api_version.max
        }

        $switchstatus = Get-ArubaSWSystemStatusSwitch -connection $connection
        $connection.switch_type = $switchstatus.switch_type

        $product = Get-ArubaSWProductInfo -SwitchStatus $switchstatus
        $connection.product_number = $product.ProductNumber

        $switchsystem = Get-ArubaSWSystem -connection $connection

        Write-Verbose "Welcome on $($switchsystem.name) -$($product.ProductName)"

        #Return connection info
        $connection
    }

    End {
    }
}

function Set-ArubaSWConnection {

    <#
        .SYNOPSIS
        Configure Aruba SW connection Setting

        .DESCRIPTION
        Configure Aruba SW connection Setting (api_version...)

        .EXAMPLE
        Set-ArubaSWConnection -api_version 4

        Configure default connection api_version to 4

    #>

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Low')]
    Param(
        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 10)]
        [int]$api_version,
        [Parameter(Mandatory = $false)]
        [psobject]$connection = (Get-ArubaSWDefaultConnection)
    )

    Begin {
    }

    Process {

        if ($PSCmdlet.ShouldProcess($connection.server, 'Set default api_version on connection')) {
            $connection.api_version.cur = $api_version
        }

    }

    End {
    }
}

function Disconnect-ArubaSW {

    <#
        .SYNOPSIS
        Disconnect to an ArubaOS Switches (Provision)

        .DESCRIPTION
        Disconnect the connection on ArubaOS Switchs

        .EXAMPLE
        Disconnect-ArubaSW

        Disconnect the connection

        .EXAMPLE
        Disconnect-ArubaSW -confirm:$false

        Disconnect the connection with no confirmation

    #>

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'high')]
    Param(
        [Parameter (Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$connection = (Get-ArubaSWDefaultConnection)
    )

    Begin {
    }

    Process {

        $uri = "login-sessions"

        if ($PSCmdlet.ShouldProcess($connection.server, 'Remove Connection')) {
            $null = Invoke-ArubaSWWebRequest -method "DELETE" -uri $uri -connection $connection
            if (Test-Path variable:global:DefaultArubaSWConnection) {
                Remove-Variable -name DefaultArubaSWConnection -scope global
            }
            #Restore the process-wide TLS state changed for -SkipCertificateCheck on Desktop
            #(no-op on PowerShell Core, where -SkipCertificateCheck is passed per request)
            Restore-ArubaSWSSL
        }

    }

    End {
    }
}
