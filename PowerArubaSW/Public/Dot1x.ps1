#
# Copyright 2026, PowerArubaSW contributors
# SPDX-License-Identifier: Apache-2.0
#
# 802.1X (REST: /dot1x/...). Die Felder stammen von einer 2540 (YC.16.11.0010), nicht aus der Spec.
# Die Unterressourcen authenticator, port_security, supplicant und die Statistiken gibt es ab REST v3
# (authenticator und supplicant auch in v1/v2), der Standard v8 genuegt.

function Get-ArubaSWDot1x {

    <#
        .SYNOPSIS
        Get the global 802.1X configuration.

        .DESCRIPTION
        Reads GET /dot1x: is_dot1x_enabled, cached_reauth_delay, allow_gvrp_vlans, use_lldp_data.

        .EXAMPLE
        Get-ArubaSWDot1x
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
        $response = Invoke-ArubaSWWebRequest -method "GET" -uri "dot1x" -connection $connection
        $response.content | ConvertFrom-Json
    }

    End {
    }
}

function Set-ArubaSWDot1x {

    <#
        .SYNOPSIS
        Configure the global 802.1X settings.

        .DESCRIPTION
        Sends PUT /dot1x. Only the parameters you pass change; the others keep their current value (the cmdlet reads
        the current state first and sends the complete object).
        -is_dot1x_enabled switches 802.1X on or off for the whole switch (ports with an enabled authenticator start to
        authenticate clients, so check the RADIUS settings first).

        .EXAMPLE
        Set-ArubaSWDot1x -cached_reauth_delay 30

        .EXAMPLE
        Set-ArubaSWDot1x -is_dot1x_enabled:$false
    #>

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    Param(
        [Parameter(Mandatory = $false)]
        [switch]$is_dot1x_enabled,
        [Parameter(Mandatory = $false)]
        [ValidateRange(0, 2147483647)]
        [int]$cached_reauth_delay,
        [Parameter(Mandatory = $false)]
        [switch]$allow_gvrp_vlans,
        [Parameter(Mandatory = $false)]
        [switch]$use_lldp_data,
        [Parameter (Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$connection = (Get-ArubaSWDefaultConnection)
    )

    Begin {
    }

    Process {
        $changes = @{}
        if ($PsBoundParameters.ContainsKey('is_dot1x_enabled')) { $changes['is_dot1x_enabled'] = [bool]$is_dot1x_enabled }
        if ($PsBoundParameters.ContainsKey('cached_reauth_delay')) { $changes['cached_reauth_delay'] = $cached_reauth_delay }
        if ($PsBoundParameters.ContainsKey('allow_gvrp_vlans')) { $changes['allow_gvrp_vlans'] = [bool]$allow_gvrp_vlans }
        if ($PsBoundParameters.ContainsKey('use_lldp_data')) { $changes['use_lldp_data'] = [bool]$use_lldp_data }

        $uri = "dot1x"
        $body = Get-ArubaSWMergedBody -Uri $uri -Changes $changes -Connection $connection

        if ($PSCmdlet.ShouldProcess($connection.server, 'Configure 802.1X')) {
            $response = Invoke-ArubaSWWebRequest -method "PUT" -body $body -uri $uri -connection $connection
            if ($response.content) {
                $response.content | ConvertFrom-Json
            }
        }
    }

    End {
    }
}

function Get-ArubaSWDot1xAuthenticationMethod {

    <#
        .SYNOPSIS
        Get the 802.1X authentication method.

        .DESCRIPTION
        Reads GET /dot1x/authentication_method: primary_authentication_method (seen: DPAM_LOCAL), server_group,
        secondary_authentication_method (seen: DSAM_NONE).

        .EXAMPLE
        Get-ArubaSWDot1xAuthenticationMethod
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
        $response = Invoke-ArubaSWWebRequest -method "GET" -uri "dot1x/authentication_method" -connection $connection
        $response.content | ConvertFrom-Json
    }

    End {
    }
}

function Set-ArubaSWDot1xAuthenticationMethod {

    <#
        .SYNOPSIS
        Set the 802.1X authentication method.

        .DESCRIPTION
        Sends PUT /dot1x/authentication_method. Fields you do not pass keep their value.
        Verified on a 2540 (YC.16.11): primary_authentication_method accepts DPAM_LOCAL, DPAM_CHAP_RADIUS and
        DPAM_EAP_RADIUS (DPAM_RADIUS is rejected: "Unsupported primary_authentication_method type").
        secondary_authentication_method: only DSAM_NONE was accepted (DSAM_LOCAL, DSAM_AUTHORIZED, DSAM_CHAP_RADIUS and
        DSAM_EAP_RADIUS were rejected with the primary method DPAM_LOCAL), so the value is passed on unchanged.

        .EXAMPLE
        Set-ArubaSWDot1xAuthenticationMethod -secondary_authentication_method DSAM_NONE
    #>

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    Param(
        [Parameter(Mandatory = $false)]
        [ValidateSet('DPAM_LOCAL', 'DPAM_CHAP_RADIUS', 'DPAM_EAP_RADIUS')]
        [string]$primary_authentication_method,
        [Parameter(Mandatory = $false)]
        [string]$server_group,
        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]$secondary_authentication_method,
        [Parameter (Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$connection = (Get-ArubaSWDefaultConnection)
    )

    Begin {
    }

    Process {
        $changes = @{}
        foreach ($name in 'primary_authentication_method', 'server_group', 'secondary_authentication_method') {
            if ($PsBoundParameters.ContainsKey($name)) { $changes[$name] = $PsBoundParameters[$name] }
        }

        $uri = "dot1x/authentication_method"
        $body = Get-ArubaSWMergedBody -Uri $uri -Changes $changes -Connection $connection

        if ($PSCmdlet.ShouldProcess($connection.server, 'Configure 802.1X authentication method')) {
            $response = Invoke-ArubaSWWebRequest -method "PUT" -body $body -uri $uri -connection $connection
            if ($response.content) {
                $response.content | ConvertFrom-Json
            }
        }
    }

    End {
    }
}

function Get-ArubaSWDot1xAuthenticator {

    <#
        .SYNOPSIS
        Get the 802.1X authenticator configuration of the ports.

        .DESCRIPTION
        Without -port_id: GET /dot1x/authenticator, all ports (unwrapped from dot1x_authenticator_port_element).
        With -port_id: GET /dot1x/authenticator/<id>. Fields: is_authenticator_enabled, control (seen: DAPC_AUTO),
        unauthorized_vlan_id, authorized_vlan_id, client_limit, quiet_period, tx_period, supplicant_timeout,
        server_timeout, max_requests, reauth_period, logoff_period, unauth_period, cached_reauth_period.

        .EXAMPLE
        Get-ArubaSWDot1xAuthenticator

        .EXAMPLE
        Get-ArubaSWDot1xAuthenticator -port_id 21
    #>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]$port_id,
        [Parameter (Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$connection = (Get-ArubaSWDefaultConnection)
    )

    Begin {
    }

    Process {
        $p = @{ Path = 'dot1x/authenticator'; ElementName = 'dot1x_authenticator_port_element'; Connection = $connection }
        if ($PsBoundParameters.ContainsKey('port_id')) { $p['PortId'] = $port_id }
        Get-ArubaSWPortResource @p
    }

    End {
    }
}

function Set-ArubaSWDot1xAuthenticator {

    <#
        .SYNOPSIS
        Configure the 802.1X authenticator of a port.

        .DESCRIPTION
        Sends PUT /dot1x/authenticator/<port_id>. Only the parameters you pass change; the cmdlet reads the port first
        and sends the complete object. Verified on a 2540 (YC.16.11): -control accepts DAPC_AUTO, DAPC_AUTHORIZED and
        DAPC_UNAUTHORIZED (DAPC_FORCE_AUTHORIZED and DAPC_FORCE_UNAUTHORIZED are rejected: "Unsupported control type").
        The switch rejects Set-ArubaSWDot1xPortSecurity, Invoke-ArubaSWDot1xReauthenticate and similar actions for a port
        whose authenticator is not enabled ("Port 21 is not an authenticator").
        Accepts pipeline input by property name (port_id).

        .EXAMPLE
        Set-ArubaSWDot1xAuthenticator -port_id 21 -is_authenticator_enabled -client_limit 4

        .EXAMPLE
        Get-ArubaSWDot1xAuthenticator -port_id 21 | Set-ArubaSWDot1xAuthenticator -quiet_period 90
    #>

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    Param(
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$port_id,
        [Parameter(Mandatory = $false)]
        [switch]$is_authenticator_enabled,
        [Parameter(Mandatory = $false)]
        [ValidateSet('DAPC_AUTO', 'DAPC_AUTHORIZED', 'DAPC_UNAUTHORIZED')]
        [string]$control,
        [Parameter(Mandatory = $false)]
        [ValidateRange(0, 4094)]
        [int]$unauthorized_vlan_id,
        [Parameter(Mandatory = $false)]
        [ValidateRange(0, 4094)]
        [int]$authorized_vlan_id,
        [Parameter(Mandatory = $false)]
        [ValidateRange(0, 2147483647)]
        [int]$client_limit,
        [Parameter(Mandatory = $false)]
        [ValidateRange(0, 2147483647)]
        [int]$quiet_period,
        [Parameter(Mandatory = $false)]
        [ValidateRange(0, 2147483647)]
        [int]$tx_period,
        [Parameter(Mandatory = $false)]
        [ValidateRange(0, 2147483647)]
        [int]$supplicant_timeout,
        [Parameter(Mandatory = $false)]
        [ValidateRange(0, 2147483647)]
        [int]$server_timeout,
        [Parameter(Mandatory = $false)]
        [ValidateRange(0, 2147483647)]
        [int]$max_requests,
        [Parameter(Mandatory = $false)]
        [ValidateRange(0, 2147483647)]
        [int]$reauth_period,
        [Parameter(Mandatory = $false)]
        [ValidateRange(0, 2147483647)]
        [int]$logoff_period,
        [Parameter(Mandatory = $false)]
        [ValidateRange(0, 2147483647)]
        [int]$unauth_period,
        [Parameter(Mandatory = $false)]
        [ValidateRange(0, 2147483647)]
        [int]$cached_reauth_period,
        [Parameter (Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$connection = (Get-ArubaSWDefaultConnection)
    )

    Begin {
    }

    Process {
        $changes = @{}
        if ($PsBoundParameters.ContainsKey('is_authenticator_enabled')) { $changes['is_authenticator_enabled'] = [bool]$is_authenticator_enabled }
        foreach ($name in 'control', 'unauthorized_vlan_id', 'authorized_vlan_id', 'client_limit', 'quiet_period', 'tx_period', 'supplicant_timeout',
            'server_timeout', 'max_requests', 'reauth_period', 'logoff_period', 'unauth_period', 'cached_reauth_period') {
            if ($PsBoundParameters.ContainsKey($name)) { $changes[$name] = $PsBoundParameters[$name] }
        }

        $uri = "dot1x/authenticator/${port_id}"
        $body = Get-ArubaSWMergedBody -Uri $uri -Changes $changes -Connection $connection

        if ($PSCmdlet.ShouldProcess($port_id, 'Configure 802.1X authenticator')) {
            $response = Invoke-ArubaSWWebRequest -method "PUT" -body $body -uri $uri -connection $connection
            if ($response.content) {
                $response.content | ConvertFrom-Json
            }
        }
    }

    End {
    }
}

function Get-ArubaSWDot1xAuthenticatorStatus {

    <#
        .SYNOPSIS
        Get the 802.1X authenticator status of the ports.

        .DESCRIPTION
        Without -port_id: GET /dot1x/authenticator/status (list). With -port_id: GET /dot1x/authenticator/<id>/status.
        Fields: auths_or_guests, unauth_clients, untagged_vlan, tagged_vlans, port_cos, in_limit_percentage, radius_acl,
        cntrl_dir, port_mode.

        .EXAMPLE
        Get-ArubaSWDot1xAuthenticatorStatus -port_id 21
    #>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]$port_id,
        [Parameter (Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$connection = (Get-ArubaSWDefaultConnection)
    )

    Begin {
    }

    Process {
        $p = @{ Path = 'dot1x/authenticator'; Suffix = '/status'; ElementName = 'dot1x_authenticator_status_element'; Connection = $connection }
        if ($PsBoundParameters.ContainsKey('port_id')) { $p['PortId'] = $port_id }
        Get-ArubaSWPortResource @p
    }

    End {
    }
}

function Get-ArubaSWDot1xAuthenticatorStats {

    <#
        .SYNOPSIS
        Get the 802.1X authenticator frame counters of the ports.

        .DESCRIPTION
        Without -port_id: GET /dot1x/authenticator/stats (list). With -port_id: GET /dot1x/authenticator/<id>/stats.
        Fields: source_mac_address, tx_req_id, tx_req, rx_start, rx_logoff, rx_resp_id, rx_resp, rx_errors.

        .EXAMPLE
        Get-ArubaSWDot1xAuthenticatorStats -port_id 21
    #>

    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseSingularNouns", "")]
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]$port_id,
        [Parameter (Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$connection = (Get-ArubaSWDefaultConnection)
    )

    Begin {
    }

    Process {
        $p = @{ Path = 'dot1x/authenticator'; Suffix = '/stats'; ElementName = 'dot1x_authenticator_stats_element'; Connection = $connection }
        if ($PsBoundParameters.ContainsKey('port_id')) { $p['PortId'] = $port_id }
        Get-ArubaSWPortResource @p
    }

    End {
    }
}

function Get-ArubaSWDot1xAuthenticatorClientStats {

    <#
        .SYNOPSIS
        Get the clients seen by the 802.1X authenticator.

        .DESCRIPTION
        Without -port_id: GET /dot1x/authenticator/client_stats (list). With -port_id: GET /dot1x/authenticator/<id>/client_stats.
        Fields: client_name, mac_address, ip_address, client_status.

        .EXAMPLE
        Get-ArubaSWDot1xAuthenticatorClientStats
    #>

    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseSingularNouns", "")]
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]$port_id,
        [Parameter (Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$connection = (Get-ArubaSWDefaultConnection)
    )

    Begin {
    }

    Process {
        $p = @{ Path = 'dot1x/authenticator'; Suffix = '/client_stats'; ElementName = 'dot1x_authenticator_client_stats_element'; Connection = $connection }
        if ($PsBoundParameters.ContainsKey('port_id')) { $p['PortId'] = $port_id }
        Get-ArubaSWPortResource @p
    }

    End {
    }
}

function Get-ArubaSWDot1xAuthenticatorSessionCounters {

    <#
        .SYNOPSIS
        Get the 802.1X session counters of the ports.

        .DESCRIPTION
        Without -port_id: GET /dot1x/authenticator/session_counters (list). With -port_id: GET /dot1x/authenticator/<id>/session_counters.
        Fields: frames_in, frames_out, session_time, session_status, user.

        .EXAMPLE
        Get-ArubaSWDot1xAuthenticatorSessionCounters -port_id 21
    #>

    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseSingularNouns", "")]
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]$port_id,
        [Parameter (Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$connection = (Get-ArubaSWDefaultConnection)
    )

    Begin {
    }

    Process {
        $p = @{ Path = 'dot1x/authenticator'; Suffix = '/session_counters'; ElementName = 'dot1x_authenticator_session_counters_element'; Connection = $connection }
        if ($PsBoundParameters.ContainsKey('port_id')) { $p['PortId'] = $port_id }
        Get-ArubaSWPortResource @p
    }

    End {
    }
}

function Clear-ArubaSWDot1xAuthenticatorStats {

    <#
        .SYNOPSIS
        Clear the 802.1X authenticator counters of a port.

        .DESCRIPTION
        Sends POST /dot1x/authenticator/<port_id>/clearstats.

        .EXAMPLE
        Clear-ArubaSWDot1xAuthenticatorStats -port_id 21
    #>

    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseSingularNouns", "")]
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    Param(
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$port_id,
        [Parameter (Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$connection = (Get-ArubaSWDefaultConnection)
    )

    Begin {
    }

    Process {
        if ($PSCmdlet.ShouldProcess($port_id, 'Clear 802.1X authenticator statistics')) {
            $null = Invoke-ArubaSWWebRequest -method "POST" -uri "dot1x/authenticator/${port_id}/clearstats" -connection $connection
        }
    }

    End {
    }
}

function Initialize-ArubaSWDot1xAuthenticator {

    <#
        .SYNOPSIS
        Re-initialize the 802.1X authenticator of a port (clients must authenticate again).

        .DESCRIPTION
        Sends POST /dot1x/authenticator/<port_id>/initialize. Connected clients lose their authorization until they
        have authenticated again.

        .EXAMPLE
        Initialize-ArubaSWDot1xAuthenticator -port_id 21
    #>

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    Param(
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$port_id,
        [Parameter (Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$connection = (Get-ArubaSWDefaultConnection)
    )

    Begin {
    }

    Process {
        if ($PSCmdlet.ShouldProcess($port_id, 'Initialize 802.1X authenticator')) {
            $null = Invoke-ArubaSWWebRequest -method "POST" -uri "dot1x/authenticator/${port_id}/initialize" -connection $connection
        }
    }

    End {
    }
}

function Invoke-ArubaSWDot1xReauthenticate {

    <#
        .SYNOPSIS
        Trigger a new 802.1X authentication of the clients on a port.

        .DESCRIPTION
        Sends POST /dot1x/authenticator/<port_id>/reauthenticate.

        .EXAMPLE
        Invoke-ArubaSWDot1xReauthenticate -port_id 21
    #>

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    Param(
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$port_id,
        [Parameter (Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$connection = (Get-ArubaSWDefaultConnection)
    )

    Begin {
    }

    Process {
        if ($PSCmdlet.ShouldProcess($port_id, 'Reauthenticate 802.1X clients')) {
            $null = Invoke-ArubaSWWebRequest -method "POST" -uri "dot1x/authenticator/${port_id}/reauthenticate" -connection $connection
        }
    }

    End {
    }
}

function Get-ArubaSWDot1xPortSecurity {

    <#
        .SYNOPSIS
        Get the 802.1X port security settings of the ports.

        .DESCRIPTION
        Without -port_id: GET /dot1x/port_security (list). With -port_id: GET /dot1x/port_security/<id>.
        Fields: controlled_direction (seen: DCD_BOTH), allow_mbv, allowed_mixed_users, is_port_speed_vsa_enabled.

        .EXAMPLE
        Get-ArubaSWDot1xPortSecurity -port_id 21
    #>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]$port_id,
        [Parameter (Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$connection = (Get-ArubaSWDefaultConnection)
    )

    Begin {
    }

    Process {
        $p = @{ Path = 'dot1x/port_security'; ElementName = 'dot1x_port_security_element'; Connection = $connection }
        if ($PsBoundParameters.ContainsKey('port_id')) { $p['PortId'] = $port_id }
        Get-ArubaSWPortResource @p
    }

    End {
    }
}

function Set-ArubaSWDot1xPortSecurity {

    <#
        .SYNOPSIS
        Configure the 802.1X port security of a port.

        .DESCRIPTION
        Sends PUT /dot1x/port_security/<port_id>. Only the parameters you pass change.
        Verified on a 2540 (YC.16.11): -controlled_direction accepts DCD_BOTH and DCD_IN (DCD_OUT is rejected). The
        switch accepts the PUT only for a port with an enabled authentication ("Port 21 is not configured with any
        Authentication"), so enable the authenticator (Set-ArubaSWDot1xAuthenticator) first.

        .EXAMPLE
        Set-ArubaSWDot1xPortSecurity -port_id 21 -allow_mbv:$false
    #>

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    Param(
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$port_id,
        [Parameter(Mandatory = $false)]
        [ValidateSet('DCD_BOTH', 'DCD_IN')]
        [string]$controlled_direction,
        [Parameter(Mandatory = $false)]
        [switch]$allow_mbv,
        [Parameter(Mandatory = $false)]
        [switch]$allowed_mixed_users,
        [Parameter(Mandatory = $false)]
        [switch]$is_port_speed_vsa_enabled,
        [Parameter (Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$connection = (Get-ArubaSWDefaultConnection)
    )

    Begin {
    }

    Process {
        $changes = @{}
        if ($PsBoundParameters.ContainsKey('controlled_direction')) { $changes['controlled_direction'] = $controlled_direction }
        foreach ($name in 'allow_mbv', 'allowed_mixed_users', 'is_port_speed_vsa_enabled') {
            if ($PsBoundParameters.ContainsKey($name)) { $changes[$name] = [bool]$PsBoundParameters[$name] }
        }

        $uri = "dot1x/port_security/${port_id}"
        $body = Get-ArubaSWMergedBody -Uri $uri -Changes $changes -Connection $connection

        if ($PSCmdlet.ShouldProcess($port_id, 'Configure 802.1X port security')) {
            $response = Invoke-ArubaSWWebRequest -method "PUT" -body $body -uri $uri -connection $connection
            if ($response.content) {
                $response.content | ConvertFrom-Json
            }
        }
    }

    End {
    }
}

function Get-ArubaSWDot1xSupplicant {

    <#
        .SYNOPSIS
        Get the 802.1X supplicant configuration of the ports.

        .DESCRIPTION
        Without -port_id: GET /dot1x/supplicant (list). With -port_id: GET /dot1x/supplicant/<id>.
        Fields: is_supplicant_enabled, username, password (the switch returns it as a placeholder), supplicant_state,
        auth_timeout, held_period, start_period, max_start.

        .EXAMPLE
        Get-ArubaSWDot1xSupplicant -port_id 21
    #>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]$port_id,
        [Parameter (Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$connection = (Get-ArubaSWDefaultConnection)
    )

    Begin {
    }

    Process {
        $p = @{ Path = 'dot1x/supplicant'; ElementName = 'dot1x_supplicant_port_element'; Connection = $connection }
        if ($PsBoundParameters.ContainsKey('port_id')) { $p['PortId'] = $port_id }
        Get-ArubaSWPortResource @p
    }

    End {
    }
}

function Set-ArubaSWDot1xSupplicant {

    <#
        .SYNOPSIS
        Configure the 802.1X supplicant of a port.

        .DESCRIPTION
        Sends PUT /dot1x/supplicant/<port_id>. Only the parameters you pass change. The cmdlet reads the port first
        and sends the complete object, so the password the switch returns as a placeholder is NOT sent back unless
        you pass -password. -password is a SecureString.
        Verified on a 2540 (YC.16.11): enabling the supplicant needs a non-empty -username ("username is empty");
        Clear-/Initialize-ArubaSWDot1xSupplicant work only for a port with an enabled supplicant.

        .EXAMPLE
        Set-ArubaSWDot1xSupplicant -port_id 21 -is_supplicant_enabled -username host01 -password (Read-Host -AsSecureString)
    #>

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    Param(
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$port_id,
        [Parameter(Mandatory = $false)]
        [switch]$is_supplicant_enabled,
        [Parameter(Mandatory = $false)]
        [string]$username,
        [Parameter(Mandatory = $false)]
        [securestring]$password,
        [Parameter(Mandatory = $false)]
        [ValidateRange(0, 2147483647)]
        [int]$auth_timeout,
        [Parameter(Mandatory = $false)]
        [ValidateRange(0, 2147483647)]
        [int]$held_period,
        [Parameter(Mandatory = $false)]
        [ValidateRange(0, 2147483647)]
        [int]$start_period,
        [Parameter(Mandatory = $false)]
        [ValidateRange(0, 2147483647)]
        [int]$max_start,
        [Parameter (Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$connection = (Get-ArubaSWDefaultConnection)
    )

    Begin {
    }

    Process {
        $changes = @{}
        if ($PsBoundParameters.ContainsKey('is_supplicant_enabled')) { $changes['is_supplicant_enabled'] = [bool]$is_supplicant_enabled }
        if ($PsBoundParameters.ContainsKey('username')) { $changes['username'] = $username }
        if ($PsBoundParameters.ContainsKey('password')) { $changes['password'] = [System.Net.NetworkCredential]::new('', $password).Password }
        foreach ($name in 'auth_timeout', 'held_period', 'start_period', 'max_start') {
            if ($PsBoundParameters.ContainsKey($name)) { $changes[$name] = $PsBoundParameters[$name] }
        }

        $uri = "dot1x/supplicant/${port_id}"
        $body = Get-ArubaSWMergedBody -Uri $uri -Changes $changes -OmitUnlessChanged 'password' -Connection $connection

        if ($PSCmdlet.ShouldProcess($port_id, 'Configure 802.1X supplicant')) {
            $response = Invoke-ArubaSWWebRequest -method "PUT" -body $body -uri $uri -connection $connection
            if ($response.content) {
                $response.content | ConvertFrom-Json
            }
        }
    }

    End {
    }
}

function Get-ArubaSWDot1xSupplicantStats {

    <#
        .SYNOPSIS
        Get the 802.1X supplicant frame counters of the ports.

        .DESCRIPTION
        Without -port_id: GET /dot1x/supplicant/stats (list). With -port_id: GET /dot1x/supplicant/<id>/stats.
        Fields: source_mac_address, tx_start, tx_logoff, tx_resp_id, tx_resp, rx_req_id, rx_req, rx_errors.

        .EXAMPLE
        Get-ArubaSWDot1xSupplicantStats -port_id 21
    #>

    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseSingularNouns", "")]
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]$port_id,
        [Parameter (Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$connection = (Get-ArubaSWDefaultConnection)
    )

    Begin {
    }

    Process {
        $p = @{ Path = 'dot1x/supplicant'; Suffix = '/stats'; ElementName = 'dot1x_supplicant_stats_element'; Connection = $connection }
        if ($PsBoundParameters.ContainsKey('port_id')) { $p['PortId'] = $port_id }
        Get-ArubaSWPortResource @p
    }

    End {
    }
}

function Clear-ArubaSWDot1xSupplicantStats {

    <#
        .SYNOPSIS
        Clear the 802.1X supplicant counters of a port.

        .DESCRIPTION
        Sends POST /dot1x/supplicant/<port_id>/clearstats.

        .EXAMPLE
        Clear-ArubaSWDot1xSupplicantStats -port_id 21
    #>

    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseSingularNouns", "")]
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    Param(
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$port_id,
        [Parameter (Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$connection = (Get-ArubaSWDefaultConnection)
    )

    Begin {
    }

    Process {
        if ($PSCmdlet.ShouldProcess($port_id, 'Clear 802.1X supplicant statistics')) {
            $null = Invoke-ArubaSWWebRequest -method "POST" -uri "dot1x/supplicant/${port_id}/clearstats" -connection $connection
        }
    }

    End {
    }
}

function Initialize-ArubaSWDot1xSupplicant {

    <#
        .SYNOPSIS
        Re-initialize the 802.1X supplicant of a port.

        .DESCRIPTION
        Sends POST /dot1x/supplicant/<port_id>/initialize.

        .EXAMPLE
        Initialize-ArubaSWDot1xSupplicant -port_id 21
    #>

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    Param(
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$port_id,
        [Parameter (Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$connection = (Get-ArubaSWDefaultConnection)
    )

    Begin {
    }

    Process {
        if ($PSCmdlet.ShouldProcess($port_id, 'Initialize 802.1X supplicant')) {
            $null = Invoke-ArubaSWWebRequest -method "POST" -uri "dot1x/supplicant/${port_id}/initialize" -connection $connection
        }
    }

    End {
    }
}
