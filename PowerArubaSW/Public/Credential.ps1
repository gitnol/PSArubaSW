#
# Copyright 2026, PowerArubaSW contributors
# SPDX-License-Identifier: Apache-2.0
#

function Save-ArubaSWCredential {

    <#
        .SYNOPSIS
        Store switch credentials in the Windows Credential Manager.

        .DESCRIPTION
        Stores the administrative credentials of an ArubaOS Switch as a generic credential in the
        Windows Credential Manager (encrypted by Windows, only for this user on this computer,
        no roaming). The password never appears on a command line.

        Connect-ArubaSW uses a stored credential automatically when no -Credentials/-Password is
        given: the default target is `PowerArubaSW_<server>` (see -Server), or any target name
        with `Connect-ArubaSW -CredentialTarget`.

        Windows only. An existing target is overwritten.

        .EXAMPLE
        Save-ArubaSWCredential -Server 192.0.2.1

        Ask for the credentials and store them under `PowerArubaSW_192.0.2.1`.
        `Connect-ArubaSW -Server 192.0.2.1` then logs in without a prompt.

        .EXAMPLE
        Save-ArubaSWCredential -CredentialTarget 'SwitchLab' -Credentials (Get-Credential manager)

        Store the given credentials under the target name `SwitchLab`.
        Use them with `Connect-ArubaSW -Server 192.0.2.1 -CredentialTarget SwitchLab`.
    #>

    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingPlainTextForPassword", "CredentialTarget", Justification = "CredentialTarget is the NAME of a Credential Manager entry, not a secret.")]
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium', DefaultParameterSetName = 'ByServer')]
    Param(
        [Parameter(Mandatory = $true, ParameterSetName = 'ByServer', Position = 1)]
        [ValidateNotNullOrEmpty()]
        [String]$Server,
        [Parameter(Mandatory = $true, ParameterSetName = 'ByTarget')]
        [ValidateNotNullOrEmpty()]
        [String]$CredentialTarget,
        [Parameter(Mandatory = $false)]
        [PSCredential]$Credentials
    )

    Begin {
    }

    Process {

        if ($PSCmdlet.ParameterSetName -eq 'ByServer') {
            $target = Get-ArubaSWDefaultCredentialTarget -Server $Server
        }
        else {
            $target = $CredentialTarget
        }

        if ($null -eq $Credentials) {
            $Credentials = Get-Credential -Message "Credentials to store for '$target'"
        }

        if ($PSCmdlet.ShouldProcess($target, 'Store credential')) {
            Set-ArubaSWStoredCredential -Target $target -Credential $Credentials -Confirm:$false
        }
    }

    End {
    }
}

function Remove-ArubaSWCredential {

    <#
        .SYNOPSIS
        Delete stored switch credentials from the Windows Credential Manager.

        .DESCRIPTION
        Deletes the generic credential created by Save-ArubaSWCredential. Warns when the target
        does not exist. Windows only.

        .EXAMPLE
        Remove-ArubaSWCredential -Server 192.0.2.1

        Delete the credential stored under `PowerArubaSW_192.0.2.1`.

        .EXAMPLE
        Remove-ArubaSWCredential -CredentialTarget 'SwitchLab'

        Delete the credential stored under the target name `SwitchLab`.
    #>

    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingPlainTextForPassword", "CredentialTarget", Justification = "CredentialTarget is the NAME of a Credential Manager entry, not a secret.")]
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium', DefaultParameterSetName = 'ByServer')]
    Param(
        [Parameter(Mandatory = $true, ParameterSetName = 'ByServer', Position = 1)]
        [ValidateNotNullOrEmpty()]
        [String]$Server,
        [Parameter(Mandatory = $true, ParameterSetName = 'ByTarget')]
        [ValidateNotNullOrEmpty()]
        [String]$CredentialTarget
    )

    Begin {
    }

    Process {

        if ($PSCmdlet.ParameterSetName -eq 'ByServer') {
            $target = Get-ArubaSWDefaultCredentialTarget -Server $Server
        }
        else {
            $target = $CredentialTarget
        }

        if ($PSCmdlet.ShouldProcess($target, 'Delete stored credential')) {
            $removed = Remove-ArubaSWStoredCredential -Target $target -Confirm:$false
            if (-not $removed) {
                Write-Warning "Credential target '$target' does not exist."
            }
        }
    }

    End {
    }
}
