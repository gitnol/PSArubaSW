#
# Copyright 2026, PowerArubaSW contributors
# SPDX-License-Identifier: Apache-2.0
#
# Unit-Tests fuer Public/Snmp.ps1 und Public/Snmpv3.ps1 (Inkrement I37). Die Fixtures sind echte Antworten einer 2540
# (YC.16.11.0010). Die Set-Cmdlets lesen den Zustand zuerst und senden das vollstaendige Objekt ohne uri.

BeforeAll {
    $script:UnitDir    = Split-Path -Parent $PSCommandPath
    $script:TestsRoot  = Split-Path -Parent $UnitDir
    $script:RepoRoot   = Split-Path -Parent $TestsRoot
    $script:ModuleRoot = Join-Path $RepoRoot 'PowerArubaSW'
    $script:Manifest   = Join-Path $ModuleRoot 'PowerArubaSW.psd1'

    $loaded = Get-Module -Name 'PowerArubaSW' -ErrorAction SilentlyContinue
    if ($loaded) { Remove-Module $loaded -Force }
    Import-Module $Manifest -Force

    . "$UnitDir\_helpers\Get-Fixture.ps1"

    $script:StubConnection = [PSCustomObject]@{
        server      = '198.51.100.1'
        port        = 443
        httpOnly    = $false
        api_version = @{ cur = 8 }
    }
}

Describe 'SNMP globale Ressourcen (Get)' -Tag 'Unit' {

    It '<Cmd> ruft GET <Uri> auf' -ForEach @(
        @{ Cmd = 'Get-ArubaSWSnmp'; Uri = 'snmp-server'; Res = 'snmp-server'; Prop = 'is_snmp_server_enabled' }
        @{ Cmd = 'Get-ArubaSWSnmpMib'; Uri = 'snmp-server/mib'; Res = 'snmp-server-mib'; Prop = 'hpSwitchAuthMIB' }
        @{ Cmd = 'Get-ArubaSWSnmpResponseSource'; Uri = 'snmp-server/response-source'; Res = 'snmp-server-response-source'; Prop = 'rs_ip_policy' }
        @{ Cmd = 'Get-ArubaSWSnmpTrapSource'; Uri = 'snmp-server/trap-source'; Res = 'snmp-server-trap-source'; Prop = 'ts_ip_policy' }
        @{ Cmd = 'Get-ArubaSWSnmpTrap'; Uri = 'snmp-server/traps'; Res = 'snmp-server-traps'; Prop = 'startup_config_change' }
        @{ Cmd = 'Get-ArubaSWSnmpv3'; Uri = 'snmpv3'; Res = 'snmpv3'; Prop = 'is_snmpv3_server_enabled' }
    ) {
        $fx = Get-Fixture -Resource $Res -Name get-default
        Mock -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -MockWith { $fx }.GetNewClosure()
        $r = & $Cmd -connection $StubConnection
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 1 -Exactly -ParameterFilter { $method -eq 'GET' -and $uri -eq $Uri }
        $r.PSObject.Properties[$Prop] | Should -Not -BeNullOrEmpty
    }
}

Describe 'SNMP globale Ressourcen (Set)' -Tag 'Unit' {

    BeforeEach {
        $script:Body = $null
        $script:Uri = $null
        $script:Gets = 0
        Mock -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest {
            if ($method -eq 'PUT') { $script:Body = $body; $script:Uri = $uri; Get-Fixture -Resource $script:Res -Name put-set }
            else { $script:Gets++; Get-Fixture -Resource $script:Res -Name get-default }
        }
    }

    It 'Set-ArubaSWSnmp sendet nur das uebergebene Feld ohne vorheriges GET' {
        $script:Res = 'snmp-server'
        $null = Set-ArubaSWSnmp -is_snmp_server_enabled:$false -Confirm:$false -connection $StubConnection
        $Uri | Should -Be 'snmp-server'
        $Body.is_snmp_server_enabled | Should -BeFalse
        $Body.is_snmp_server_enabled | Should -BeOfType [bool]
        $Body.PSObject.Properties['local_engine_id'] | Should -BeNullOrEmpty
        $Gets | Should -Be 0
    }

    It 'Set-ArubaSWSnmpMib sendet hpSwitchAuthMIB' {
        $script:Res = 'snmp-server-mib'
        $null = Set-ArubaSWSnmpMib -hpSwitchAuthMIB SMT_EXCLUDED -Confirm:$false -connection $StubConnection
        $Uri | Should -Be 'snmp-server/mib'
        $Body.hpSwitchAuthMIB | Should -Be 'SMT_EXCLUDED'
    }

    It 'Set-ArubaSWSnmpResponseSource sendet nur die uebergebenen Felder und lehnt unbekannte Richtlinien ab' {
        $script:Res = 'snmp-server-response-source'
        $null = Set-ArubaSWSnmpResponseSource -rs_ip_policy RSIP_LOOPBACK -loopback_interface 1 -Confirm:$false -connection $StubConnection
        $Uri | Should -Be 'snmp-server/response-source'
        $Body.rs_ip_policy | Should -Be 'RSIP_LOOPBACK'
        $Body.loopback_interface | Should -Be 1
        $Body.PSObject.Properties['ip_addr'] | Should -BeNullOrEmpty
        { Set-ArubaSWSnmpResponseSource -rs_ip_policy RSIP_BOGUS -Confirm:$false -connection $StubConnection -ErrorAction Stop } |
            Should -Throw -ErrorId 'ParameterArgumentValidationError,Set-ArubaSWSnmpResponseSource'
    }

    It 'Set-ArubaSWSnmpTrapSource sendet ts_ip_policy' {
        $script:Res = 'snmp-server-trap-source'
        $null = Set-ArubaSWSnmpTrapSource -ts_ip_policy TSIP_DEFAULT -Confirm:$false -connection $StubConnection
        $Uri | Should -Be 'snmp-server/trap-source'
        $Body.ts_ip_policy | Should -Be 'TSIP_DEFAULT'
    }

    It 'Set-ArubaSWSnmpTrap liest zuerst und sendet das vollstaendige Objekt ohne uri' {
        $script:Res = 'snmp-server-traps'
        $null = Set-ArubaSWSnmpTrap -startup_config_change STM_ENABLE -Confirm:$false -connection $StubConnection
        $Uri | Should -Be 'snmp-server/traps'
        $Gets | Should -Be 1
        $Body.startup_config_change | Should -Be 'STM_ENABLE'
        $Body.arp_protect | Should -Be 'STM_ENABLE'
        $Body.mac_notify.trap_interval | Should -Be 30
        $Body.PSObject.Properties['uri'] | Should -BeNullOrEmpty
    }

    It 'Set-ArubaSWSnmpTrap lehnt Werte ausser STM_ENABLE und STM_DISABLE ab' {
        { Set-ArubaSWSnmpTrap -arp_protect ON -Confirm:$false -connection $StubConnection -ErrorAction Stop } |
            Should -Throw -ErrorId 'ParameterArgumentValidationError,Set-ArubaSWSnmpTrap'
    }

    It 'Set-ArubaSWSnmpv3 sendet alle drei Schalter als Booleans' {
        $script:Res = 'snmpv3'
        $null = Set-ArubaSWSnmpv3 -is_snmpv3_server_enabled -Confirm:$false -connection $StubConnection
        $Uri | Should -Be 'snmpv3'
        $Body.is_snmpv3_server_enabled | Should -BeTrue
        $Body.is_non_snmpv3_access_readonly | Should -BeFalse
        $Body.is_snmpv3_messages_only | Should -BeFalse
    }

    It '<Cmd> macht bei -WhatIf keinen PUT' -ForEach @(
        @{ Cmd = 'Set-ArubaSWSnmp'; Res = 'snmp-server'; Params = @{ is_snmp_server_enabled = $true } }
        @{ Cmd = 'Set-ArubaSWSnmpMib'; Res = 'snmp-server-mib'; Params = @{ hpSwitchAuthMIB = 'SMT_INCLUDED' } }
        @{ Cmd = 'Set-ArubaSWSnmpTrap'; Res = 'snmp-server-traps'; Params = @{ arp_protect = 'STM_ENABLE' } }
        @{ Cmd = 'Set-ArubaSWSnmpv3'; Res = 'snmpv3'; Params = @{ is_snmpv3_server_enabled = $true } }
    ) {
        $script:Res = $Res
        $a = $Params
        & $Cmd @a -WhatIf -connection $StubConnection
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 0 -Exactly -ParameterFilter { $method -eq 'PUT' }
    }
}

Describe 'SNMP Community' -Tag 'Unit' {

    BeforeEach {
        $script:Body = $null
        $script:Uri = $null
        Mock -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest {
            switch ($method) {
                'POST' { $script:Body = $body; $script:Uri = $uri; Get-Fixture -Resource snmp-server-communities -Name post-new }
                'PUT' { $script:Body = $body; $script:Uri = $uri; Get-Fixture -Resource snmp-server-communities -Name put-set }
                'DELETE' { $script:Uri = $uri }
                default { if ($uri -eq 'snmp-server/communities') { Get-Fixture -Resource snmp-server-communities -Name get-list } else { Get-Fixture -Resource snmp-server-communities -Name get-item } }
            }
        }
    }

    It 'Get ohne Name liefert die ausgepackte Liste, mit Name das einzelne Objekt' {
        @(Get-ArubaSWSnmpCommunity -connection $StubConnection).Count | Should -Be 2
        $r = Get-ArubaSWSnmpCommunity -community_name i36test -connection $StubConnection
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 1 -Exactly -ParameterFilter { $uri -eq 'snmp-server/communities/i36test' }
        $r.access_type | Should -Be 'UT_OPERATOR'
    }

    It 'Add sendet POST mit Name, Zugriffstyp und restricted als Boolean' {
        $null = Add-ArubaSWSnmpCommunity -community_name i36test -access_type UT_OPERATOR -restricted:$false -Confirm:$false -connection $StubConnection
        $Uri | Should -Be 'snmp-server/communities'
        $Body.community_name | Should -Be 'i36test'
        $Body.access_type | Should -Be 'UT_OPERATOR'
        $Body.restricted | Should -BeFalse
    }

    It 'Add sendet restricted nur, wenn es uebergeben wurde (der Switch setzt sonst true)' {
        $null = Add-ArubaSWSnmpCommunity -community_name i36test -access_type UT_OPERATOR -Confirm:$false -connection $StubConnection
        $Body.PSObject.Properties['restricted'] | Should -BeNullOrEmpty
    }

    It 'Add lehnt andere Zugriffstypen ab' {
        { Add-ArubaSWSnmpCommunity -community_name x -access_type UT_GUEST -Confirm:$false -connection $StubConnection -ErrorAction Stop } |
            Should -Throw -ErrorId 'ParameterArgumentValidationError,Add-ArubaSWSnmpCommunity'
    }

    It 'Set liest zuerst und sendet das vollstaendige Objekt (der Switch lehnt Teilobjekte ab)' {
        $null = Set-ArubaSWSnmpCommunity -community_name i36test -restricted:$false -Confirm:$false -connection $StubConnection
        $Uri | Should -Be 'snmp-server/communities/i36test'
        $Body.restricted | Should -BeFalse
        $Body.access_type | Should -Be 'UT_OPERATOR'
        $Body.community_name | Should -Be 'i36test'
        $Body.PSObject.Properties['uri'] | Should -BeNullOrEmpty
    }

    It 'Set nimmt community_name aus der Pipeline' {
        Get-ArubaSWSnmpCommunity -community_name i36test -connection $StubConnection |
            Set-ArubaSWSnmpCommunity -access_type UT_MANAGER -Confirm:$false -connection $StubConnection | Out-Null
        $Body.access_type | Should -Be 'UT_MANAGER'
    }

    It 'Remove sendet DELETE per Name und per Pipeline' {
        Remove-ArubaSWSnmpCommunity -community_name i36test -Confirm:$false -connection $StubConnection
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 1 -Exactly -ParameterFilter { $method -eq 'DELETE' -and $uri -eq 'snmp-server/communities/i36test' }
        Get-ArubaSWSnmpCommunity -community_name i36test -connection $StubConnection | Remove-ArubaSWSnmpCommunity -Confirm:$false -connection $StubConnection
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 2 -Exactly -ParameterFilter { $method -eq 'DELETE' }
    }

    It 'Add, Set und Remove machen bei -WhatIf keinen schreibenden Aufruf' {
        Add-ArubaSWSnmpCommunity -community_name x -access_type UT_OPERATOR -WhatIf -connection $StubConnection
        Set-ArubaSWSnmpCommunity -community_name i36test -restricted -WhatIf -connection $StubConnection
        Remove-ArubaSWSnmpCommunity -community_name i36test -WhatIf -connection $StubConnection
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 0 -Exactly -ParameterFilter { $method -in 'POST', 'PUT', 'DELETE' }
    }
}

Describe 'SNMP Host' -Tag 'Unit' {

    BeforeEach {
        $script:Body = $null
        $script:Uri = $null
        Mock -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest {
            switch ($method) {
                'POST' { $script:Body = $body; $script:Uri = $uri; Get-Fixture -Resource snmp-server-hosts -Name post-new }
                'PUT' { $script:Body = $body; $script:Uri = $uri; Get-Fixture -Resource snmp-server-hosts -Name put-set }
                'DELETE' { $script:Uri = $uri }
                default { if ($uri -eq 'snmp-server/hosts') { Get-Fixture -Resource snmp-server-hosts -Name get-list } else { Get-Fixture -Resource snmp-server-hosts -Name get-item } }
            }
        }
    }

    It 'Get ohne Parameter liefert die Liste, mit Adresse und Community das Objekt unter <ip>-<community>' {
        @(Get-ArubaSWSnmpHost -connection $StubConnection).Count | Should -Be 1
        $r = Get-ArubaSWSnmpHost -host_ip 198.51.100.77 -community i36test -connection $StubConnection
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 1 -Exactly -ParameterFilter { $uri -eq 'snmp-server/hosts/198.51.100.77-i36test' }
        $r.trap_level | Should -Be 'STL_NONE'
    }

    It 'Get verlangt -host_ip und -community zusammen' {
        { Get-ArubaSWSnmpHost -host_ip 198.51.100.77 -connection $StubConnection -ErrorAction Stop } | Should -Throw -ExpectedMessage '*together*'
    }

    It 'Add sendet host_ip als Adressobjekt und community' {
        $null = Add-ArubaSWSnmpHost -host_ip 198.51.100.77 -community i36test -trap_level STL_CRITICAL -informs -inform_retries 5 -Confirm:$false -connection $StubConnection
        $Uri | Should -Be 'snmp-server/hosts'
        $Body.host_ip.version | Should -Be 'IAV_IP_V4'
        $Body.host_ip.octets | Should -Be '198.51.100.77'
        $Body.community | Should -Be 'i36test'
        $Body.trap_level | Should -Be 'STL_CRITICAL'
        $Body.informs | Should -BeTrue
        $Body.inform_retries | Should -Be 5
        $Body.PSObject.Properties['use_oobm'] | Should -BeNullOrEmpty
    }

    It 'Set per Adresse liest zuerst und sendet das vollstaendige Objekt' {
        $null = Set-ArubaSWSnmpHost -host_ip 198.51.100.77 -community i36test -trap_level STL_ALL -Confirm:$false -connection $StubConnection
        $Uri | Should -Be 'snmp-server/hosts/198.51.100.77-i36test'
        $Body.trap_level | Should -Be 'STL_ALL'
        $Body.inform_timeout | Should -Be 15
        $Body.host_ip.octets | Should -Be '198.51.100.77'
        $Body.PSObject.Properties['uri'] | Should -BeNullOrEmpty
    }

    It 'Set und Remove nehmen das Host-Objekt aus der Pipeline' {
        Get-ArubaSWSnmpHost -connection $StubConnection | Set-ArubaSWSnmpHost -informs -Confirm:$false -connection $StubConnection | Out-Null
        $Uri | Should -Be 'snmp-server/hosts/198.51.100.77-i36test'
        $Body.informs | Should -BeTrue
        Get-ArubaSWSnmpHost -connection $StubConnection | Remove-ArubaSWSnmpHost -Confirm:$false -connection $StubConnection
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 1 -Exactly -ParameterFilter { $method -eq 'DELETE' -and $uri -eq 'snmp-server/hosts/198.51.100.77-i36test' }
    }

    It 'Remove per Adresse sendet DELETE auf <ip>-<community>' {
        Remove-ArubaSWSnmpHost -host_ip 198.51.100.77 -community i36test -Confirm:$false -connection $StubConnection
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 1 -Exactly -ParameterFilter { $method -eq 'DELETE' -and $uri -eq 'snmp-server/hosts/198.51.100.77-i36test' }
    }

    It 'Add, Set und Remove machen bei -WhatIf keinen schreibenden Aufruf' {
        Add-ArubaSWSnmpHost -host_ip 198.51.100.77 -community x -WhatIf -connection $StubConnection
        Set-ArubaSWSnmpHost -host_ip 198.51.100.77 -community i36test -informs -WhatIf -connection $StubConnection
        Remove-ArubaSWSnmpHost -host_ip 198.51.100.77 -community i36test -WhatIf -connection $StubConnection
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 0 -Exactly -ParameterFilter { $method -in 'POST', 'PUT', 'DELETE' }
    }
}

Describe 'SNMP Link-Traps' -Tag 'Unit' {

    BeforeEach {
        $script:Body = $null
        $script:Uri = $null
        Mock -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest {
            if ($method -eq 'PUT') { $script:Body = $body; $script:Uri = $uri; Get-Fixture -Resource snmp-server-linktraps -Name put-port21 }
            elseif ($uri -eq 'snmp-server/traps/linktraps') { Get-Fixture -Resource snmp-server-linktraps -Name get-list }
            else { Get-Fixture -Resource snmp-server-linktraps -Name get-port21 }
        }
    }

    It 'Get liefert Liste bzw. einzelnen Port' {
        @(Get-ArubaSWSnmpLinkTrap -connection $StubConnection).Count | Should -Be 2
        (Get-ArubaSWSnmpLinkTrap -port_id 21 -connection $StubConnection).port_id | Should -Be '21'
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 1 -Exactly -ParameterFilter { $uri -eq 'snmp-server/traps/linktraps/21' }
    }

    It 'Set sendet port_id und is_enabled als Boolean, auch aus der Pipeline' {
        $null = Set-ArubaSWSnmpLinkTrap -port_id 21 -is_enabled:$false -Confirm:$false -connection $StubConnection
        $Uri | Should -Be 'snmp-server/traps/linktraps/21'
        $Body.port_id | Should -Be '21'
        $Body.is_enabled | Should -BeFalse
        Get-ArubaSWSnmpLinkTrap -port_id 21 -connection $StubConnection | Set-ArubaSWSnmpLinkTrap -is_enabled -Confirm:$false -connection $StubConnection | Out-Null
        $Body.is_enabled | Should -BeTrue
    }

    It 'Set macht bei -WhatIf keinen PUT' {
        Set-ArubaSWSnmpLinkTrap -port_id 21 -is_enabled -WhatIf -connection $StubConnection
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 0 -Exactly -ParameterFilter { $method -eq 'PUT' }
    }
}

Describe 'SNMPv3 Notify-Namen, Parameter, Ziele' -Tag 'Unit' {

    BeforeEach {
        $script:Body = $null
        $script:Uri = $null
        Mock -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest {
            $res = $script:Res
            switch ($method) {
                'POST' { $script:Body = $body; $script:Uri = $uri; Get-Fixture -Resource $res -Name post-new }
                'PUT' { $script:Body = $body; $script:Uri = $uri; Get-Fixture -Resource $res -Name put-set }
                'DELETE' { $script:Uri = $uri }
                default { Get-Fixture -Resource $res -Name get-list }
            }
        }
    }

    It 'NotifyName: Get-Liste, Add (POST) und Remove (DELETE)' {
        $script:Res = 'snmpv3-notify_names'
        $r = @(Get-ArubaSWSnmpv3NotifyName -connection $StubConnection)
        @($r.notify_name) | Should -Contain 'stacktraps'
        $null = Add-ArubaSWSnmpv3NotifyName -notify_name i36notify -tagvalue i36tag -Confirm:$false -connection $StubConnection
        $Uri | Should -Be 'snmpv3/notify_names'
        $Body.notify_name | Should -Be 'i36notify'
        $Body.tagvalue | Should -Be 'i36tag'
        Remove-ArubaSWSnmpv3NotifyName -notify_name i36notify -Confirm:$false -connection $StubConnection
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 1 -Exactly -ParameterFilter { $method -eq 'DELETE' -and $uri -eq 'snmpv3/notify_names/i36notify' }
    }

    It 'Param: Add sendet die echten Feldnamen' {
        $script:Res = 'snmpv3-params'
        $null = Add-ArubaSWSnmpv3Param -parameter_name i36param -snmpv3_message_processing_model_value SMPMV_VER2C -user_name i36test -snmpv3_authentication ATV_NOAUTH -snmpv3_sec_model SSM_VER2C -Confirm:$false -connection $StubConnection
        $Uri | Should -Be 'snmpv3/params'
        $Body.parameter_name | Should -Be 'i36param'
        $Body.snmpv3_message_processing_model_value | Should -Be 'SMPMV_VER2C'
        $Body.snmpv3_sec_model | Should -Be 'SSM_VER2C'
    }

    It 'Param: Set liest zuerst (Liste enthaelt den Eintrag nicht, daher Einzelabfrage) und sendet das vollstaendige Objekt' {
        $script:Res = 'snmpv3-params'
        $null = Set-ArubaSWSnmpv3Param -parameter_name i36param -user_name i36other -Confirm:$false -connection $StubConnection
        $Uri | Should -Be 'snmpv3/params/i36param'
        $Body.user_name | Should -Be 'i36other'
        $Body.PSObject.Properties['uri'] | Should -BeNullOrEmpty
    }

    It 'Ziel: Add sendet dest_ip_address als Adressobjekt und tag_list als Array' {
        $script:Res = 'snmpv3-target_addresses'
        $null = Add-ArubaSWSnmpv3TargetAddress -target_address_name i36target -dest_ip_address 198.51.100.78 -tag_list i36tag -snmpv3_filter SF_NONE -parameter_name i36param -Confirm:$false -connection $StubConnection
        $Uri | Should -Be 'snmpv3/target_addresses'
        $Body.dest_ip_address.octets | Should -Be '198.51.100.78'
        @($Body.tag_list) | Should -Be @('i36tag')
        $Body.snmpv3_filter | Should -Be 'SF_NONE'
    }

    It 'Ziel: Set sendet tag_list als Array und behaelt die uebrigen Felder' {
        $script:Res = 'snmpv3-target_addresses'
        $null = Set-ArubaSWSnmpv3TargetAddress -target_address_name i36target -tag_list a, b -Confirm:$false -connection $StubConnection
        $Uri | Should -Be 'snmpv3/target_addresses/i36target'
        @($Body.tag_list) | Should -Be @('a', 'b')
        $Body.PSObject.Properties['uri'] | Should -BeNullOrEmpty
    }

    It '<Cmd> macht bei -WhatIf keinen schreibenden Aufruf' -ForEach @(
        @{ Cmd = 'Add-ArubaSWSnmpv3NotifyName'; Res = 'snmpv3-notify_names'; Params = @{ notify_name = 'n'; tagvalue = 't' } }
        @{ Cmd = 'Remove-ArubaSWSnmpv3NotifyName'; Res = 'snmpv3-notify_names'; Params = @{ notify_name = 'n' } }
        @{ Cmd = 'Remove-ArubaSWSnmpv3Param'; Res = 'snmpv3-params'; Params = @{ parameter_name = 'p' } }
        @{ Cmd = 'Set-ArubaSWSnmpv3Param'; Res = 'snmpv3-params'; Params = @{ parameter_name = 'p'; user_name = 'u' } }
        @{ Cmd = 'Remove-ArubaSWSnmpv3TargetAddress'; Res = 'snmpv3-target_addresses'; Params = @{ target_address_name = 't' } }
    ) {
        $script:Res = $Res
        $a = $Params
        & $Cmd @a -WhatIf -connection $StubConnection
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 0 -Exactly -ParameterFilter { $method -in 'POST', 'PUT', 'DELETE' }
    }
}

Describe 'SNMPv3 Benutzer' -Tag 'Unit' {

    BeforeEach {
        $script:Body = $null
        $script:Uri = $null
        Mock -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest {
            switch ($method) {
                'POST' { $script:Body = $body; $script:Uri = $uri; Get-Fixture -Resource snmpv3-users -Name post-new }
                'PUT' { $script:Body = $body; $script:Uri = $uri; Get-Fixture -Resource snmpv3-users -Name put-set }
                'DELETE' { $script:Uri = $uri }
                default { if ($uri -eq 'snmpv3/users') { Get-Fixture -Resource snmpv3-users -Name get-list } else { Get-Fixture -Resource snmpv3-users -Name get-item } }
            }
        }
    }

    It 'Get liefert die Liste (Benutzer initial) bzw. den einzelnen Benutzer' {
        @(Get-ArubaSWSnmpv3User -connection $StubConnection)[0].user_name | Should -Be 'initial'
        (Get-ArubaSWSnmpv3User -user_name i36user -connection $StubConnection).snmpv3_v3_group | Should -Be 'SGT_NONE'
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 1 -Exactly -ParameterFilter { $uri -eq 'snmpv3/users/i36user' }
    }

    It 'Add ohne Kennwoerter sendet nur den Namen' {
        $null = Add-ArubaSWSnmpv3User -user_name i36user -Confirm:$false -connection $StubConnection
        $Uri | Should -Be 'snmpv3/users'
        $Body.user_name | Should -Be 'i36user'
        $Body.PSObject.Properties['authentication_password'] | Should -BeNullOrEmpty
    }

    It 'Add loest SecureString-Kennwoerter fuer die Anfrage auf' {
        $pw = ConvertTo-SecureString 'dummy-wert-fuer-test' -AsPlainText -Force
        $null = Add-ArubaSWSnmpv3User -user_name i36user -snmpv3_authentication_protocol SAP_SHA -authentication_password $pw -snmpv3_authentication_privacy_protocol SAPP_AES -privacy_password $pw -Confirm:$false -connection $StubConnection
        $Body.snmpv3_authentication_protocol | Should -Be 'SAP_SHA'
        $Body.authentication_password | Should -Be 'dummy-wert-fuer-test'
        $Body.privacy_password | Should -Be 'dummy-wert-fuer-test'
    }

    It 'Add lehnt Protokolle ab, die der Switch nicht kennt (SAP_SHA1, SAPP_AES128)' {
        { Add-ArubaSWSnmpv3User -user_name u -snmpv3_authentication_protocol SAP_SHA1 -Confirm:$false -connection $StubConnection -ErrorAction Stop } |
            Should -Throw -ErrorId 'ParameterArgumentValidationError,Add-ArubaSWSnmpv3User'
        { Add-ArubaSWSnmpv3User -user_name u -snmpv3_authentication_privacy_protocol SAPP_AES128 -Confirm:$false -connection $StubConnection -ErrorAction Stop } |
            Should -Throw -ErrorId 'ParameterArgumentValidationError,Add-ArubaSWSnmpv3User'
    }

    It 'Set sendet die leeren Kennwortfelder der Antwort nicht zurueck' {
        Get-ArubaSWSnmpv3User -user_name i36user -connection $StubConnection |
            Set-ArubaSWSnmpv3User -snmpv3_v1_group SGT_NONE -Confirm:$false -connection $StubConnection | Out-Null
        $Uri | Should -Be 'snmpv3/users/i36user'
        $Body.user_name | Should -Be 'i36user'
        $Body.PSObject.Properties['authentication_password'] | Should -BeNullOrEmpty
        $Body.PSObject.Properties['privacy_password'] | Should -BeNullOrEmpty
        $Body.PSObject.Properties['uri'] | Should -BeNullOrEmpty
    }

    It 'Set sendet ein uebergebenes Kennwort mit' {
        $pw = ConvertTo-SecureString 'dummy-wert-fuer-test' -AsPlainText -Force
        $null = Set-ArubaSWSnmpv3User -user_name i36user -authentication_password $pw -snmpv3_authentication_protocol SAP_MD5 -Confirm:$false -connection $StubConnection
        $Body.authentication_password | Should -Be 'dummy-wert-fuer-test'
        $Body.snmpv3_authentication_protocol | Should -Be 'SAP_MD5'
    }

    It 'Remove sendet DELETE' {
        Get-ArubaSWSnmpv3User -user_name i36user -connection $StubConnection | Remove-ArubaSWSnmpv3User -Confirm:$false -connection $StubConnection
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 1 -Exactly -ParameterFilter { $method -eq 'DELETE' -and $uri -eq 'snmpv3/users/i36user' }
    }

    It 'Add, Set und Remove machen bei -WhatIf keinen schreibenden Aufruf' {
        Add-ArubaSWSnmpv3User -user_name u -WhatIf -connection $StubConnection
        Set-ArubaSWSnmpv3User -user_name i36user -snmpv3_v1_group SGT_NONE -WhatIf -connection $StubConnection
        Remove-ArubaSWSnmpv3User -user_name i36user -WhatIf -connection $StubConnection
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 0 -Exactly -ParameterFilter { $method -in 'POST', 'PUT', 'DELETE' }
    }
}
