#
# Copyright 2026, PowerArubaSW contributors
# SPDX-License-Identifier: Apache-2.0
#
# Web-Authentifizierung (Inkrement I39). Felder und Verhalten stammen von einer 2540 (YC.16.11.0010), nicht aus der Spec.

function Get-ArubaSWWebauth {

    <#
        .SYNOPSIS
        Get the global web authentication settings.

        .DESCRIPTION
        Reads GET /webauth: override_ewa_servers, ewa_server_1..3, dhcp_ip, dhcp_ip_netmask, dhcp_lease, use_radius_response_msg, access_denied_message.

        .EXAMPLE
        Get-ArubaSWWebauth
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
        $response = Invoke-ArubaSWWebRequest -method "GET" -uri "webauth" -connection $connection
        $response.content | ConvertFrom-Json
    }

    End {
    }
}

function Set-ArubaSWWebauth {

    <#
        .SYNOPSIS
        Configure the global web authentication settings.

        .DESCRIPTION
        Sends PUT /webauth. Only the parameters you pass change; the cmdlet reads the current settings first. Verified on a 2540 (YC.16.11) with -dhcp_lease and -access_denied_message. -dhcp_ip and -dhcp_ip_netmask are sent as address objects.

        .EXAMPLE
        Set-ArubaSWWebauth -dhcp_lease 20
    #>

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    Param(
        [Parameter(Mandatory = $false)]
        [switch]$override_ewa_servers,
        [Parameter(Mandatory = $false)]
        [string]$ewa_server_1,
        [Parameter(Mandatory = $false)]
        [string]$ewa_server_2,
        [Parameter(Mandatory = $false)]
        [string]$ewa_server_3,
        [Parameter(Mandatory = $false)]
        [ipaddress]$dhcp_ip,
        [Parameter(Mandatory = $false)]
        [ipaddress]$dhcp_ip_netmask,
        [Parameter(Mandatory = $false)]
        [ValidateRange(0, 2147483647)]
        [int]$dhcp_lease,
        [Parameter(Mandatory = $false)]
        [switch]$use_radius_response_msg,
        [Parameter(Mandatory = $false)]
        [string]$access_denied_message,
        [Parameter (Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$connection = (Get-ArubaSWDefaultConnection)
    )

    Begin {
    }

    Process {
        $changes = @{}
        if ($PsBoundParameters.ContainsKey('override_ewa_servers')) { $changes['override_ewa_servers'] = [bool]$override_ewa_servers }
        if ($PsBoundParameters.ContainsKey('use_radius_response_msg')) { $changes['use_radius_response_msg'] = [bool]$use_radius_response_msg }
        if ($PsBoundParameters.ContainsKey('dhcp_ip')) { $changes['dhcp_ip'] = [pscustomobject]@{ version = 'IAV_IP_V4'; octets = $dhcp_ip.ToString() } }
        if ($PsBoundParameters.ContainsKey('dhcp_ip_netmask')) { $changes['dhcp_ip_netmask'] = [pscustomobject]@{ version = 'IAV_IP_V4'; octets = $dhcp_ip_netmask.ToString() } }
        foreach ($name in 'ewa_server_1', 'ewa_server_2', 'ewa_server_3', 'dhcp_lease', 'access_denied_message') {
            if ($PsBoundParameters.ContainsKey($name)) { $changes[$name] = $PsBoundParameters[$name] }
        }

        $uri = "webauth"
        $body = Get-ArubaSWMergedBody -Uri $uri -Changes $changes -Connection $connection

        if ($PSCmdlet.ShouldProcess('webauth', 'Configure the global web authentication settings')) {
            $response = Invoke-ArubaSWWebRequest -method "PUT" -body $body -uri $uri -connection $connection
            if ($response.content) {
                $response.content | ConvertFrom-Json
            }
        }
    }

    End {
    }
}

function Get-ArubaSWWebauthPort {

    <#
        .SYNOPSIS
        Get the web authentication settings of ports.

        .DESCRIPTION
        Reads GET /webauth/port (all ports) or /webauth/port/<port_id>.

        .EXAMPLE
        Get-ArubaSWWebauthPort -port_id 21
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
            Get-ArubaSWPortResource -Path "webauth/port" -ElementName 'webauth_port_element' -PortId $port_id -Connection $connection
        }
        else {
            Get-ArubaSWPortResource -Path "webauth/port" -ElementName 'webauth_port_element' -Connection $connection
        }
    }

    End {
    }
}

function Set-ArubaSWWebauthPort {

    <#
        .SYNOPSIS
        Configure the web authentication of a port.

        .DESCRIPTION
        Sends PUT /webauth/port/<port_id>. Only the parameters you pass change; the cmdlet reads the port first and sends the complete object. Verified on a 2540 (YC.16.11): -redirect_url must be a valid URL ("Bad URL format"); an empty string does NOT clear an existing URL (use the CLI: no aaa port-access web-based <port> redirect-url). Accepts pipeline input by property name (port_id).

        .EXAMPLE
        Set-ArubaSWWebauthPort -port_id 21 -is_webauth_enabled -client_limit 2
    #>

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    Param(
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$port_id,
        [Parameter(Mandatory = $false)]
        [switch]$is_webauth_enabled,
        [Parameter(Mandatory = $false)]
        [ValidateRange(0, 4094)]
        [int]$unauthorized_vlan_id,
        [Parameter(Mandatory = $false)]
        [ValidateRange(0, 2147483647)]
        [int]$cached_reauth_period,
        [Parameter(Mandatory = $false)]
        [ValidateRange(0, 2147483647)]
        [int]$client_limit,
        [Parameter(Mandatory = $false)]
        [switch]$client_moves,
        [Parameter(Mandatory = $false)]
        [ValidateRange(0, 2147483647)]
        [int]$logoff_period,
        [Parameter(Mandatory = $false)]
        [ValidateRange(0, 2147483647)]
        [int]$max_requests,
        [Parameter(Mandatory = $false)]
        [ValidateRange(0, 2147483647)]
        [int]$max_retries,
        [Parameter(Mandatory = $false)]
        [ValidateRange(0, 2147483647)]
        [int]$quiet_period,
        [Parameter(Mandatory = $false)]
        [ValidateRange(0, 2147483647)]
        [int]$reauth_period,
        [Parameter(Mandatory = $false)]
        [switch]$reauthenticate,
        [Parameter(Mandatory = $false)]
        [string]$redirect_url,
        [Parameter(Mandatory = $false)]
        [ValidateRange(0, 2147483647)]
        [int]$server_timeout,
        [Parameter(Mandatory = $false)]
        [switch]$ssl_login,
        [Parameter (Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$connection = (Get-ArubaSWDefaultConnection)
    )

    Begin {
    }

    Process {
        $changes = @{}
        if ($PsBoundParameters.ContainsKey('is_webauth_enabled')) { $changes['is_webauth_enabled'] = [bool]$is_webauth_enabled }
        if ($PsBoundParameters.ContainsKey('client_moves')) { $changes['client_moves'] = [bool]$client_moves }
        if ($PsBoundParameters.ContainsKey('reauthenticate')) { $changes['reauthenticate'] = [bool]$reauthenticate }
        if ($PsBoundParameters.ContainsKey('ssl_login')) { $changes['ssl_login'] = [bool]$ssl_login }
        foreach ($name in 'unauthorized_vlan_id', 'cached_reauth_period', 'client_limit', 'logoff_period', 'max_requests', 'max_retries', 'quiet_period', 'reauth_period', 'redirect_url', 'server_timeout') {
            if ($PsBoundParameters.ContainsKey($name)) { $changes[$name] = $PsBoundParameters[$name] }
        }

        $uri = "webauth/port/${port_id}"
        $body = Get-ArubaSWMergedBody -Uri $uri -Changes $changes -Connection $connection

        if ($PSCmdlet.ShouldProcess($port_id, 'Configure the web authentication of a port')) {
            $response = Invoke-ArubaSWWebRequest -method "PUT" -body $body -uri $uri -connection $connection
            if ($response.content) {
                $response.content | ConvertFrom-Json
            }
        }
    }

    End {
    }
}

