#
# Copyright 2026, PowerArubaSW contributors
# SPDX-License-Identifier: Apache-2.0
#

function Get-ArubaSWJumbo {

    <#
        .SYNOPSIS
        Get global Jumbo-frame configuration.

        .DESCRIPTION
        Reads GET /jumbo -- returns the global Jumbo-frame attributes
        (`max_frame_size`, `ip_mtu_size`). Per-VLAN-Jumbo wird ueber `Vlan.is_jumbo_enabled`
        gesteuert, nicht ueber diesen globalen Endpoint.

        .EXAMPLE
        Get-ArubaSWJumbo

        Returns the current global Jumbo-frame configuration.
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

        $uri = "jumbo"

        $response = Invoke-ArubaSWWebRequest -method "GET" -uri $uri -connection $connection

        $response.content | ConvertFrom-Json
    }

    End {
    }
}

function Set-ArubaSWJumbo {
    <#
        .SYNOPSIS
        Configure the global Jumbo-frame sizes.

        .DESCRIPTION
        Sends PUT /jumbo with -max_frame_size (1518..9216) and/or -ip_mtu_size (1500..9198).
        Only parameters passed are included in the body. Verified on the 2540 (YC.16.11):
        the switch derives ip_mtu_size as max_frame_size minus 18 when only the frame size
        is sent, and rejects an ip_mtu_size above max_frame_size minus 18.
        Whether a VLAN carries jumbo frames is set per VLAN (is_jumbo_enabled of Set-ArubaSWVlans);
        the former -is_jumbo_enabled parameter of this cmdlet was ignored by the switch and was removed.

        .EXAMPLE
        Set-ArubaSWJumbo -max_frame_size 9216

        Allow frames up to 9216 bytes (ip_mtu_size follows as 9198).

        .EXAMPLE
        Set-ArubaSWJumbo -max_frame_size 1518

        Back to standard frame size (ip_mtu_size 1500).
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    Param(
        [Parameter(Mandatory = $false)]
        [ValidateRange(1518, 9216)]
        [int]$max_frame_size,
        [Parameter(Mandatory = $false)]
        [ValidateRange(1500, 9198)]
        [int]$ip_mtu_size,
        [Parameter (Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$connection = (Get-ArubaSWDefaultConnection)
    )
    Begin {
    }
    Process {
        $uri = "jumbo"
        $jumbo = New-Object -TypeName PSObject
        if ($PsBoundParameters.ContainsKey('max_frame_size')) {
            $jumbo | Add-Member -name "max_frame_size" -membertype NoteProperty -Value $max_frame_size
        }
        if ($PsBoundParameters.ContainsKey('ip_mtu_size')) {
            $jumbo | Add-Member -name "ip_mtu_size" -membertype NoteProperty -Value $ip_mtu_size
        }
        if ($PSCmdlet.ShouldProcess($connection.server, 'Configure Jumbo frames')) {
            $response = Invoke-ArubaSWWebRequest -method "PUT" -body $jumbo -uri $uri -connection $connection
            $response.content | ConvertFrom-Json
        }
    }
    End {
    }
}
