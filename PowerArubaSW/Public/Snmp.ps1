#
# Copyright 2026, PowerArubaSW contributors
# SPDX-License-Identifier: Apache-2.0
#
# SNMP v1/v2c: Public/Snmp.ps1 (Inkrement I37). Felder, Werte und Verhalten stammen von einer 2540 (YC.16.11.0010), nicht aus der Spec.

function Get-ArubaSWSnmp {

    <#
        .SYNOPSIS
        Get the SNMP server configuration.

        .DESCRIPTION
        Reads GET /snmp-server: is_snmp_server_enabled, local_engine_id.

        .EXAMPLE
        Get-ArubaSWSnmp
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
        $response = Invoke-ArubaSWWebRequest -method "GET" -uri "snmp-server" -connection $connection
        $response.content | ConvertFrom-Json
    }

    End {
    }
}

function Set-ArubaSWSnmp {

    <#
        .SYNOPSIS
        Enable or disable the SNMP server.

        .DESCRIPTION
        Sends PUT /snmp-server. -is_snmp_server_enabled:$false switches SNMP off, monitoring systems then lose the switch.

        .EXAMPLE
        Set-ArubaSWSnmp -is_snmp_server_enabled
    #>

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    Param(
        [Parameter(Mandatory = $false)]
        [switch]$is_snmp_server_enabled,
        [Parameter (Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$connection = (Get-ArubaSWDefaultConnection)
    )

    Begin {
    }

    Process {
        $uri = "snmp-server"
        $changes = @{}
        if ($PsBoundParameters.ContainsKey('is_snmp_server_enabled')) { $changes['is_snmp_server_enabled'] = [bool]$is_snmp_server_enabled }
        $body = [pscustomobject]$changes

        if ($PSCmdlet.ShouldProcess($connection.server, 'Configure Enable or disable the SNMP server.')) {
            $response = Invoke-ArubaSWWebRequest -method "PUT" -body $body -uri $uri -connection $connection
            if ($response.content) {
                $response.content | ConvertFrom-Json
            }
        }
    }

    End {
    }
}

function Get-ArubaSWSnmpCommunity {

    <#
        .SYNOPSIS
        Get SNMP communities.

        .DESCRIPTION
        Without -community_name: GET /snmp-server/communities (list). With it: GET /snmp-server/communities/<name>.
        Fields: community_name, access_type (UT_MANAGER or UT_OPERATOR), restricted.

        .EXAMPLE
        Get-ArubaSWSnmpCommunity

        .EXAMPLE
        Get-ArubaSWSnmpCommunity -community_name public
    #>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $false)]
        [string]$community_name,
        [Parameter (Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$connection = (Get-ArubaSWDefaultConnection)
    )

    Begin {
    }

    Process {
        $p = @{ Path = 'snmp-server/communities'; ElementName = 'snmp_server_community_element'; Connection = $connection }
        if ($PsBoundParameters.ContainsKey('community_name')) { $p['PortId'] = $community_name }
        Get-ArubaSWPortResource @p
    }

    End {
    }
}

function Add-ArubaSWSnmpCommunity {

    <#
        .SYNOPSIS
        Add SNMP community.

        .DESCRIPTION
        Sends POST /snmp-server/communities. -access_type takes UT_MANAGER or UT_OPERATOR (verified on a 2540).
        The community name works like a password, so choose it accordingly.
        Without -restricted the switch creates the community with restricted = true (seen on a 2540); pass -restricted:$false for an unrestricted one.

        .EXAMPLE
        Add-ArubaSWSnmpCommunity -community_name monitor -access_type UT_OPERATOR -restricted:$false
    #>

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    Param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$community_name,
        [Parameter(Mandatory = $true)]
        [ValidateSet('UT_MANAGER', 'UT_OPERATOR')]
        [string]$access_type,
        [Parameter(Mandatory = $false)]
        [switch]$restricted,
        [Parameter (Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$connection = (Get-ArubaSWDefaultConnection)
    )

    Begin {
    }

    Process {
        $uri = "snmp-server/communities"
        $changes = @{}
        if ($PsBoundParameters.ContainsKey('community_name')) { $changes['community_name'] = $community_name }
        if ($PsBoundParameters.ContainsKey('access_type')) { $changes['access_type'] = $access_type }
        if ($PsBoundParameters.ContainsKey('restricted')) { $changes['restricted'] = [bool]$restricted }

        if ($PSCmdlet.ShouldProcess($community_name, 'Add SNMP community')) {
            $response = Invoke-ArubaSWWebRequest -method "POST" -body ([pscustomobject]$changes) -uri $uri -connection $connection
            $response.content | ConvertFrom-Json
        }
    }

    End {
    }
}

function Set-ArubaSWSnmpCommunity {

    <#
        .SYNOPSIS
        Configure SNMP community.

        .DESCRIPTION
        Sends PUT /snmp-server/communities/<name>. The switch accepts only the complete object, so the cmdlet reads
        the community first; fields you do not pass keep their value.

        .EXAMPLE
        Set-ArubaSWSnmpCommunity -community_name monitor -restricted
    #>

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    Param(
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$community_name,
        [Parameter(Mandatory = $false)]
        [ValidateSet('UT_MANAGER', 'UT_OPERATOR')]
        [string]$access_type,
        [Parameter(Mandatory = $false)]
        [switch]$restricted,
        [Parameter (Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$connection = (Get-ArubaSWDefaultConnection)
    )

    Begin {
    }

    Process {
        $uri = "snmp-server/communities/${community_name}"
        $changes = @{}
        if ($PsBoundParameters.ContainsKey('access_type')) { $changes['access_type'] = $access_type }
        if ($PsBoundParameters.ContainsKey('restricted')) { $changes['restricted'] = [bool]$restricted }
        $body = Get-ArubaSWMergedBody -Uri $uri -Changes $changes -Connection $connection

        if ($PSCmdlet.ShouldProcess($community_name, 'Configure SNMP community')) {
            $response = Invoke-ArubaSWWebRequest -method "PUT" -body $body -uri $uri -connection $connection
            if ($response.content) {
                $response.content | ConvertFrom-Json
            }
        }
    }

    End {
    }
}

function Remove-ArubaSWSnmpCommunity {

    <#
        .SYNOPSIS
        Remove SNMP community.

        .DESCRIPTION
        Sends DELETE /snmp-server/communities/<name>.

        .EXAMPLE
        Get-ArubaSWSnmpCommunity -community_name monitor | Remove-ArubaSWSnmpCommunity
    #>

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    Param(
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$community_name,
        [Parameter (Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$connection = (Get-ArubaSWDefaultConnection)
    )

    Begin {
    }

    Process {
        $uri = "snmp-server/communities/${community_name}"

        if ($PSCmdlet.ShouldProcess($community_name, 'Remove SNMP community')) {
            $null = Invoke-ArubaSWWebRequest -method "DELETE" -uri $uri -connection $connection
        }
    }

    End {
    }
}

function Get-ArubaSWSnmpHost {

    <#
        .SYNOPSIS
        Get SNMP trap hosts.

        .DESCRIPTION
        Without parameters: GET /snmp-server/hosts (list). With -host_ip and -community: GET /snmp-server/hosts/<ip>-<community>.
        Fields: host_ip, community, trap_level, informs, inform_retries, inform_timeout, use_oobm.

        .EXAMPLE
        Get-ArubaSWSnmpHost

        .EXAMPLE
        Get-ArubaSWSnmpHost -host_ip 192.0.2.10 -community monitor
    #>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $false)]
        [ipaddress]$host_ip,
        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]$community,
        [Parameter (Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$connection = (Get-ArubaSWDefaultConnection)
    )

    Begin {
    }

    Process {
        if ($PsBoundParameters.ContainsKey('host_ip') -ne $PsBoundParameters.ContainsKey('community')) {
            throw "Use -host_ip and -community together."
        }
        $p = @{ Path = 'snmp-server/hosts'; ElementName = 'snmp_server_host_element'; Connection = $connection }
        if ($PsBoundParameters.ContainsKey('host_ip')) { $p['PortId'] = "$($host_ip.ToString())-$community" }
        Get-ArubaSWPortResource @p
    }

    End {
    }
}

function Add-ArubaSWSnmpHost {

    <#
        .SYNOPSIS
        Add SNMP trap host.

        .DESCRIPTION
        Sends POST /snmp-server/hosts. Defaults of the switch: trap_level STL_NONE, informs off, inform_retries 3, inform_timeout 15.
        Verified -trap_level values on a 2540: STL_NONE, STL_ALL, STL_CRITICAL, STL_DEBUG (STL_NOT_CRITICAL is rejected); other names are passed on unchanged.
        The switch also creates a matching SNMPv3 parameter and target address for the host and removes them again with the host.

        .EXAMPLE
        Add-ArubaSWSnmpHost -host_ip 192.0.2.10 -community monitor -trap_level STL_CRITICAL
    #>

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    Param(
        [Parameter(Mandatory = $true)]
        [ipaddress]$host_ip,
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$community,
        [Parameter(Mandatory = $false)]
        [string]$trap_level,
        [Parameter(Mandatory = $false)]
        [switch]$informs,
        [Parameter(Mandatory = $false)]
        [ValidateRange(0, 100)]
        [int]$inform_retries,
        [Parameter(Mandatory = $false)]
        [ValidateRange(0, 3600)]
        [int]$inform_timeout,
        [Parameter(Mandatory = $false)]
        [switch]$use_oobm,
        [Parameter (Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$connection = (Get-ArubaSWDefaultConnection)
    )

    Begin {
    }

    Process {
        $uri = "snmp-server/hosts"
        $changes = @{}
        if ($PsBoundParameters.ContainsKey('host_ip')) { $changes['host_ip'] = [pscustomobject]@{ version = 'IAV_IP_V4'; octets = $host_ip.ToString() } }
        if ($PsBoundParameters.ContainsKey('community')) { $changes['community'] = $community }
        if ($PsBoundParameters.ContainsKey('trap_level')) { $changes['trap_level'] = $trap_level }
        if ($PsBoundParameters.ContainsKey('informs')) { $changes['informs'] = [bool]$informs }
        if ($PsBoundParameters.ContainsKey('inform_retries')) { $changes['inform_retries'] = $inform_retries }
        if ($PsBoundParameters.ContainsKey('inform_timeout')) { $changes['inform_timeout'] = $inform_timeout }
        if ($PsBoundParameters.ContainsKey('use_oobm')) { $changes['use_oobm'] = [bool]$use_oobm }

        if ($PSCmdlet.ShouldProcess($host_ip, 'Add SNMP trap host')) {
            $response = Invoke-ArubaSWWebRequest -method "POST" -body ([pscustomobject]$changes) -uri $uri -connection $connection
            $response.content | ConvertFrom-Json
        }
    }

    End {
    }
}

function Set-ArubaSWSnmpHost {

    <#
        .SYNOPSIS
        Configure an SNMP trap host.

        .DESCRIPTION
        Sends PUT /snmp-server/hosts/<ip>-<community> with the complete object (the cmdlet reads the host first; fields you do not pass keep their value).
        Pass the host by -host_ip and -community or as an object from Get-ArubaSWSnmpHost.

        .EXAMPLE
        Set-ArubaSWSnmpHost -host_ip 192.0.2.10 -community monitor -trap_level STL_ALL

        .EXAMPLE
        Get-ArubaSWSnmpHost | Set-ArubaSWSnmpHost -informs
    #>

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium', DefaultParameterSetName = 'address')]
    Param(
        [Parameter(Mandatory = $true, ParameterSetName = 'address')]
        [ipaddress]$host_ip,
        [Parameter(Mandatory = $true, ParameterSetName = 'address')]
        [ValidateNotNullOrEmpty()]
        [string]$community,
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ParameterSetName = 'object')]
        [PSObject]$snmp_host,
        [Parameter(Mandatory = $false)]
        [string]$trap_level,
        [Parameter(Mandatory = $false)]
        [switch]$informs,
        [Parameter(Mandatory = $false)]
        [ValidateRange(0, 100)]
        [int]$inform_retries,
        [Parameter(Mandatory = $false)]
        [ValidateRange(0, 3600)]
        [int]$inform_timeout,
        [Parameter(Mandatory = $false)]
        [switch]$use_oobm,
        [Parameter (Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$connection = (Get-ArubaSWDefaultConnection)
    )

    Begin {
    }

    Process {
        if ($PSCmdlet.ParameterSetName -eq 'object') {
            $ip = $snmp_host.host_ip.octets
            $comm = $snmp_host.community
        }
        else {
            $ip = $host_ip.ToString()
            $comm = $community
        }
        $uri = "snmp-server/hosts/${ip}-${comm}"
        $changes = @{}
        if ($PsBoundParameters.ContainsKey('trap_level')) { $changes['trap_level'] = $trap_level }
        if ($PsBoundParameters.ContainsKey('informs')) { $changes['informs'] = [bool]$informs }
        if ($PsBoundParameters.ContainsKey('inform_retries')) { $changes['inform_retries'] = $inform_retries }
        if ($PsBoundParameters.ContainsKey('inform_timeout')) { $changes['inform_timeout'] = $inform_timeout }
        if ($PsBoundParameters.ContainsKey('use_oobm')) { $changes['use_oobm'] = [bool]$use_oobm }
        $body = Get-ArubaSWMergedBody -Uri $uri -Changes $changes -Connection $connection

        if ($PSCmdlet.ShouldProcess("$ip-$comm", 'Configure SNMP trap host')) {
            $response = Invoke-ArubaSWWebRequest -method "PUT" -body $body -uri $uri -connection $connection
            if ($response.content) {
                $response.content | ConvertFrom-Json
            }
        }
    }

    End {
    }
}

function Remove-ArubaSWSnmpHost {

    <#
        .SYNOPSIS
        Remove an SNMP trap host.

        .DESCRIPTION
        Sends DELETE /snmp-server/hosts/<ip>-<community>.

        .EXAMPLE
        Remove-ArubaSWSnmpHost -host_ip 192.0.2.10 -community monitor

        .EXAMPLE
        Get-ArubaSWSnmpHost | Remove-ArubaSWSnmpHost
    #>

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High', DefaultParameterSetName = 'address')]
    Param(
        [Parameter(Mandatory = $true, ParameterSetName = 'address')]
        [ipaddress]$host_ip,
        [Parameter(Mandatory = $true, ParameterSetName = 'address')]
        [ValidateNotNullOrEmpty()]
        [string]$community,
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ParameterSetName = 'object')]
        [PSObject]$snmp_host,
        [Parameter (Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$connection = (Get-ArubaSWDefaultConnection)
    )

    Begin {
    }

    Process {
        if ($PSCmdlet.ParameterSetName -eq 'object') {
            $ip = $snmp_host.host_ip.octets
            $comm = $snmp_host.community
        }
        else {
            $ip = $host_ip.ToString()
            $comm = $community
        }

        if ($PSCmdlet.ShouldProcess("$ip-$comm", 'Remove SNMP trap host')) {
            $null = Invoke-ArubaSWWebRequest -method "DELETE" -uri "snmp-server/hosts/${ip}-${comm}" -connection $connection
        }
    }

    End {
    }
}

function Get-ArubaSWSnmpMib {

    <#
        .SYNOPSIS
        Get the SNMP MIB settings.

        .DESCRIPTION
        Reads GET /snmp-server/mib (seen: hpSwitchAuthMIB = SMT_INCLUDED).

        .EXAMPLE
        Get-ArubaSWSnmpMib
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
        $response = Invoke-ArubaSWWebRequest -method "GET" -uri "snmp-server/mib" -connection $connection
        $response.content | ConvertFrom-Json
    }

    End {
    }
}

function Set-ArubaSWSnmpMib {

    <#
        .SYNOPSIS
        Configure the SNMP MIB settings.

        .DESCRIPTION
        Sends PUT /snmp-server/mib. -hpSwitchAuthMIB takes the value as Get-ArubaSWSnmpMib returns it (SMT_INCLUDED).

        .EXAMPLE
        Set-ArubaSWSnmpMib -hpSwitchAuthMIB SMT_INCLUDED
    #>

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    Param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$hpSwitchAuthMIB,
        [Parameter (Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$connection = (Get-ArubaSWDefaultConnection)
    )

    Begin {
    }

    Process {
        $uri = "snmp-server/mib"
        $changes = @{}
        if ($PsBoundParameters.ContainsKey('hpSwitchAuthMIB')) { $changes['hpSwitchAuthMIB'] = $hpSwitchAuthMIB }
        $body = [pscustomobject]$changes

        if ($PSCmdlet.ShouldProcess($connection.server, 'Configure Configure the SNMP MIB settings.')) {
            $response = Invoke-ArubaSWWebRequest -method "PUT" -body $body -uri $uri -connection $connection
            if ($response.content) {
                $response.content | ConvertFrom-Json
            }
        }
    }

    End {
    }
}

function Get-ArubaSWSnmpResponseSource {

    <#
        .SYNOPSIS
        Get the source address policy for SNMP responses.

        .DESCRIPTION
        Reads GET /snmp-server/response-source: rs_ip_policy, loopback_interface, ip_addr.

        .EXAMPLE
        Get-ArubaSWSnmpResponseSource
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
        $response = Invoke-ArubaSWWebRequest -method "GET" -uri "snmp-server/response-source" -connection $connection
        $response.content | ConvertFrom-Json
    }

    End {
    }
}

function Set-ArubaSWSnmpResponseSource {

    <#
        .SYNOPSIS
        Set the source address policy for SNMP responses.

        .DESCRIPTION
        Sends PUT /snmp-server/response-source with only the fields you pass (verified on a 2540).
        -rs_ip_policy: RSIP_DEFAULT and RSIP_LOOPBACK were accepted; the loopback interface is then -loopback_interface.
        The switch ignores -ip_addr for these policies (it returns null).

        .EXAMPLE
        Set-ArubaSWSnmpResponseSource -rs_ip_policy RSIP_DEFAULT

        .EXAMPLE
        Set-ArubaSWSnmpResponseSource -rs_ip_policy RSIP_LOOPBACK -loopback_interface 1
    #>

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    Param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('RSIP_DEFAULT', 'RSIP_LOOPBACK')]
        [string]$rs_ip_policy,
        [Parameter(Mandatory = $false)]
        [ValidateRange(0, 7)]
        [int]$loopback_interface,
        [Parameter(Mandatory = $false)]
        [ipaddress]$ip_addr,
        [Parameter (Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$connection = (Get-ArubaSWDefaultConnection)
    )

    Begin {
    }

    Process {
        $uri = "snmp-server/response-source"
        $changes = @{}
        if ($PsBoundParameters.ContainsKey('rs_ip_policy')) { $changes['rs_ip_policy'] = $rs_ip_policy }
        if ($PsBoundParameters.ContainsKey('loopback_interface')) { $changes['loopback_interface'] = $loopback_interface }
        if ($PsBoundParameters.ContainsKey('ip_addr')) { $changes['ip_addr'] = [pscustomobject]@{ version = 'IAV_IP_V4'; octets = $ip_addr.ToString() } }
        $body = [pscustomobject]$changes

        if ($PSCmdlet.ShouldProcess($connection.server, 'Configure Set the source address policy for SNMP responses.')) {
            $response = Invoke-ArubaSWWebRequest -method "PUT" -body $body -uri $uri -connection $connection
            if ($response.content) {
                $response.content | ConvertFrom-Json
            }
        }
    }

    End {
    }
}

function Get-ArubaSWSnmpTrapSource {

    <#
        .SYNOPSIS
        Get the source address policy for SNMP traps.

        .DESCRIPTION
        Reads GET /snmp-server/trap-source: ts_ip_policy, loopback_interface, ip_addr.

        .EXAMPLE
        Get-ArubaSWSnmpTrapSource
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
        $response = Invoke-ArubaSWWebRequest -method "GET" -uri "snmp-server/trap-source" -connection $connection
        $response.content | ConvertFrom-Json
    }

    End {
    }
}

function Set-ArubaSWSnmpTrapSource {

    <#
        .SYNOPSIS
        Set the source address policy for SNMP traps.

        .DESCRIPTION
        Sends PUT /snmp-server/trap-source with only the fields you pass. -ts_ip_policy takes the value as Get-ArubaSWSnmpTrapSource returns it (seen: TSIP_DEFAULT; unknown names are rejected by the switch).

        .EXAMPLE
        Set-ArubaSWSnmpTrapSource -ts_ip_policy TSIP_DEFAULT
    #>

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    Param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ts_ip_policy,
        [Parameter(Mandatory = $false)]
        [ValidateRange(0, 7)]
        [int]$loopback_interface,
        [Parameter(Mandatory = $false)]
        [ipaddress]$ip_addr,
        [Parameter (Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$connection = (Get-ArubaSWDefaultConnection)
    )

    Begin {
    }

    Process {
        $uri = "snmp-server/trap-source"
        $changes = @{}
        if ($PsBoundParameters.ContainsKey('ts_ip_policy')) { $changes['ts_ip_policy'] = $ts_ip_policy }
        if ($PsBoundParameters.ContainsKey('loopback_interface')) { $changes['loopback_interface'] = $loopback_interface }
        if ($PsBoundParameters.ContainsKey('ip_addr')) { $changes['ip_addr'] = [pscustomobject]@{ version = 'IAV_IP_V4'; octets = $ip_addr.ToString() } }
        $body = [pscustomobject]$changes

        if ($PSCmdlet.ShouldProcess($connection.server, 'Configure Set the source address policy for SNMP traps.')) {
            $response = Invoke-ArubaSWWebRequest -method "PUT" -body $body -uri $uri -connection $connection
            if ($response.content) {
                $response.content | ConvertFrom-Json
            }
        }
    }

    End {
    }
}

function Get-ArubaSWSnmpTrap {

    <#
        .SYNOPSIS
        Get the SNMP trap settings.

        .DESCRIPTION
        Reads GET /snmp-server/traps: one STM_ENABLE/STM_DISABLE value per trap type, snmp_authentication (seen: SATM_EXTENDED),
        mac_notify and running_config_changes (nested objects).

        .EXAMPLE
        Get-ArubaSWSnmpTrap
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
        $response = Invoke-ArubaSWWebRequest -method "GET" -uri "snmp-server/traps" -connection $connection
        $response.content | ConvertFrom-Json
    }

    End {
    }
}

function Set-ArubaSWSnmpTrap {

    <#
        .SYNOPSIS
        Configure the SNMP trap settings.

        .DESCRIPTION
        Sends PUT /snmp-server/traps with the complete object (the cmdlet reads it first; fields you do not pass keep their value).
        Trap types take STM_ENABLE or STM_DISABLE. -mac_notify and -running_config_changes take the nested object as Get-ArubaSWSnmpTrap returns it.

        .EXAMPLE
        Set-ArubaSWSnmpTrap -startup_config_change STM_ENABLE
    #>

    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingPlainTextForPassword", "password_change_mgr", Justification = "password_change_mgr is the name of an SNMP trap type (STM_ENABLE/STM_DISABLE), not a secret.")]
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    Param(
        [Parameter(Mandatory = $false)]
        [ValidateSet('STM_ENABLE', 'STM_DISABLE')]
        [string]$arp_protect,
        [Parameter(Mandatory = $false)]
        [ValidateSet('STM_ENABLE', 'STM_DISABLE')]
        [string]$auth_server_fail,
        [Parameter(Mandatory = $false)]
        [ValidateSet('STM_ENABLE', 'STM_DISABLE')]
        [string]$dhcp_server,
        [Parameter(Mandatory = $false)]
        [ValidateSet('STM_ENABLE', 'STM_DISABLE')]
        [string]$dhcp_snooping,
        [Parameter(Mandatory = $false)]
        [ValidateSet('STM_ENABLE', 'STM_DISABLE')]
        [string]$dhcpv6_snooping_errant_replies,
        [Parameter(Mandatory = $false)]
        [ValidateSet('STM_ENABLE', 'STM_DISABLE')]
        [string]$dhcpv6_snooping_out_of_resource,
        [Parameter(Mandatory = $false)]
        [ValidateSet('STM_ENABLE', 'STM_DISABLE')]
        [string]$dyn_ip_lockdown,
        [Parameter(Mandatory = $false)]
        [ValidateSet('STM_ENABLE', 'STM_DISABLE')]
        [string]$dyn_ipv6_ld_out_of_resources,
        [Parameter(Mandatory = $false)]
        [ValidateSet('STM_ENABLE', 'STM_DISABLE')]
        [string]$dyn_ipv6_ld_violations,
        [Parameter(Mandatory = $false)]
        [ValidateSet('STM_ENABLE', 'STM_DISABLE')]
        [string]$login_failure_mgr,
        [Parameter(Mandatory = $false)]
        [ValidateSet('STM_ENABLE', 'STM_DISABLE')]
        [string]$mac_count_notify,
        [Parameter(Mandatory = $false)]
        [ValidateSet('STM_ENABLE', 'STM_DISABLE')]
        [string]$nd_snooping_out_of_resources,
        [Parameter(Mandatory = $false)]
        [ValidateSet('STM_ENABLE', 'STM_DISABLE')]
        [string]$password_change_mgr,
        [Parameter(Mandatory = $false)]
        [ValidateSet('STM_ENABLE', 'STM_DISABLE')]
        [string]$port_security,
        [Parameter(Mandatory = $false)]
        [ValidateSet('STM_ENABLE', 'STM_DISABLE')]
        [string]$startup_config_change,
        [Parameter(Mandatory = $false)]
        [string]$snmp_authentication,
        [Parameter(Mandatory = $false)]
        [PSObject]$mac_notify,
        [Parameter(Mandatory = $false)]
        [PSObject]$running_config_changes,
        [Parameter (Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$connection = (Get-ArubaSWDefaultConnection)
    )

    Begin {
    }

    Process {
        $uri = "snmp-server/traps"
        $changes = @{}
        if ($PsBoundParameters.ContainsKey('arp_protect')) { $changes['arp_protect'] = $arp_protect }
        if ($PsBoundParameters.ContainsKey('auth_server_fail')) { $changes['auth_server_fail'] = $auth_server_fail }
        if ($PsBoundParameters.ContainsKey('dhcp_server')) { $changes['dhcp_server'] = $dhcp_server }
        if ($PsBoundParameters.ContainsKey('dhcp_snooping')) { $changes['dhcp_snooping'] = $dhcp_snooping }
        if ($PsBoundParameters.ContainsKey('dhcpv6_snooping_errant_replies')) { $changes['dhcpv6_snooping_errant_replies'] = $dhcpv6_snooping_errant_replies }
        if ($PsBoundParameters.ContainsKey('dhcpv6_snooping_out_of_resource')) { $changes['dhcpv6_snooping_out_of_resource'] = $dhcpv6_snooping_out_of_resource }
        if ($PsBoundParameters.ContainsKey('dyn_ip_lockdown')) { $changes['dyn_ip_lockdown'] = $dyn_ip_lockdown }
        if ($PsBoundParameters.ContainsKey('dyn_ipv6_ld_out_of_resources')) { $changes['dyn_ipv6_ld_out_of_resources'] = $dyn_ipv6_ld_out_of_resources }
        if ($PsBoundParameters.ContainsKey('dyn_ipv6_ld_violations')) { $changes['dyn_ipv6_ld_violations'] = $dyn_ipv6_ld_violations }
        if ($PsBoundParameters.ContainsKey('login_failure_mgr')) { $changes['login_failure_mgr'] = $login_failure_mgr }
        if ($PsBoundParameters.ContainsKey('mac_count_notify')) { $changes['mac_count_notify'] = $mac_count_notify }
        if ($PsBoundParameters.ContainsKey('nd_snooping_out_of_resources')) { $changes['nd_snooping_out_of_resources'] = $nd_snooping_out_of_resources }
        if ($PsBoundParameters.ContainsKey('password_change_mgr')) { $changes['password_change_mgr'] = $password_change_mgr }
        if ($PsBoundParameters.ContainsKey('port_security')) { $changes['port_security'] = $port_security }
        if ($PsBoundParameters.ContainsKey('startup_config_change')) { $changes['startup_config_change'] = $startup_config_change }
        if ($PsBoundParameters.ContainsKey('snmp_authentication')) { $changes['snmp_authentication'] = $snmp_authentication }
        if ($PsBoundParameters.ContainsKey('mac_notify')) { $changes['mac_notify'] = $mac_notify }
        if ($PsBoundParameters.ContainsKey('running_config_changes')) { $changes['running_config_changes'] = $running_config_changes }
        $body = Get-ArubaSWMergedBody -Uri $uri -Changes $changes -Connection $connection

        if ($PSCmdlet.ShouldProcess($connection.server, 'Configure Configure the SNMP trap settings.')) {
            $response = Invoke-ArubaSWWebRequest -method "PUT" -body $body -uri $uri -connection $connection
            if ($response.content) {
                $response.content | ConvertFrom-Json
            }
        }
    }

    End {
    }
}

function Get-ArubaSWSnmpLinkTrap {

    <#
        .SYNOPSIS
        Get the link-change trap setting of the ports.

        .DESCRIPTION
        Without -port_id: GET /snmp-server/traps/linktraps (list). With it: GET /snmp-server/traps/linktraps/<port>.
        Fields: port_id, is_enabled.

        .EXAMPLE
        Get-ArubaSWSnmpLinkTrap -port_id 21
    #>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $false)]
        [string]$port_id,
        [Parameter (Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$connection = (Get-ArubaSWDefaultConnection)
    )

    Begin {
    }

    Process {
        $p = @{ Path = 'snmp-server/traps/linktraps'; ElementName = 'link_change_trap_element'; Connection = $connection }
        if ($PsBoundParameters.ContainsKey('port_id')) { $p['PortId'] = $port_id }
        Get-ArubaSWPortResource @p
    }

    End {
    }
}

function Set-ArubaSWSnmpLinkTrap {

    <#
        .SYNOPSIS
        Configure link-change trap of a port.

        .DESCRIPTION
        Sends PUT /snmp-server/traps/linktraps/<port> with port_id and is_enabled. Accepts port_id from the pipeline.

        .EXAMPLE
        Set-ArubaSWSnmpLinkTrap -port_id 21 -is_enabled:$false
    #>

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    Param(
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$port_id,
        [Parameter(Mandatory = $false)]
        [switch]$is_enabled,
        [Parameter (Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$connection = (Get-ArubaSWDefaultConnection)
    )

    Begin {
    }

    Process {
        $uri = "snmp-server/traps/linktraps/${port_id}"
        $changes = @{}
        if ($PsBoundParameters.ContainsKey('is_enabled')) { $changes['is_enabled'] = [bool]$is_enabled }
        $body = Get-ArubaSWMergedBody -Uri $uri -Changes $changes -Connection $connection

        if ($PSCmdlet.ShouldProcess($port_id, 'Configure link-change trap of a port')) {
            $response = Invoke-ArubaSWWebRequest -method "PUT" -body $body -uri $uri -connection $connection
            if ($response.content) {
                $response.content | ConvertFrom-Json
            }
        }
    }

    End {
    }
}
