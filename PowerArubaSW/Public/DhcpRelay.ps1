#
# Copyright 2026, PowerArubaSW contributors
# SPDX-License-Identifier: Apache-2.0
#

function Get-ArubaSWDhcpRelay {

    <#
        .SYNOPSIS
        Get global DHCP relay configuration.

        .DESCRIPTION
        Reads GET /dhcp-relay -- returns the global DHCP relay attributes.

        .EXAMPLE
        Get-ArubaSWDhcpRelay
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
        $uri = "dhcp-relay"
        $response = Invoke-ArubaSWWebRequest -method "GET" -uri $uri -connection $connection
        $response.content | ConvertFrom-Json
    }

    End {
    }
}

function Set-ArubaSWDhcpRelay {

    <#
        .SYNOPSIS
        Update global DHCP relay configuration.

        .DESCRIPTION
        Sends PUT /dhcp-relay.

        .EXAMPLE
        Set-ArubaSWDhcpRelay -is_dhcp_relay_enabled
        Set-ArubaSWDhcpRelay -is_dhcp_relay_enabled:$false
    #>

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    Param(
        [Parameter(Mandatory = $false)]
        [switch]$is_dhcp_relay_enabled,
        [Parameter (Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$connection = (Get-ArubaSWDefaultConnection)
    )

    Begin {
    }

    Process {
        $uri = "dhcp-relay"
        $payload = New-Object -TypeName PSObject

        if ($PsBoundParameters.ContainsKey('is_dhcp_relay_enabled')) {
            $payload | Add-Member -name "is_dhcp_relay_enabled" -membertype NoteProperty -Value ([bool]$is_dhcp_relay_enabled)
        }

        if ($PSCmdlet.ShouldProcess($connection.server, 'Configure DHCP Relay')) {
            $response = Invoke-ArubaSWWebRequest -method "PUT" -body $payload -uri $uri -connection $connection
            if ($response.content) {
                $response.content | ConvertFrom-Json
            }
        }
    }

    End {
    }
}

function Get-ArubaSWDhcpRelayOption82 {

    <#
        .SYNOPSIS
        Get DHCP relay Option 82 configuration.

        .DESCRIPTION
        Reads GET /dhcp-relay/option_82.

        .EXAMPLE
        Get-ArubaSWDhcpRelayOption82
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
        $uri = "dhcp-relay/option_82"
        $response = Invoke-ArubaSWWebRequest -method "GET" -uri $uri -connection $connection
        $response.content | ConvertFrom-Json
    }

    End {
    }
}

function Set-ArubaSWDhcpRelayOption82 {

    <#
        .SYNOPSIS
        Update DHCP relay Option 82 configuration.

        .DESCRIPTION
        Sends PUT /dhcp-relay/option_82. The switch rejects every PUT without is_option82_enabled
        ("Missing mandatory parameter is_option82_enabled"), so the switch -is_option82_enabled is
        mandatory here; pass -is_option82_enabled:$false to switch it off.
        Fields on the 2540 (YC.16.11, verified on a test switch): is_option82_enabled, dhcp_relay_action
        (DRO82A_KEEP | DRO82A_DROP | DRO82A_REPLACE), dhcp_relay_remote_id (DRO82RI_IP | DRO82RI_MAC),
        is_validation_enabled. The switch rejects other values ("Invalid dhcp_relay_action").
        Each field was accepted on its own; a call that combined -is_validation_enabled with
        DRO82A_KEEP and DRO82RI_IP was rejected, so change the fields step by step if a combination fails.
        The former -option82_policy was unknown to the switch and was removed.

        .EXAMPLE
        Set-ArubaSWDhcpRelayOption82 -is_option82_enabled -dhcp_relay_action DRO82A_REPLACE

        Enable Option 82 and replace existing option data.

        .EXAMPLE
        Set-ArubaSWDhcpRelayOption82 -is_option82_enabled:$false

        Disable Option 82.
    #>

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    Param(
        [Parameter(Mandatory = $true)]
        [switch]$is_option82_enabled,
        [Parameter(Mandatory = $false)]
        [ValidateSet('DRO82A_KEEP', 'DRO82A_DROP', 'DRO82A_REPLACE')]
        [string]$dhcp_relay_action,
        [Parameter(Mandatory = $false)]
        [ValidateSet('DRO82RI_IP', 'DRO82RI_MAC')]
        [string]$dhcp_relay_remote_id,
        [Parameter(Mandatory = $false)]
        [switch]$is_validation_enabled,
        [Parameter (Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$connection = (Get-ArubaSWDefaultConnection)
    )

    Begin {
    }

    Process {

        $uri = "dhcp-relay/option_82"

        $payload = New-Object -TypeName PSObject
        $payload | Add-Member -name "is_option82_enabled" -membertype NoteProperty -Value ([bool]$is_option82_enabled)

        if ($PsBoundParameters.ContainsKey('dhcp_relay_action')) {
            $payload | Add-Member -name "dhcp_relay_action" -membertype NoteProperty -Value $dhcp_relay_action
        }

        if ($PsBoundParameters.ContainsKey('dhcp_relay_remote_id')) {
            $payload | Add-Member -name "dhcp_relay_remote_id" -membertype NoteProperty -Value $dhcp_relay_remote_id
        }

        if ($PsBoundParameters.ContainsKey('is_validation_enabled')) {
            $payload | Add-Member -name "is_validation_enabled" -membertype NoteProperty -Value ([bool]$is_validation_enabled)
        }

        if ($PSCmdlet.ShouldProcess($connection.server, 'Configure DHCP Relay Option 82')) {
            $response = Invoke-ArubaSWWebRequest -method "PUT" -body $payload -uri $uri -connection $connection
            if ($response.content) {
                $response.content | ConvertFrom-Json
            }
        }
    }

    End {
    }
}

function Get-ArubaSWDhcpRelayVlan {

    <#
        .SYNOPSIS
        Get DHCP relay VLAN configuration.

        .DESCRIPTION
        Reads GET /vlans/{vlanId}/dhcp-relay. The resource exists only up to REST v3 (404 from v4 on, measured on a
        2540); the cmdlet limits the version itself. The field is dhcp_helper_addresses (objects with version/octets).

        .EXAMPLE
        Get-ArubaSWDhcpRelayVlan -vlan_id 1
    #>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [int]$vlan_id,
        [Parameter (Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$connection = (Get-ArubaSWDefaultConnection)
    )

    Begin {
    }

    Process {
        $uri = "vlans/${vlan_id}/dhcp-relay"
        $response = Invoke-ArubaSWWebRequest -method "GET" -uri $uri -api_version (Get-ArubaSWDhcpRelayVlanApiVersion -Connection $connection) -connection $connection
        $response.content | ConvertFrom-Json
    }

    End {
    }
}

function Set-ArubaSWDhcpRelayVlan {

    <#
        .SYNOPSIS
        Update DHCP relay VLAN configuration.

        .DESCRIPTION
        Sends PUT /vlans/{vlanId}/dhcp-relay with the field dhcp_helper_addresses (REST v3, the highest version that
        has the resource). Verified on a 2540: an empty array (-helper_addresses @()) removes all helper addresses.

        .EXAMPLE
        Set-ArubaSWDhcpRelayVlan -vlan_id 1 -helper_addresses @("192.168.1.10", "192.168.1.11")

        .EXAMPLE
        Set-ArubaSWDhcpRelayVlan -vlan_id 1 -helper_addresses @()

        Remove all helper addresses of VLAN 1.
    #>

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    Param(
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [int]$vlan_id,
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [ipaddress[]]$helper_addresses,
        [Parameter (Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$connection = (Get-ArubaSWDefaultConnection)
    )

    Begin {
    }

    Process {
        $uri = "vlans/${vlan_id}/dhcp-relay"
        $payload = New-Object -TypeName PSObject

        $payload | Add-Member -name "vlan_id" -membertype NoteProperty -Value $vlan_id
        $addresses = @(foreach ($h in $helper_addresses) { [pscustomobject]@{ version = 'IAV_IP_V4'; octets = $h.ToString() } })
        $payload | Add-Member -name "dhcp_helper_addresses" -membertype NoteProperty -Value $addresses

        if ($PSCmdlet.ShouldProcess("VLAN $vlan_id", 'Configure DHCP Relay VLAN Helper Addresses')) {
            $response = Invoke-ArubaSWWebRequest -method "PUT" -body $payload -uri $uri -api_version (Get-ArubaSWDhcpRelayVlanApiVersion -Connection $connection) -connection $connection
            if ($response.content) {
                $response.content | ConvertFrom-Json
            }
        }
    }

    End {
    }
}
