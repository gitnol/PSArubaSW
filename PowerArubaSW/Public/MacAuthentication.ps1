#
# Copyright 2026, PowerArubaSW contributors
# SPDX-License-Identifier: Apache-2.0
#
# MAC-Authentifizierung (Inkrement I39). Felder und Verhalten stammen von einer 2540 (YC.16.11.0010), nicht aus der Spec.

function Get-ArubaSWMacAuthentication {

    <#
        .SYNOPSIS
        Get the global MAC authentication settings.

        .DESCRIPTION
        Reads GET /mac-authentication: unauthorized_vlan_id.

        .EXAMPLE
        Get-ArubaSWMacAuthentication
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
        $response = Invoke-ArubaSWWebRequest -method "GET" -uri "mac-authentication" -connection $connection
        $response.content | ConvertFrom-Json
    }

    End {
    }
}

function Set-ArubaSWMacAuthentication {

    <#
        .SYNOPSIS
        Configure the global MAC authentication settings.

        .DESCRIPTION
        Sends PUT /mac-authentication. The VLAN given as -unauthorized_vlan_id must exist (otherwise "VLAN ID, not found"); 0 means none.

        .EXAMPLE
        Set-ArubaSWMacAuthentication -unauthorized_vlan_id 0
    #>

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    Param(
        [Parameter(Mandatory = $false)]
        [ValidateRange(0, 4094)]
        [int]$unauthorized_vlan_id,
        [Parameter (Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$connection = (Get-ArubaSWDefaultConnection)
    )

    Begin {
    }

    Process {
        $changes = @{}
        foreach ($name in 'unauthorized_vlan_id') {
            if ($PsBoundParameters.ContainsKey($name)) { $changes[$name] = $PsBoundParameters[$name] }
        }

        $uri = "mac-authentication"
        $body = Get-ArubaSWMergedBody -Uri $uri -Changes $changes -Connection $connection

        if ($PSCmdlet.ShouldProcess('mac-authentication', 'Configure the global MAC authentication settings')) {
            $response = Invoke-ArubaSWWebRequest -method "PUT" -body $body -uri $uri -connection $connection
            if ($response.content) {
                $response.content | ConvertFrom-Json
            }
        }
    }

    End {
    }
}

function Get-ArubaSWMacAuthenticationPort {

    <#
        .SYNOPSIS
        Get the MAC authentication settings of ports.

        .DESCRIPTION
        Reads GET /mac-authentication/port (all ports) or /mac-authentication/port/<port_id>.

        .EXAMPLE
        Get-ArubaSWMacAuthenticationPort -port_id 21
    #>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$port_id,
        [Parameter (Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$connection = (Get-ArubaSWDefaultConnection)
    )

    Begin {
    }

    Process {
        if ($PsBoundParameters.ContainsKey('port_id')) {
            Get-ArubaSWPortResource -Path "mac-authentication/port" -ElementName 'mac_authentication_port_element' -PortId $port_id -Connection $connection
        }
        else {
            Get-ArubaSWPortResource -Path "mac-authentication/port" -ElementName 'mac_authentication_port_element' -Connection $connection
        }
    }

    End {
    }
}

function Set-ArubaSWMacAuthenticationPort {

    <#
        .SYNOPSIS
        Configure the MAC authentication of a port.

        .DESCRIPTION
        Sends PUT /mac-authentication/port/<port_id>. Only the parameters you pass change; the cmdlet reads the port first and sends the complete object. Verified on a 2540 (YC.16.11) with enable, disable and -quiet_period. Accepts pipeline input by property name (port_id).

        .EXAMPLE
        Set-ArubaSWMacAuthenticationPort -port_id 21 -is_mac_authentication_enabled -quiet_period 70
    #>

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    Param(
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$port_id,
        [Parameter(Mandatory = $false)]
        [switch]$is_mac_authentication_enabled,
        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 256)]
        [int]$mac_address_limit,
        [Parameter(Mandatory = $false)]
        [switch]$reauthenticate,
        [Parameter(Mandatory = $false)]
        [ValidateRange(0, 4094)]
        [int]$unauthorized_vlan_id,
        [Parameter(Mandatory = $false)]
        [ValidateRange(0, 4094)]
        [int]$authorized_vlan_id,
        [Parameter(Mandatory = $false)]
        [ValidateRange(0, 2147483647)]
        [int]$cached_reauth_period,
        [Parameter(Mandatory = $false)]
        [ValidateRange(0, 2147483647)]
        [int]$logoff_period,
        [Parameter(Mandatory = $false)]
        [ValidateRange(0, 2147483647)]
        [int]$quiet_period,
        [Parameter(Mandatory = $false)]
        [ValidateRange(0, 2147483647)]
        [int]$reauth_period,
        [Parameter(Mandatory = $false)]
        [ValidateRange(0, 2147483647)]
        [int]$server_timeout,
        [Parameter (Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$connection = (Get-ArubaSWDefaultConnection)
    )

    Begin {
    }

    Process {
        $changes = @{}
        if ($PsBoundParameters.ContainsKey('is_mac_authentication_enabled')) { $changes['is_mac_authentication_enabled'] = [bool]$is_mac_authentication_enabled }
        if ($PsBoundParameters.ContainsKey('reauthenticate')) { $changes['reauthenticate'] = [bool]$reauthenticate }
        foreach ($name in 'mac_address_limit', 'unauthorized_vlan_id', 'authorized_vlan_id', 'cached_reauth_period', 'logoff_period', 'quiet_period', 'reauth_period', 'server_timeout') {
            if ($PsBoundParameters.ContainsKey($name)) { $changes[$name] = $PsBoundParameters[$name] }
        }

        $uri = "mac-authentication/port/${port_id}"
        $body = Get-ArubaSWMergedBody -Uri $uri -Changes $changes -Connection $connection

        if ($PSCmdlet.ShouldProcess($port_id, 'Configure the MAC authentication of a port')) {
            $response = Invoke-ArubaSWWebRequest -method "PUT" -body $body -uri $uri -connection $connection
            if ($response.content) {
                $response.content | ConvertFrom-Json
            }
        }
    }

    End {
    }
}

