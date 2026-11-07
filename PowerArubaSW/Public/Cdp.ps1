#
# Copyright 2026, PowerArubaSW contributors
# SPDX-License-Identifier: Apache-2.0
#

function Get-ArubaSWCdp {

    <#
        .SYNOPSIS
        Get global CDP (Cisco Discovery Protocol) configuration.

        .DESCRIPTION
        Reads the global CDP attributes from the switch via GET /cdp:
        is_cdp_enabled, cdp_holdtime, cdp_timer.

        .EXAMPLE
        Get-ArubaSWCdp

        Returns the current CDP configuration.
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

        $uri = "cdp"

        $response = Invoke-ArubaSWWebRequest -method "GET" -uri $uri -connection $connection

        $response.content | ConvertFrom-Json
    }

    End {
    }
}

function Set-ArubaSWCdp {

    <#
        .SYNOPSIS
        Configure global CDP attributes.

        .DESCRIPTION
        Sends PUT /cdp with is_cdp_enabled and/or mode. Only parameters that the caller passed are
        included in the request body -- other fields keep their current value.
        Verified on the 2540 (YC.16.11): the switch knows only is_cdp_enabled and mode (CDPM_RXONLY
        on all switches seen so far). The former -cdp_holdtime and -cdp_timer were ignored by the
        switch and were removed. Other mode values were rejected ("Invalid mode"), so the value is
        passed on unchanged; use the value Get-ArubaSWCdp returns.

        .EXAMPLE
        Set-ArubaSWCdp -is_cdp_enabled:$true

        Enable CDP globally.

        .EXAMPLE
        Set-ArubaSWCdp -is_cdp_enabled:$false

        Disable CDP globally.

        .EXAMPLE
        Set-ArubaSWCdp -mode CDPM_RXONLY

        Set the CDP mode (receive only).
    #>

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    Param(
        [Parameter(Mandatory = $false)]
        [switch]$is_cdp_enabled,
        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]$mode,
        [Parameter (Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$connection = (Get-ArubaSWDefaultConnection)
    )

    Begin {
    }

    Process {

        $uri = "cdp"

        $cdp = New-Object -TypeName PSObject

        if ($PsBoundParameters.ContainsKey('is_cdp_enabled')) {
            $cdp | Add-Member -name "is_cdp_enabled" -membertype NoteProperty -Value ([bool]$is_cdp_enabled)
        }

        if ($PsBoundParameters.ContainsKey('mode')) {
            $cdp | Add-Member -name "mode" -membertype NoteProperty -Value $mode
        }

        if ($PSCmdlet.ShouldProcess($connection.server, 'Configure CDP')) {
            $response = Invoke-ArubaSWWebRequest -method "PUT" -body $cdp -uri $uri -connection $connection

            $response.content | ConvertFrom-Json
        }
    }

    End {
    }
}
