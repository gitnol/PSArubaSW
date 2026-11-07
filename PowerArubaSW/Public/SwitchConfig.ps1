#
# Copyright 2026, PowerArubaSW contributors
# SPDX-License-Identifier: Apache-2.0
#

function Save-ArubaSWConfig {

    <#
        .SYNOPSIS
        Persist the running switch configuration to startup-config (write memory).

        .DESCRIPTION
        Runs "write memory" through the CLI endpoint (POST /cli): copies
        running-config to startup-config (flash), so changes survive a reboot.
        Without this, any Set-* call only modifies the in-memory configuration.

        Returns the CLI result object (cmd, status CCS_SUCCESS, error_msg).
        The REST resource /switch-config of the specification does not exist
        on a 2540 (YC.16.11.0010, 404), the CLI endpoint does.

        .EXAMPLE
        Save-ArubaSWConfig

        Saves the current running configuration to startup-config. Prompts
        for confirmation by default (ConfirmImpact='High'); pass -Confirm:$false
        to suppress in scripts.

        .EXAMPLE
        Set-ArubaSWVlans -id 85 -name 'production' -Confirm:$false ; Save-ArubaSWConfig -Confirm:$false

        Apply a VLAN change and persist it.

        .NOTES
        Verified on a 2540 (YC.16.11.0010): "write memory" answers CCS_SUCCESS with an
        empty result; Get-ArubaSWConfigStatus then reports that running and saved
        configuration match.
    #>

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    Param(
        [Parameter (Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$connection = (Get-ArubaSWDefaultConnection)
    )

    Begin {
    }

    Process {

        if ($PSCmdlet.ShouldProcess($connection.server, 'Save running-config to startup-config')) {
            Get-ArubaSWCli -cmd 'write memory' -connection $connection
        }
    }

    End {
    }
}

function Get-ArubaSWConfigStatus {

    <#
        .SYNOPSIS
        Tell whether the running configuration is saved.

        .DESCRIPTION
        Runs "show config status" through the CLI endpoint and returns the CLI result
        object; its result text is "The running configuration matches the saved
        configuration." when everything is saved. Useful as a follow-up call after
        Save-ArubaSWConfig. (GET /switch-config/status of the specification does not
        exist on a 2540, YC.16.11.0010.)

        .EXAMPLE
        Get-ArubaSWConfigStatus

        Returns the CLI result of "show config status".
    #>

    [CmdletBinding()]
    Param(
        [Parameter (Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$connection = (Get-ArubaSWDefaultConnection)
    )

    Begin {
    }

    Process {

        Get-ArubaSWCli -cmd 'show config status' -connection $connection
    }

    End {
    }
}
