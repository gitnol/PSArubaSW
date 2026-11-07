#
# Copyright 2026, PowerArubaSW contributors
# SPDX-License-Identifier: Apache-2.0
#
# SNMPv3: Public/Snmpv3.ps1 (Inkrement I37). Felder, Werte und Verhalten stammen von einer 2540 (YC.16.11.0010), nicht aus der Spec.

function Get-ArubaSWSnmpv3 {

    <#
        .SYNOPSIS
        Get the global SNMPv3 settings.

        .DESCRIPTION
        Reads GET /snmpv3: is_snmpv3_server_enabled, is_non_snmpv3_access_readonly, is_snmpv3_messages_only.

        .EXAMPLE
        Get-ArubaSWSnmpv3
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
        $response = Invoke-ArubaSWWebRequest -method "GET" -uri "snmpv3" -connection $connection
        $response.content | ConvertFrom-Json
    }

    End {
    }
}

function Set-ArubaSWSnmpv3 {

    <#
        .SYNOPSIS
        Configure the global SNMPv3 settings.

        .DESCRIPTION
        Sends PUT /snmpv3 with the complete object (the cmdlet reads it first; fields you do not pass keep their value).
        Verified on a 2540: -is_snmpv3_server_enabled creates the user "initial" in the configuration (snmpv3 enable, snmpv3 user "initial"), switching it off removes both again.
        SNMPv3 users, parameters and targets can only be created while SNMPv3 is enabled ("SNMPv3 must be enabled").
        -is_non_snmpv3_access_readonly and -is_snmpv3_messages_only restrict SNMPv1/v2c access and can lock out monitoring systems.

        .EXAMPLE
        Set-ArubaSWSnmpv3 -is_snmpv3_server_enabled
    #>

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    Param(
        [Parameter(Mandatory = $false)]
        [switch]$is_snmpv3_server_enabled,
        [Parameter(Mandatory = $false)]
        [switch]$is_non_snmpv3_access_readonly,
        [Parameter(Mandatory = $false)]
        [switch]$is_snmpv3_messages_only,
        [Parameter (Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$connection = (Get-ArubaSWDefaultConnection)
    )

    Begin {
    }

    Process {
        $uri = "snmpv3"
        $changes = @{}
        if ($PsBoundParameters.ContainsKey('is_snmpv3_server_enabled')) { $changes['is_snmpv3_server_enabled'] = [bool]$is_snmpv3_server_enabled }
        if ($PsBoundParameters.ContainsKey('is_non_snmpv3_access_readonly')) { $changes['is_non_snmpv3_access_readonly'] = [bool]$is_non_snmpv3_access_readonly }
        if ($PsBoundParameters.ContainsKey('is_snmpv3_messages_only')) { $changes['is_snmpv3_messages_only'] = [bool]$is_snmpv3_messages_only }
        $body = Get-ArubaSWMergedBody -Uri $uri -Changes $changes -Connection $connection

        if ($PSCmdlet.ShouldProcess($connection.server, 'Configure Configure the global SNMPv3 settings.')) {
            $response = Invoke-ArubaSWWebRequest -method "PUT" -body $body -uri $uri -connection $connection
            if ($response.content) {
                $response.content | ConvertFrom-Json
            }
        }
    }

    End {
    }
}

function Get-ArubaSWSnmpv3NotifyName {

    <#
        .SYNOPSIS
        Get SNMPv3 notify names.

        .DESCRIPTION
        Without -notify_name: GET /snmpv3/notify_names (list). With it: GET /snmpv3/notify_names/<name>. Fields: notify_name, tagvalue.

        .EXAMPLE
        Get-ArubaSWSnmpv3NotifyName
    #>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $false)]
        [string]$notify_name,
        [Parameter (Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$connection = (Get-ArubaSWDefaultConnection)
    )

    Begin {
    }

    Process {
        $p = @{ Path = 'snmpv3/notify_names'; ElementName = 'snmpv3_notify_element'; Connection = $connection }
        if ($PsBoundParameters.ContainsKey('notify_name')) { $p['PortId'] = $notify_name }
        Get-ArubaSWPortResource @p
    }

    End {
    }
}

function Add-ArubaSWSnmpv3NotifyName {

    <#
        .SYNOPSIS
        Add SNMPv3 notify name.

        .DESCRIPTION
        Sends POST /snmpv3/notify_names.

        .EXAMPLE
        Add-ArubaSWSnmpv3NotifyName -notify_name notify1 -tagvalue tag1
    #>

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    Param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$notify_name,
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$tagvalue,
        [Parameter (Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$connection = (Get-ArubaSWDefaultConnection)
    )

    Begin {
    }

    Process {
        $uri = "snmpv3/notify_names"
        $changes = @{}
        if ($PsBoundParameters.ContainsKey('notify_name')) { $changes['notify_name'] = $notify_name }
        if ($PsBoundParameters.ContainsKey('tagvalue')) { $changes['tagvalue'] = $tagvalue }

        if ($PSCmdlet.ShouldProcess($notify_name, 'Add SNMPv3 notify name')) {
            $response = Invoke-ArubaSWWebRequest -method "POST" -body ([pscustomobject]$changes) -uri $uri -connection $connection
            $response.content | ConvertFrom-Json
        }
    }

    End {
    }
}

function Remove-ArubaSWSnmpv3NotifyName {

    <#
        .SYNOPSIS
        Remove SNMPv3 notify name.

        .DESCRIPTION
        Sends DELETE /snmpv3/notify_names/<name>.

        .EXAMPLE
        Get-ArubaSWSnmpv3NotifyName -notify_name notify1 | Remove-ArubaSWSnmpv3NotifyName
    #>

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    Param(
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$notify_name,
        [Parameter (Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$connection = (Get-ArubaSWDefaultConnection)
    )

    Begin {
    }

    Process {
        $uri = "snmpv3/notify_names/${notify_name}"

        if ($PSCmdlet.ShouldProcess($notify_name, 'Remove SNMPv3 notify name')) {
            $null = Invoke-ArubaSWWebRequest -method "DELETE" -uri $uri -connection $connection
        }
    }

    End {
    }
}

function Get-ArubaSWSnmpv3Param {

    <#
        .SYNOPSIS
        Get SNMPv3 parameters.

        .DESCRIPTION
        Without -parameter_name: GET /snmpv3/params (list). With it: GET /snmpv3/params/<name>.
        Fields: parameter_name, snmpv3_message_processing_model_value (seen: SMPMV_VER1, SMPMV_VER2C), user_name, snmpv3_authentication (seen: ATV_NOAUTH), snmpv3_sec_model (seen: SSM_VER1, SSM_VER2C).

        .EXAMPLE
        Get-ArubaSWSnmpv3Param
    #>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $false)]
        [string]$parameter_name,
        [Parameter (Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$connection = (Get-ArubaSWDefaultConnection)
    )

    Begin {
    }

    Process {
        $p = @{ Path = 'snmpv3/params'; ElementName = 'snmpv3_param_element'; Connection = $connection }
        if ($PsBoundParameters.ContainsKey('parameter_name')) { $p['PortId'] = $parameter_name }
        Get-ArubaSWPortResource @p
    }

    End {
    }
}

function Add-ArubaSWSnmpv3Param {

    <#
        .SYNOPSIS
        Add SNMPv3 parameter.

        .DESCRIPTION
        Sends POST /snmpv3/params. Values as Get-ArubaSWSnmpv3Param returns them (verified: SMPMV_VER2C, ATV_NOAUTH, SSM_VER2C).

        .EXAMPLE
        Add-ArubaSWSnmpv3Param -parameter_name p1 -snmpv3_message_processing_model_value SMPMV_VER2C -user_name monitor -snmpv3_authentication ATV_NOAUTH -snmpv3_sec_model SSM_VER2C
    #>

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    Param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$parameter_name,
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$snmpv3_message_processing_model_value,
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$user_name,
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$snmpv3_authentication,
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$snmpv3_sec_model,
        [Parameter (Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$connection = (Get-ArubaSWDefaultConnection)
    )

    Begin {
    }

    Process {
        $uri = "snmpv3/params"
        $changes = @{}
        if ($PsBoundParameters.ContainsKey('parameter_name')) { $changes['parameter_name'] = $parameter_name }
        if ($PsBoundParameters.ContainsKey('snmpv3_message_processing_model_value')) { $changes['snmpv3_message_processing_model_value'] = $snmpv3_message_processing_model_value }
        if ($PsBoundParameters.ContainsKey('user_name')) { $changes['user_name'] = $user_name }
        if ($PsBoundParameters.ContainsKey('snmpv3_authentication')) { $changes['snmpv3_authentication'] = $snmpv3_authentication }
        if ($PsBoundParameters.ContainsKey('snmpv3_sec_model')) { $changes['snmpv3_sec_model'] = $snmpv3_sec_model }

        if ($PSCmdlet.ShouldProcess($parameter_name, 'Add SNMPv3 parameter')) {
            $response = Invoke-ArubaSWWebRequest -method "POST" -body ([pscustomobject]$changes) -uri $uri -connection $connection
            $response.content | ConvertFrom-Json
        }
    }

    End {
    }
}

function Set-ArubaSWSnmpv3Param {

    <#
        .SYNOPSIS
        Configure SNMPv3 parameter.

        .DESCRIPTION
        Sends PUT /snmpv3/params/<name> with the complete object (read first; fields you do not pass keep their value).

        .EXAMPLE
        Set-ArubaSWSnmpv3Param -parameter_name p1 -user_name other
    #>

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    Param(
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$parameter_name,
        [Parameter(Mandatory = $false)]
        [string]$snmpv3_message_processing_model_value,
        [Parameter(Mandatory = $false)]
        [string]$user_name,
        [Parameter(Mandatory = $false)]
        [string]$snmpv3_authentication,
        [Parameter(Mandatory = $false)]
        [string]$snmpv3_sec_model,
        [Parameter (Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$connection = (Get-ArubaSWDefaultConnection)
    )

    Begin {
    }

    Process {
        $uri = "snmpv3/params/${parameter_name}"
        $changes = @{}
        if ($PsBoundParameters.ContainsKey('snmpv3_message_processing_model_value')) { $changes['snmpv3_message_processing_model_value'] = $snmpv3_message_processing_model_value }
        if ($PsBoundParameters.ContainsKey('user_name')) { $changes['user_name'] = $user_name }
        if ($PsBoundParameters.ContainsKey('snmpv3_authentication')) { $changes['snmpv3_authentication'] = $snmpv3_authentication }
        if ($PsBoundParameters.ContainsKey('snmpv3_sec_model')) { $changes['snmpv3_sec_model'] = $snmpv3_sec_model }
        $body = Get-ArubaSWMergedBody -Uri $uri -Changes $changes -Connection $connection

        if ($PSCmdlet.ShouldProcess($parameter_name, 'Configure SNMPv3 parameter')) {
            $response = Invoke-ArubaSWWebRequest -method "PUT" -body $body -uri $uri -connection $connection
            if ($response.content) {
                $response.content | ConvertFrom-Json
            }
        }
    }

    End {
    }
}

function Remove-ArubaSWSnmpv3Param {

    <#
        .SYNOPSIS
        Remove SNMPv3 parameter.

        .DESCRIPTION
        Sends DELETE /snmpv3/params/<name>.

        .EXAMPLE
        Get-ArubaSWSnmpv3Param -parameter_name p1 | Remove-ArubaSWSnmpv3Param
    #>

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    Param(
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$parameter_name,
        [Parameter (Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$connection = (Get-ArubaSWDefaultConnection)
    )

    Begin {
    }

    Process {
        $uri = "snmpv3/params/${parameter_name}"

        if ($PSCmdlet.ShouldProcess($parameter_name, 'Remove SNMPv3 parameter')) {
            $null = Invoke-ArubaSWWebRequest -method "DELETE" -uri $uri -connection $connection
        }
    }

    End {
    }
}

function Get-ArubaSWSnmpv3TargetAddress {

    <#
        .SYNOPSIS
        Get SNMPv3 target addresses.

        .DESCRIPTION
        Without -target_address_name: GET /snmpv3/target_addresses (list). With it: GET /snmpv3/target_addresses/<name>.
        Fields: target_address_name, dest_ip_address, tag_list, snmpv3_filter (seen: SF_NONE), parameter_name, is_oobm.
        Every SNMP host (Add-ArubaSWSnmpHost) creates an entry here, which disappears with the host.

        .EXAMPLE
        Get-ArubaSWSnmpv3TargetAddress
    #>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $false)]
        [string]$target_address_name,
        [Parameter (Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$connection = (Get-ArubaSWDefaultConnection)
    )

    Begin {
    }

    Process {
        $p = @{ Path = 'snmpv3/target_addresses'; ElementName = 'snmpv3_target_address_element'; Connection = $connection }
        if ($PsBoundParameters.ContainsKey('target_address_name')) { $p['PortId'] = $target_address_name }
        Get-ArubaSWPortResource @p
    }

    End {
    }
}

function Add-ArubaSWSnmpv3TargetAddress {

    <#
        .SYNOPSIS
        Add SNMPv3 target address.

        .DESCRIPTION
        Sends POST /snmpv3/target_addresses. -parameter_name must name an existing parameter (Add-ArubaSWSnmpv3Param); -tag_list names notify tags.

        .EXAMPLE
        Add-ArubaSWSnmpv3TargetAddress -target_address_name t1 -dest_ip_address 192.0.2.10 -tag_list tag1 -snmpv3_filter SF_NONE -parameter_name p1
    #>

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    Param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$target_address_name,
        [Parameter(Mandatory = $true)]
        [ipaddress]$dest_ip_address,
        [Parameter(Mandatory = $true)]
        [string[]]$tag_list,
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$snmpv3_filter,
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$parameter_name,
        [Parameter(Mandatory = $false)]
        [switch]$is_oobm,
        [Parameter (Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$connection = (Get-ArubaSWDefaultConnection)
    )

    Begin {
    }

    Process {
        $uri = "snmpv3/target_addresses"
        $changes = @{}
        if ($PsBoundParameters.ContainsKey('target_address_name')) { $changes['target_address_name'] = $target_address_name }
        if ($PsBoundParameters.ContainsKey('dest_ip_address')) { $changes['dest_ip_address'] = [pscustomobject]@{ version = 'IAV_IP_V4'; octets = $dest_ip_address.ToString() } }
        if ($PsBoundParameters.ContainsKey('tag_list')) { $changes['tag_list'] = @($tag_list) }
        if ($PsBoundParameters.ContainsKey('snmpv3_filter')) { $changes['snmpv3_filter'] = $snmpv3_filter }
        if ($PsBoundParameters.ContainsKey('parameter_name')) { $changes['parameter_name'] = $parameter_name }
        if ($PsBoundParameters.ContainsKey('is_oobm')) { $changes['is_oobm'] = [bool]$is_oobm }

        if ($PSCmdlet.ShouldProcess($target_address_name, 'Add SNMPv3 target address')) {
            $response = Invoke-ArubaSWWebRequest -method "POST" -body ([pscustomobject]$changes) -uri $uri -connection $connection
            $response.content | ConvertFrom-Json
        }
    }

    End {
    }
}

function Set-ArubaSWSnmpv3TargetAddress {

    <#
        .SYNOPSIS
        Configure SNMPv3 target address.

        .DESCRIPTION
        Sends PUT /snmpv3/target_addresses/<name> with the complete object (read first; fields you do not pass keep their value).

        .EXAMPLE
        Set-ArubaSWSnmpv3TargetAddress -target_address_name t1 -tag_list tag2
    #>

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    Param(
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$target_address_name,
        [Parameter(Mandatory = $false)]
        [ipaddress]$dest_ip_address,
        [Parameter(Mandatory = $false)]
        [string[]]$tag_list,
        [Parameter(Mandatory = $false)]
        [string]$snmpv3_filter,
        [Parameter(Mandatory = $false)]
        [string]$parameter_name,
        [Parameter(Mandatory = $false)]
        [switch]$is_oobm,
        [Parameter (Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$connection = (Get-ArubaSWDefaultConnection)
    )

    Begin {
    }

    Process {
        $uri = "snmpv3/target_addresses/${target_address_name}"
        $changes = @{}
        if ($PsBoundParameters.ContainsKey('dest_ip_address')) { $changes['dest_ip_address'] = [pscustomobject]@{ version = 'IAV_IP_V4'; octets = $dest_ip_address.ToString() } }
        if ($PsBoundParameters.ContainsKey('tag_list')) { $changes['tag_list'] = @($tag_list) }
        if ($PsBoundParameters.ContainsKey('snmpv3_filter')) { $changes['snmpv3_filter'] = $snmpv3_filter }
        if ($PsBoundParameters.ContainsKey('parameter_name')) { $changes['parameter_name'] = $parameter_name }
        if ($PsBoundParameters.ContainsKey('is_oobm')) { $changes['is_oobm'] = [bool]$is_oobm }
        $body = Get-ArubaSWMergedBody -Uri $uri -Changes $changes -Connection $connection

        if ($PSCmdlet.ShouldProcess($target_address_name, 'Configure SNMPv3 target address')) {
            $response = Invoke-ArubaSWWebRequest -method "PUT" -body $body -uri $uri -connection $connection
            if ($response.content) {
                $response.content | ConvertFrom-Json
            }
        }
    }

    End {
    }
}

function Remove-ArubaSWSnmpv3TargetAddress {

    <#
        .SYNOPSIS
        Remove SNMPv3 target address.

        .DESCRIPTION
        Sends DELETE /snmpv3/target_addresses/<name>.

        .EXAMPLE
        Get-ArubaSWSnmpv3TargetAddress -target_address_name t1 | Remove-ArubaSWSnmpv3TargetAddress
    #>

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    Param(
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$target_address_name,
        [Parameter (Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$connection = (Get-ArubaSWDefaultConnection)
    )

    Begin {
    }

    Process {
        $uri = "snmpv3/target_addresses/${target_address_name}"

        if ($PSCmdlet.ShouldProcess($target_address_name, 'Remove SNMPv3 target address')) {
            $null = Invoke-ArubaSWWebRequest -method "DELETE" -uri $uri -connection $connection
        }
    }

    End {
    }
}

function Get-ArubaSWSnmpv3User {

    <#
        .SYNOPSIS
        Get SNMPv3 users.

        .DESCRIPTION
        Without -user_name: GET /snmpv3/users (list). With it: GET /snmpv3/users/<name>.
        Fields: user_name, snmpv3_authentication_protocol, snmpv3_authentication_privacy_protocol, authentication_password and privacy_password (always empty),
        snmpv3_v1_group, snmpv3_v2c_group, snmpv3_v3_group. Empty while SNMPv3 is off.

        .EXAMPLE
        Get-ArubaSWSnmpv3User
    #>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $false)]
        [string]$user_name,
        [Parameter (Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$connection = (Get-ArubaSWDefaultConnection)
    )

    Begin {
    }

    Process {
        $p = @{ Path = 'snmpv3/users'; ElementName = 'snmpv3_user_element'; Connection = $connection }
        if ($PsBoundParameters.ContainsKey('user_name')) { $p['PortId'] = $user_name }
        Get-ArubaSWPortResource @p
    }

    End {
    }
}

function Add-ArubaSWSnmpv3User {

    <#
        .SYNOPSIS
        Add SNMPv3 user.

        .DESCRIPTION
        Sends POST /snmpv3/users; SNMPv3 must be enabled (Set-ArubaSWSnmpv3 -is_snmpv3_server_enabled).
        Verified on a 2540 (SNMPv3 enabled): a user without passwords (SAP_NONE, SAPP_NONE, groups SGT_NONE) is created and removed; SAP_MD5 and SAP_SHA need
        -authentication_password, SAPP_DES and SAPP_AES need -privacy_password ("... password is missing"); SAP_SHA1 and SAPP_AES128 do not exist.
        The group names SGT_* were not found (every guess was rejected as "Invalid group Type"); pass the value that Get-ArubaSWSnmpv3User returns.
        Passwords are SecureString and are sent in clear text in the request, the switch returns them as empty strings. Creating a user WITH passwords was not exercised on a switch.

        .EXAMPLE
        Add-ArubaSWSnmpv3User -user_name monitor

        .EXAMPLE
        Add-ArubaSWSnmpv3User -user_name monitor -snmpv3_authentication_protocol SAP_SHA -authentication_password (Read-Host -AsSecureString)
    #>

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    Param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$user_name,
        [Parameter(Mandatory = $false)]
        [ValidateSet('SAP_NONE', 'SAP_MD5', 'SAP_SHA')]
        [string]$snmpv3_authentication_protocol,
        [Parameter(Mandatory = $false)]
        [securestring]$authentication_password,
        [Parameter(Mandatory = $false)]
        [ValidateSet('SAPP_NONE', 'SAPP_DES', 'SAPP_AES')]
        [string]$snmpv3_authentication_privacy_protocol,
        [Parameter(Mandatory = $false)]
        [securestring]$privacy_password,
        [Parameter(Mandatory = $false)]
        [string]$snmpv3_v1_group,
        [Parameter(Mandatory = $false)]
        [string]$snmpv3_v2c_group,
        [Parameter(Mandatory = $false)]
        [string]$snmpv3_v3_group,
        [Parameter (Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$connection = (Get-ArubaSWDefaultConnection)
    )

    Begin {
    }

    Process {
        $uri = "snmpv3/users"
        $changes = @{}
        if ($PsBoundParameters.ContainsKey('user_name')) { $changes['user_name'] = $user_name }
        if ($PsBoundParameters.ContainsKey('snmpv3_authentication_protocol')) { $changes['snmpv3_authentication_protocol'] = $snmpv3_authentication_protocol }
        if ($PsBoundParameters.ContainsKey('authentication_password')) { $changes['authentication_password'] = [System.Net.NetworkCredential]::new('', $authentication_password).Password }
        if ($PsBoundParameters.ContainsKey('snmpv3_authentication_privacy_protocol')) { $changes['snmpv3_authentication_privacy_protocol'] = $snmpv3_authentication_privacy_protocol }
        if ($PsBoundParameters.ContainsKey('privacy_password')) { $changes['privacy_password'] = [System.Net.NetworkCredential]::new('', $privacy_password).Password }
        if ($PsBoundParameters.ContainsKey('snmpv3_v1_group')) { $changes['snmpv3_v1_group'] = $snmpv3_v1_group }
        if ($PsBoundParameters.ContainsKey('snmpv3_v2c_group')) { $changes['snmpv3_v2c_group'] = $snmpv3_v2c_group }
        if ($PsBoundParameters.ContainsKey('snmpv3_v3_group')) { $changes['snmpv3_v3_group'] = $snmpv3_v3_group }

        if ($PSCmdlet.ShouldProcess($user_name, 'Add SNMPv3 user')) {
            $response = Invoke-ArubaSWWebRequest -method "POST" -body ([pscustomobject]$changes) -uri $uri -connection $connection
            $response.content | ConvertFrom-Json
        }
    }

    End {
    }
}

function Set-ArubaSWSnmpv3User {

    <#
        .SYNOPSIS
        Configure SNMPv3 user.

        .DESCRIPTION
        Sends PUT /snmpv3/users/<name> with the complete object (read first). The password fields that the switch returns empty are NOT sent back unless you pass them.
        Verified on a 2540 (SNMPv3 enabled): a user without passwords (SAP_NONE, SAPP_NONE, groups SGT_NONE) is created and removed; SAP_MD5 and SAP_SHA need
        -authentication_password, SAPP_DES and SAPP_AES need -privacy_password ("... password is missing"); SAP_SHA1 and SAPP_AES128 do not exist.
        The group names SGT_* were not found (every guess was rejected as "Invalid group Type"); pass the value that Get-ArubaSWSnmpv3User returns.
        Passwords are SecureString and are sent in clear text in the request, the switch returns them as empty strings. Creating a user WITH passwords was not exercised on a switch.

        .EXAMPLE
        Set-ArubaSWSnmpv3User -user_name monitor -snmpv3_v3_group <value from Get-ArubaSWSnmpv3User>
    #>

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    Param(
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$user_name,
        [Parameter(Mandatory = $false)]
        [ValidateSet('SAP_NONE', 'SAP_MD5', 'SAP_SHA')]
        [string]$snmpv3_authentication_protocol,
        [Parameter(Mandatory = $false)]
        [securestring]$authentication_password,
        [Parameter(Mandatory = $false)]
        [ValidateSet('SAPP_NONE', 'SAPP_DES', 'SAPP_AES')]
        [string]$snmpv3_authentication_privacy_protocol,
        [Parameter(Mandatory = $false)]
        [securestring]$privacy_password,
        [Parameter(Mandatory = $false)]
        [string]$snmpv3_v1_group,
        [Parameter(Mandatory = $false)]
        [string]$snmpv3_v2c_group,
        [Parameter(Mandatory = $false)]
        [string]$snmpv3_v3_group,
        [Parameter (Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$connection = (Get-ArubaSWDefaultConnection)
    )

    Begin {
    }

    Process {
        $uri = "snmpv3/users/${user_name}"
        $changes = @{}
        if ($PsBoundParameters.ContainsKey('snmpv3_authentication_protocol')) { $changes['snmpv3_authentication_protocol'] = $snmpv3_authentication_protocol }
        if ($PsBoundParameters.ContainsKey('authentication_password')) { $changes['authentication_password'] = [System.Net.NetworkCredential]::new('', $authentication_password).Password }
        if ($PsBoundParameters.ContainsKey('snmpv3_authentication_privacy_protocol')) { $changes['snmpv3_authentication_privacy_protocol'] = $snmpv3_authentication_privacy_protocol }
        if ($PsBoundParameters.ContainsKey('privacy_password')) { $changes['privacy_password'] = [System.Net.NetworkCredential]::new('', $privacy_password).Password }
        if ($PsBoundParameters.ContainsKey('snmpv3_v1_group')) { $changes['snmpv3_v1_group'] = $snmpv3_v1_group }
        if ($PsBoundParameters.ContainsKey('snmpv3_v2c_group')) { $changes['snmpv3_v2c_group'] = $snmpv3_v2c_group }
        if ($PsBoundParameters.ContainsKey('snmpv3_v3_group')) { $changes['snmpv3_v3_group'] = $snmpv3_v3_group }
        $body = Get-ArubaSWMergedBody -Uri $uri -Changes $changes -OmitUnlessChanged 'authentication_password','privacy_password' -Connection $connection

        if ($PSCmdlet.ShouldProcess($user_name, 'Configure SNMPv3 user')) {
            $response = Invoke-ArubaSWWebRequest -method "PUT" -body $body -uri $uri -connection $connection
            if ($response.content) {
                $response.content | ConvertFrom-Json
            }
        }
    }

    End {
    }
}

function Remove-ArubaSWSnmpv3User {

    <#
        .SYNOPSIS
        Remove SNMPv3 user.

        .DESCRIPTION
        Sends DELETE /snmpv3/users/<name>.

        .EXAMPLE
        Get-ArubaSWSnmpv3User -user_name monitor | Remove-ArubaSWSnmpv3User
    #>

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    Param(
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$user_name,
        [Parameter (Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$connection = (Get-ArubaSWDefaultConnection)
    )

    Begin {
    }

    Process {
        $uri = "snmpv3/users/${user_name}"

        if ($PSCmdlet.ShouldProcess($user_name, 'Remove SNMPv3 user')) {
            $null = Invoke-ArubaSWWebRequest -method "DELETE" -uri $uri -connection $connection
        }
    }

    End {
    }
}
