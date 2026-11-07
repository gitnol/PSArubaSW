#
# Copyright 2026, PowerArubaSW contributors
# SPDX-License-Identifier: Apache-2.0
#

function Get-ArubaSWIncludeCredentials {

    <#
        .SYNOPSIS
        Get the include-credentials setting of the switch.

        .DESCRIPTION
        Reads GET /system/include-credentials -- returns `include_credentials_in_response` and `store_in_config`.
        When enabled, the switch includes passwords and other credentials (as hashes or
        in clear text, depending on the firmware) in the output of the running
        configuration and in saved/exported configuration files.

        .EXAMPLE
        Get-ArubaSWIncludeCredentials

        Returns the current include-credentials setting.
    #>

    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseSingularNouns", "")]
    [CmdletBinding()]
    Param(
        [Parameter (Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$connection = (Get-ArubaSWDefaultConnection)
    )

    Begin {
    }

    Process {

        $uri = "system/include-credentials"

        $response = Invoke-ArubaSWWebRequest -method "GET" -uri $uri -connection $connection

        $response.content | ConvertFrom-Json
    }

    End {
    }
}

function Set-ArubaSWIncludeCredentials {

    <#
        .SYNOPSIS
        Enable or disable include-credentials on the switch.

        .DESCRIPTION
        Sends PUT /system/include-credentials. Partial-update-Pattern: nur explizit
        gesetzte Felder gehen in den Request-Body.

        Security: with include-credentials enabled the switch writes credentials into
        its configuration output (and into backups of it). Enabling therefore requires
        -Force (same pattern as `Connect-ArubaSW -httpOnly`); without -Force the cmdlet
        warns and throws BEFORE anything is sent to the switch. Disabling needs no -Force.
        The cmdlet uses ConfirmImpact 'High', so it also prompts unless -Confirm:$false is set.
        Verified on the 2540 (YC.16.11): the switch field is include_credentials_in_response
        (ICS_ENABLED | ICS_DISABLED). Enabling also sets store_in_config to true and writes the
        credentials into the STARTUP configuration; PUT with ICS_DISABLED does not reset
        store_in_config (a PUT with store_in_config=false is rejected), and the CLI command
        "no include-credentials" removed the configured manager/operator passwords from the
        configuration on a test switch. Do not enable it on a switch you cannot reconfigure from the console.

        .EXAMPLE
        Set-ArubaSWIncludeCredentials -is_include_credentials_enabled:$false

        Disable include-credentials (credentials no longer appear in the configuration output).

        .EXAMPLE
        Set-ArubaSWIncludeCredentials -is_include_credentials_enabled -Force

        Enable include-credentials. -Force confirms that credentials may appear in the
        configuration output.
    #>

    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseSingularNouns", "")]
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    Param(
        [Parameter(Mandatory = $false)]
        [switch]$is_include_credentials_enabled,
        [Parameter(Mandatory = $false)]
        [switch]$Force,
        [Parameter (Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$connection = (Get-ArubaSWDefaultConnection)
    )

    Begin {
    }

    Process {

        $uri = "system/include-credentials"

        if ($PsBoundParameters.ContainsKey('is_include_credentials_enabled') -and $is_include_credentials_enabled -and -not $Force) {
            Write-Warning "Include-credentials writes credentials into the configuration output and into backups of it."
            Write-Warning "Anyone who can read the configuration can then read the credentials."
            Write-Warning "Confirm explicitly with -Force or leave include-credentials disabled."
            throw "Refused enabling include-credentials without -Force: explicit confirmation required."
        }

        $includeCredentials = New-Object -TypeName PSObject

        if ($PsBoundParameters.ContainsKey('is_include_credentials_enabled')) {
            # Der Switch kennt das Feld include_credentials_in_response (ICS_ENABLED | ICS_DISABLED); is_include_credentials_enabled wurde ignoriert.
            $value = if ($is_include_credentials_enabled) { 'ICS_ENABLED' } else { 'ICS_DISABLED' }
            $includeCredentials | Add-Member -name "include_credentials_in_response" -membertype NoteProperty -Value $value
        }

        if ($PSCmdlet.ShouldProcess($connection.server, 'Configure include-credentials')) {
            $response = Invoke-ArubaSWWebRequest -method "PUT" -body $includeCredentials -uri $uri -connection $connection

            $response.content | ConvertFrom-Json
        }
    }

    End {
    }
}
