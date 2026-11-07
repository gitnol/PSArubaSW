#
# Copyright 2026, PowerArubaSW contributors
# SPDX-License-Identifier: Apache-2.0
#
# Authentifizierung, Accounting und Autorisierung (Inkrement I39). Felder und Verhalten stammen von einer 2540 (YC.16.11.0010), nicht aus der Spec.

function Get-ArubaSWAuthentication {

    <#
        .SYNOPSIS
        Get the global authentication settings.

        .DESCRIPTION
        Reads GET /authentication: is_privilege_mode_enabled.

        .EXAMPLE
        Get-ArubaSWAuthentication
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
        $response = Invoke-ArubaSWWebRequest -method "GET" -uri "authentication" -connection $connection
        $response.content | ConvertFrom-Json
    }

    End {
    }
}

function Set-ArubaSWAuthentication {

    <#
        .SYNOPSIS
        Configure the global authentication settings.

        .DESCRIPTION
        Sends PUT /authentication. -is_privilege_mode_enabled switches the privilege mode (verified on a 2540, YC.16.11).

        .EXAMPLE
        Set-ArubaSWAuthentication -is_privilege_mode_enabled
    #>

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    Param(
        [Parameter(Mandatory = $false)]
        [switch]$is_privilege_mode_enabled,
        [Parameter (Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$connection = (Get-ArubaSWDefaultConnection)
    )

    Begin {
    }

    Process {
        $changes = @{}
        if ($PsBoundParameters.ContainsKey('is_privilege_mode_enabled')) { $changes['is_privilege_mode_enabled'] = [bool]$is_privilege_mode_enabled }

        $uri = "authentication"
        $body = Get-ArubaSWMergedBody -Uri $uri -Changes $changes -Connection $connection

        if ($PSCmdlet.ShouldProcess('authentication', 'Configure the global authentication settings')) {
            $response = Invoke-ArubaSWWebRequest -method "PUT" -body $body -uri $uri -connection $connection
            if ($response.content) {
                $response.content | ConvertFrom-Json
            }
        }
    }

    End {
    }
}

function Get-ArubaSWAuthenticationConsole {

    <#
        .SYNOPSIS
        Get the authentication methods for console logins.

        .DESCRIPTION
        Reads GET /authentication/console: auth_console_login and auth_console_enable with primary_method, secondary_method and server_group.

        .EXAMPLE
        Get-ArubaSWAuthenticationConsole
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
        $response = Invoke-ArubaSWWebRequest -method "GET" -uri "authentication/console" -connection $connection
        $response.content | ConvertFrom-Json
    }

    End {
    }
}

function Set-ArubaSWAuthenticationConsole {

    <#
        .SYNOPSIS
        Configure the authentication methods for console logins.

        .DESCRIPTION
        Sends PUT /authentication/console. Only the parameters you pass change; the cmdlet reads the current settings first. Verified on a 2540 (YC.16.11): PAM_LOCAL with SAM_NONE is the default; PAM_RADIUS without a server group and SAM_LOCAL as secondary method after PAM_LOCAL are rejected ("Not legal combination of authentication methods"), an unknown name gives "Invalid value for primary_method". Methods other than PAM_LOCAL/SAM_NONE were not exercised with a working server. A wrong combination can lock you out of the console.

        .EXAMPLE
        Set-ArubaSWAuthenticationConsole -login_primary_method PAM_LOCAL -login_secondary_method SAM_NONE
    #>

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    Param(
        [Parameter(Mandatory = $false)]
        [string]$login_primary_method,
        [Parameter(Mandatory = $false)]
        [string]$login_secondary_method,
        [Parameter(Mandatory = $false)]
        [string]$login_server_group,
        [Parameter(Mandatory = $false)]
        [string]$enable_primary_method,
        [Parameter(Mandatory = $false)]
        [string]$enable_secondary_method,
        [Parameter(Mandatory = $false)]
        [string]$enable_server_group,
        [Parameter (Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$connection = (Get-ArubaSWDefaultConnection)
    )

    Begin {
    }

    Process {
        $uri = "authentication/console"
        $body = Get-ArubaSWMergedBody -Uri $uri -Changes @{} -Connection $connection
        foreach ($f in 'primary_method', 'secondary_method', 'server_group') {
            $p = 'login_' + $f
            if ($PsBoundParameters.ContainsKey($p)) { $body.auth_console_login.$f = $PsBoundParameters[$p] }
        }
        foreach ($f in 'primary_method', 'secondary_method', 'server_group') {
            $p = 'enable_' + $f
            if ($PsBoundParameters.ContainsKey($p)) { $body.auth_console_enable.$f = $PsBoundParameters[$p] }
        }

        if ($PSCmdlet.ShouldProcess('authentication/console', 'Configure the authentication methods for console logins')) {
            $response = Invoke-ArubaSWWebRequest -method "PUT" -body $body -uri $uri -connection $connection
            if ($response.content) {
                $response.content | ConvertFrom-Json
            }
        }
    }

    End {
    }
}

function Get-ArubaSWAuthenticationSsh {

    <#
        .SYNOPSIS
        Get the authentication methods for SSH logins.

        .DESCRIPTION
        Reads GET /authentication/ssh: auth_ssh_login and auth_ssh_enable plus is_client_certificate_enabled.

        .EXAMPLE
        Get-ArubaSWAuthenticationSsh
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
        $response = Invoke-ArubaSWWebRequest -method "GET" -uri "authentication/ssh" -connection $connection
        $response.content | ConvertFrom-Json
    }

    End {
    }
}

function Set-ArubaSWAuthenticationSsh {

    <#
        .SYNOPSIS
        Configure the authentication methods for SSH logins.

        .DESCRIPTION
        Sends PUT /authentication/ssh. Only the parameters you pass change; the cmdlet reads the current settings first. Verified on a 2540 (YC.16.11): -is_client_certificate_enabled switches on and off; the rules for the methods are the same as for Set-ArubaSWAuthenticationConsole. A wrong combination can lock you out of SSH.

        .EXAMPLE
        Set-ArubaSWAuthenticationSsh -is_client_certificate_enabled
    #>

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    Param(
        [Parameter(Mandatory = $false)]
        [string]$login_primary_method,
        [Parameter(Mandatory = $false)]
        [string]$login_secondary_method,
        [Parameter(Mandatory = $false)]
        [string]$login_server_group,
        [Parameter(Mandatory = $false)]
        [string]$enable_primary_method,
        [Parameter(Mandatory = $false)]
        [string]$enable_secondary_method,
        [Parameter(Mandatory = $false)]
        [string]$enable_server_group,
        [Parameter(Mandatory = $false)]
        [switch]$is_client_certificate_enabled,
        [Parameter (Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$connection = (Get-ArubaSWDefaultConnection)
    )

    Begin {
    }

    Process {
        $uri = "authentication/ssh"
        $body = Get-ArubaSWMergedBody -Uri $uri -Changes @{} -Connection $connection
        foreach ($f in 'primary_method', 'secondary_method', 'server_group') {
            $p = 'login_' + $f
            if ($PsBoundParameters.ContainsKey($p)) { $body.auth_ssh_login.$f = $PsBoundParameters[$p] }
        }
        foreach ($f in 'primary_method', 'secondary_method', 'server_group') {
            $p = 'enable_' + $f
            if ($PsBoundParameters.ContainsKey($p)) { $body.auth_ssh_enable.$f = $PsBoundParameters[$p] }
        }
        if ($PsBoundParameters.ContainsKey('is_client_certificate_enabled')) { $body.is_client_certificate_enabled = [bool]$is_client_certificate_enabled }

        if ($PSCmdlet.ShouldProcess('authentication/ssh', 'Configure the authentication methods for SSH logins')) {
            $response = Invoke-ArubaSWWebRequest -method "PUT" -body $body -uri $uri -connection $connection
            if ($response.content) {
                $response.content | ConvertFrom-Json
            }
        }
    }

    End {
    }
}

function Get-ArubaSWAccounting {

    <#
        .SYNOPSIS
        Get the accounting configuration.

        .DESCRIPTION
        Reads GET /accounting: session_id, update_interval, is_supress_null_user and the groups accounting_exec, accounting_system, accounting_rest, accounting_network, accounting_commands (accounting_method, accounting_mode, server_group).

        .EXAMPLE
        Get-ArubaSWAccounting
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
        $response = Invoke-ArubaSWWebRequest -method "GET" -uri "accounting" -connection $connection
        $response.content | ConvertFrom-Json
    }

    End {
    }
}

function Set-ArubaSWAccounting {

    <#
        .SYNOPSIS
        Configure accounting.

        .DESCRIPTION
        Sends PUT /accounting. Only the parameters you pass change. Parameters are <group>_accounting_method, <group>_accounting_mode and <group>_server_group for the groups exec, system, rest, network and commands. Verified on a 2540 (YC.16.11): accounting_method AME_NONE, AME_RADIUS, AME_TACACS; accounting_mode AMO_NONE, AMO_START_STOP, AMO_STOP_ONLY; session_id ASI_UNIQUE (ASI_BOGUS is rejected); the switch accepts a method without a server group. Nothing was checked against a working RADIUS or TACACS server.

        .EXAMPLE
        Set-ArubaSWAccounting -exec_accounting_method AME_RADIUS -exec_accounting_mode AMO_START_STOP
    #>

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    Param(
        [Parameter(Mandatory = $false)]
        [string]$exec_accounting_method,
        [Parameter(Mandatory = $false)]
        [string]$exec_accounting_mode,
        [Parameter(Mandatory = $false)]
        [string]$exec_server_group,
        [Parameter(Mandatory = $false)]
        [string]$system_accounting_method,
        [Parameter(Mandatory = $false)]
        [string]$system_accounting_mode,
        [Parameter(Mandatory = $false)]
        [string]$system_server_group,
        [Parameter(Mandatory = $false)]
        [string]$rest_accounting_method,
        [Parameter(Mandatory = $false)]
        [string]$rest_accounting_mode,
        [Parameter(Mandatory = $false)]
        [string]$rest_server_group,
        [Parameter(Mandatory = $false)]
        [string]$network_accounting_method,
        [Parameter(Mandatory = $false)]
        [string]$network_accounting_mode,
        [Parameter(Mandatory = $false)]
        [string]$network_server_group,
        [Parameter(Mandatory = $false)]
        [string]$commands_accounting_method,
        [Parameter(Mandatory = $false)]
        [string]$commands_accounting_mode,
        [Parameter(Mandatory = $false)]
        [string]$commands_server_group,
        [Parameter(Mandatory = $false)]
        [switch]$is_supress_null_user,
        [Parameter(Mandatory = $false)]
        [string]$session_id,
        [Parameter(Mandatory = $false)]
        [ValidateRange(0, 2147483647)]
        [int]$update_interval,
        [Parameter (Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$connection = (Get-ArubaSWDefaultConnection)
    )

    Begin {
    }

    Process {
        $uri = "accounting"
        $body = Get-ArubaSWMergedBody -Uri $uri -Changes @{} -Connection $connection
        foreach ($f in 'accounting_method', 'accounting_mode', 'server_group') {
            $p = 'exec_' + $f
            if ($PsBoundParameters.ContainsKey($p)) { $body.accounting_exec.$f = $PsBoundParameters[$p] }
        }
        foreach ($f in 'accounting_method', 'accounting_mode', 'server_group') {
            $p = 'system_' + $f
            if ($PsBoundParameters.ContainsKey($p)) { $body.accounting_system.$f = $PsBoundParameters[$p] }
        }
        foreach ($f in 'accounting_method', 'accounting_mode', 'server_group') {
            $p = 'rest_' + $f
            if ($PsBoundParameters.ContainsKey($p)) { $body.accounting_rest.$f = $PsBoundParameters[$p] }
        }
        foreach ($f in 'accounting_method', 'accounting_mode', 'server_group') {
            $p = 'network_' + $f
            if ($PsBoundParameters.ContainsKey($p)) { $body.accounting_network.$f = $PsBoundParameters[$p] }
        }
        foreach ($f in 'accounting_method', 'accounting_mode', 'server_group') {
            $p = 'commands_' + $f
            if ($PsBoundParameters.ContainsKey($p)) { $body.accounting_commands.$f = $PsBoundParameters[$p] }
        }
        if ($PsBoundParameters.ContainsKey('is_supress_null_user')) { $body.is_supress_null_user = [bool]$is_supress_null_user }
        if ($PsBoundParameters.ContainsKey('session_id')) { $body.session_id = $session_id }
        if ($PsBoundParameters.ContainsKey('update_interval')) { $body.update_interval = $update_interval }

        if ($PSCmdlet.ShouldProcess('accounting', 'Configure accounting')) {
            $response = Invoke-ArubaSWWebRequest -method "PUT" -body $body -uri $uri -connection $connection
            if ($response.content) {
                $response.content | ConvertFrom-Json
            }
        }
    }

    End {
    }
}

function Get-ArubaSWAuthorization {

    <#
        .SYNOPSIS
        Get the authorization settings.

        .DESCRIPTION
        Reads GET /authorization: access_level, authorization_method, autz_uri_level, autz_uri_method.

        .EXAMPLE
        Get-ArubaSWAuthorization
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
        $response = Invoke-ArubaSWWebRequest -method "GET" -uri "authorization" -connection $connection
        $response.content | ConvertFrom-Json
    }

    End {
    }
}

function Set-ArubaSWAuthorization {

    <#
        .SYNOPSIS
        Configure authorization.

        .DESCRIPTION
        Sends PUT /authorization. Verified on a 2540 (YC.16.11): authorization_method AZM_NONE and AZM_RADIUS are accepted, other names give "Invalid value or unsupported option"; access_level and autz_uri_level are AZL_ALL by default.

        .EXAMPLE
        Set-ArubaSWAuthorization -authorization_method AZM_NONE
    #>

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    Param(
        [Parameter(Mandatory = $false)]
        [string]$access_level,
        [Parameter(Mandatory = $false)]
        [string]$authorization_method,
        [Parameter(Mandatory = $false)]
        [string]$autz_uri_level,
        [Parameter(Mandatory = $false)]
        [string]$autz_uri_method,
        [Parameter (Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$connection = (Get-ArubaSWDefaultConnection)
    )

    Begin {
    }

    Process {
        $changes = @{}
        foreach ($name in 'access_level', 'authorization_method', 'autz_uri_level', 'autz_uri_method') {
            if ($PsBoundParameters.ContainsKey($name)) { $changes[$name] = $PsBoundParameters[$name] }
        }

        $uri = "authorization"
        $body = Get-ArubaSWMergedBody -Uri $uri -Changes $changes -Connection $connection

        if ($PSCmdlet.ShouldProcess('authorization', 'Configure authorization')) {
            $response = Invoke-ArubaSWWebRequest -method "PUT" -body $body -uri $uri -connection $connection
            if ($response.content) {
                $response.content | ConvertFrom-Json
            }
        }
    }

    End {
    }
}

