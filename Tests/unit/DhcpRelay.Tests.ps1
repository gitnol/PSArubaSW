#
# Copyright 2026, PowerArubaSW contributors
# SPDX-License-Identifier: Apache-2.0
#
# Unit-Tests fuer Public/DhcpRelay.ps1 (Inkrement I18).
# Refactor in der I18-Reflexion (2026-05-31): Get-Fixture-Loader statt
# direktem Get-Content; Should -Invoke (Pester 5) statt Assert-MockCalled
# (Pester 4); BeforeEach-Mock-Setup; -Tag 'Unit'; WhatIf-Tests pro Set-Cmdlet;
# Trailing-Whitespace entfernt. Strukturell jetzt parallel zu Sntp/Cdp/Vlans.Tests.

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

Describe 'Get-ArubaSWDhcpRelay' -Tag 'Unit' {

    BeforeEach {
        Mock -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest {
            Get-Fixture -Resource dhcp-relay -Name get-default
        }
    }

    It 'ruft GET dhcp-relay ueber den Transport-Wrapper' {
        $r = Get-ArubaSWDhcpRelay -connection $StubConnection
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 1 -Exactly `
            -ParameterFilter { $method -eq 'GET' -and $uri -eq 'dhcp-relay' }
        $r.is_dhcp_relay_enabled | Should -BeFalse
    }
}

Describe 'Set-ArubaSWDhcpRelay' -Tag 'Unit' {

    BeforeEach {
        $script:CapturedBody = $null
        Mock -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest {
            $script:CapturedBody = $body
            Get-Fixture -Resource dhcp-relay -Name put-enabled
        }
    }

    It 'ruft PUT dhcp-relay mit is_dhcp_relay_enabled=$true im Body' {
        $r = Set-ArubaSWDhcpRelay -is_dhcp_relay_enabled -Confirm:$false -connection $StubConnection
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 1 -Exactly `
            -ParameterFilter { $method -eq 'PUT' -and $uri -eq 'dhcp-relay' }
        $CapturedBody.is_dhcp_relay_enabled | Should -BeTrue
        $r.is_dhcp_relay_enabled | Should -BeTrue
    }

    It 'macht KEINEN Aufruf bei -WhatIf' {
        Set-ArubaSWDhcpRelay -is_dhcp_relay_enabled -WhatIf -connection $StubConnection
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 0 -Exactly
    }
}

Describe 'Get-ArubaSWDhcpRelayOption82' -Tag 'Unit' {

    BeforeEach {
        Mock -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest {
            Get-Fixture -Resource dhcp-relay_option82 -Name get-default
        }
    }

    It 'ruft GET dhcp-relay/option_82 ueber den Transport-Wrapper' {
        $r = Get-ArubaSWDhcpRelayOption82 -connection $StubConnection
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 1 -Exactly `
            -ParameterFilter { $method -eq 'GET' -and $uri -eq 'dhcp-relay/option_82' }
        $r.is_option82_enabled | Should -BeFalse
        $r.dhcp_relay_action   | Should -Be 'DRO82A_REPLACE'
        $r.dhcp_relay_remote_id | Should -Be 'DRO82RI_MAC'
    }
}

Describe 'Set-ArubaSWDhcpRelayOption82' -Tag 'Unit' {

    BeforeEach {
        $script:CapturedBody = $null
        Mock -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest {
            $script:CapturedBody = $body
            Get-Fixture -Resource dhcp-relay_option82 -Name put-enabled
        }
    }

    It 'sendet is_option82_enabled und die echten Felder im Body' {
        $r = Set-ArubaSWDhcpRelayOption82 -is_option82_enabled -dhcp_relay_action 'DRO82A_REPLACE' -dhcp_relay_remote_id 'DRO82RI_MAC' -is_validation_enabled `
            -Confirm:$false -connection $StubConnection
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 1 -Exactly `
            -ParameterFilter { $method -eq 'PUT' -and $uri -eq 'dhcp-relay/option_82' }
        $CapturedBody.is_option82_enabled  | Should -BeTrue
        $CapturedBody.dhcp_relay_action    | Should -Be 'DRO82A_REPLACE'
        $CapturedBody.dhcp_relay_remote_id | Should -Be 'DRO82RI_MAC'
        $CapturedBody.is_validation_enabled | Should -BeTrue
        $r.is_option82_enabled | Should -BeTrue
    }

    It 'sendet is_option82_enabled immer mit (der Switch verlangt es in jedem PUT)' {
        $null = Set-ArubaSWDhcpRelayOption82 -is_option82_enabled:$false -Confirm:$false -connection $StubConnection
        @($CapturedBody.PSObject.Properties.Name) | Should -Be @('is_option82_enabled')
        $CapturedBody.is_option82_enabled | Should -BeFalse
    }

    It 'verlangt is_option82_enabled (Mandatory) und kennt -option82_policy nicht mehr' {
        # Metadaten statt Aufruf: ein Aufruf ohne Pflichtparameter wuerde in einer interaktiven Sitzung nachfragen.
        $cmd = Get-Command Set-ArubaSWDhcpRelayOption82
        $param = $cmd.Parameters['is_option82_enabled']
        ($param.Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] }).Mandatory | Should -BeTrue
        $cmd.Parameters.ContainsKey('option82_policy') | Should -BeFalse
    }

    It 'lehnt Werte ausserhalb der vom Switch erlaubten ab (Aktion, Remote-ID)' {
        { Set-ArubaSWDhcpRelayOption82 -is_option82_enabled -dhcp_relay_action 'BOGUS' -Confirm:$false -connection $StubConnection -ErrorAction Stop } |
            Should -Throw -ErrorId 'ParameterArgumentValidationError,Set-ArubaSWDhcpRelayOption82'
        { Set-ArubaSWDhcpRelayOption82 -is_option82_enabled -dhcp_relay_remote_id 'DRO82RI_VLAN' -Confirm:$false -connection $StubConnection -ErrorAction Stop } |
            Should -Throw -ErrorId 'ParameterArgumentValidationError,Set-ArubaSWDhcpRelayOption82'
    }

    It 'macht KEINEN Aufruf bei -WhatIf' {
        Set-ArubaSWDhcpRelayOption82 -is_option82_enabled -WhatIf -connection $StubConnection
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 0 -Exactly
    }
}

Describe 'Get-ArubaSWDhcpRelayVlan' -Tag 'Unit' {

    BeforeEach {
        Mock -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest {
            Get-Fixture -Resource vlans-dhcp-relay -Name get-default
        }
    }

    It 'ruft GET vlans/{id}/dhcp-relay mit der gegebenen ID auf' {
        $r = Get-ArubaSWDhcpRelayVlan -vlan_id 1 -connection $StubConnection
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 1 -Exactly `
            -ParameterFilter { $method -eq 'GET' -and $uri -eq 'vlans/1/dhcp-relay' }
        $r.vlan_id | Should -Be 1
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 1 -Exactly -ParameterFilter { $api_version -eq 3 }
    }

    It 'verlangt -vlan_id (Mandatory)' {
        { Get-ArubaSWDhcpRelayVlan -connection $StubConnection -ErrorAction Stop } |
            Should -Throw -ErrorId 'MissingMandatoryParameter,Get-ArubaSWDhcpRelayVlan'
    }
}

Describe 'Set-ArubaSWDhcpRelayVlan' -Tag 'Unit' {

    BeforeEach {
        $script:CapturedBody = $null
        $script:CapturedUri  = $null
        Mock -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest {
            $script:CapturedBody = $body
            $script:CapturedUri  = $uri
            Get-Fixture -Resource vlans-dhcp-relay -Name put-set
        }
    }

    It 'baut URI vlans/<id>/dhcp-relay und sendet dhcp_helper_addresses als Adressobjekte (REST v3)' {
        $r = Set-ArubaSWDhcpRelayVlan -vlan_id 1 `
            -helper_addresses @('198.51.100.10', '198.51.100.11') `
            -Confirm:$false -connection $StubConnection
        $CapturedUri | Should -Be 'vlans/1/dhcp-relay'
        $CapturedBody.vlan_id | Should -Be 1
        $CapturedBody.dhcp_helper_addresses.Count | Should -Be 2
        $CapturedBody.dhcp_helper_addresses[0].version | Should -Be 'IAV_IP_V4'
        $CapturedBody.dhcp_helper_addresses[0].octets | Should -Be '198.51.100.10'
        $r.dhcp_helper_addresses.Count | Should -Be 2
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 1 -Exactly -ParameterFilter { $api_version -eq 3 }
    }

    It 'akzeptiert ein leeres Array (entfernt alle Helper-Adressen)' {
        Set-ArubaSWDhcpRelayVlan -vlan_id 1 -helper_addresses @() -Confirm:$false -connection $StubConnection
        @($CapturedBody.dhcp_helper_addresses).Count | Should -Be 0
    }

    It 'akzeptiert ein VLAN-Objekt aus der Pipeline (ValueFromPipelineByPropertyName)' {
        $vlan = [PSCustomObject]@{ vlan_id = 1 }
        $vlan | Set-ArubaSWDhcpRelayVlan -helper_addresses @('198.51.100.10') `
            -Confirm:$false -connection $StubConnection
        $CapturedUri | Should -Be 'vlans/1/dhcp-relay'
    }

    It 'macht KEINEN Aufruf bei -WhatIf' {
        Set-ArubaSWDhcpRelayVlan -vlan_id 1 -helper_addresses @('198.51.100.10') `
            -WhatIf -connection $StubConnection
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 0 -Exactly
    }
}
