#
# Copyright 2026, PowerArubaSW contributors
# SPDX-License-Identifier: Apache-2.0
#
# Unit-Tests fuer Public/VlanIpAddress.ps1 (Inkrement I38). Die Fixtures sind echte Antworten einer 2540 (YC.16.11.0010).

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

Describe 'Get-ArubaSWVlanIpAddress' -Tag 'Unit' {

    It 'ruft GET vlans/<id>/ipaddresses auf und packt die Liste aus' {
        Mock -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest { Get-Fixture -Resource vlans-ipaddresses -Name get-list }
        $r = @(Get-ArubaSWVlanIpAddress -vlan_id 701 -connection $StubConnection)
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 1 -Exactly -ParameterFilter { $method -eq 'GET' -and $uri -eq 'vlans/701/ipaddresses' }
        $r.Count | Should -Be 1
        $r[0].ip_address_mode | Should -Be 'IAAM_STATIC'
        $r[0].ip_address.octets | Should -Be '198.51.100.1'
        $r[0].ip_mask.octets | Should -Be '255.255.255.0'
    }

    It 'liefert nichts fuer ein VLAN ohne Adresse' {
        Mock -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest { Get-Fixture -Resource vlans-ipaddresses -Name get-empty }
        @(Get-ArubaSWVlanIpAddress -vlan_id 701 -connection $StubConnection).Count | Should -Be 0
    }

    It 'liefert den DHCP-Eintrag ohne Adressfelder' {
        Mock -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest { Get-Fixture -Resource vlans-ipaddresses -Name get-dhcp }
        $r = @(Get-ArubaSWVlanIpAddress -vlan_id 701 -connection $StubConnection)
        $r[0].ip_address_mode | Should -Be 'IAAM_DHCP'
        $r[0].PSObject.Properties['ip_address'] | Should -BeNullOrEmpty
    }

    It 'nimmt vlan_id aus der Pipeline' {
        Mock -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest { Get-Fixture -Resource vlans-ipaddresses -Name get-list }
        [pscustomobject]@{ vlan_id = 701 } | Get-ArubaSWVlanIpAddress -connection $StubConnection | Out-Null
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 1 -Exactly -ParameterFilter { $uri -eq 'vlans/701/ipaddresses' }
    }

    It 'prueft den VLAN-Bereich' {
        { Get-ArubaSWVlanIpAddress -vlan_id 5000 -connection $StubConnection -ErrorAction Stop } |
            Should -Throw -ErrorId 'ParameterArgumentValidationError,Get-ArubaSWVlanIpAddress'
    }
}

Describe 'Add-ArubaSWVlanIpAddress' -Tag 'Unit' {

    BeforeEach {
        $script:Body = $null
        $script:Uri = $null
        Mock -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest {
            $script:Body = $body
            $script:Uri = $uri
            Get-Fixture -Resource vlans-ipaddresses -Name post-static
        }
    }

    It 'sendet POST mit vlan_id im Body (der Switch verlangt es), Modus, Adresse und Maske' {
        $r = Add-ArubaSWVlanIpAddress -vlan_id 701 -ip_address 198.51.100.1 -ip_mask 255.255.255.0 -Confirm:$false -connection $StubConnection
        $Uri | Should -Be 'vlans/701/ipaddresses'
        $Body.vlan_id | Should -Be 701
        $Body.ip_address_mode | Should -Be 'IAAM_STATIC'
        $Body.ip_address.version | Should -Be 'IAV_IP_V4'
        $Body.ip_address.octets | Should -Be '198.51.100.1'
        $Body.ip_mask.octets | Should -Be '255.255.255.0'
        $r.uri | Should -Be '/vlans/701/ipaddresses/IAAM_STATIC-198.51.100.1'
    }

    It 'rechnet -prefix_length in die Maske um' -ForEach @(
        @{ Prefix = 24; Mask = '255.255.255.0' }
        @{ Prefix = 22; Mask = '255.255.252.0' }
        @{ Prefix = 30; Mask = '255.255.255.252' }
        @{ Prefix = 8; Mask = '255.0.0.0' }
        @{ Prefix = 32; Mask = '255.255.255.255' }
        @{ Prefix = 1; Mask = '128.0.0.0' }
    ) {
        $null = Add-ArubaSWVlanIpAddress -vlan_id 701 -ip_address 198.51.100.1 -prefix_length $Prefix -Confirm:$false -connection $StubConnection
        $Body.ip_mask.octets | Should -Be $Mask
    }

    It '-dhcp sendet IAAM_DHCP ohne Adressfelder' {
        $null = Add-ArubaSWVlanIpAddress -vlan_id 701 -dhcp -Confirm:$false -connection $StubConnection
        $Body.ip_address_mode | Should -Be 'IAAM_DHCP'
        $Body.vlan_id | Should -Be 701
        $Body.PSObject.Properties['ip_address'] | Should -BeNullOrEmpty
        $Body.PSObject.Properties['ip_mask'] | Should -BeNullOrEmpty
    }

    It 'prueft Praefixlaenge und VLAN-Bereich' {
        { Add-ArubaSWVlanIpAddress -vlan_id 701 -ip_address 198.51.100.1 -prefix_length 33 -Confirm:$false -connection $StubConnection -ErrorAction Stop } |
            Should -Throw -ErrorId 'ParameterArgumentValidationError,Add-ArubaSWVlanIpAddress'
        { Add-ArubaSWVlanIpAddress -vlan_id 0 -dhcp -Confirm:$false -connection $StubConnection -ErrorAction Stop } |
            Should -Throw -ErrorId 'ParameterArgumentValidationError,Add-ArubaSWVlanIpAddress'
    }

    It 'verlangt Maske oder Praefix zur Adresse (Parametersaetze)' {
        $sets = (Get-Command Add-ArubaSWVlanIpAddress).ParameterSets.Name
        $sets | Should -Contain 'mask'
        $sets | Should -Contain 'prefix'
        $sets | Should -Contain 'dhcp'
    }

    It 'macht bei -WhatIf keinen Aufruf' {
        Add-ArubaSWVlanIpAddress -vlan_id 701 -ip_address 198.51.100.1 -ip_mask 255.255.255.0 -WhatIf -connection $StubConnection
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 0 -Exactly
    }
}

Describe 'Remove-ArubaSWVlanIpAddress' -Tag 'Unit' {

    BeforeEach {
        Mock -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest { }
    }

    It 'sendet DELETE auf IAAM_STATIC-<ip>' {
        Remove-ArubaSWVlanIpAddress -vlan_id 701 -ip_address 198.51.100.1 -Confirm:$false -connection $StubConnection
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 1 -Exactly -ParameterFilter { $method -eq 'DELETE' -and $uri -eq 'vlans/701/ipaddresses/IAAM_STATIC-198.51.100.1' }
    }

    It '-dhcp sendet DELETE auf IAAM_DHCP-0.0.0.0' {
        Remove-ArubaSWVlanIpAddress -vlan_id 701 -dhcp -Confirm:$false -connection $StubConnection
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 1 -Exactly -ParameterFilter { $method -eq 'DELETE' -and $uri -eq 'vlans/701/ipaddresses/IAAM_DHCP-0.0.0.0' }
    }

    It 'nimmt das Objekt aus Get-ArubaSWVlanIpAddress aus der Pipeline (statisch und DHCP)' {
        Mock -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest { Get-Fixture -Resource vlans-ipaddresses -Name get-list }
        Get-ArubaSWVlanIpAddress -vlan_id 701 -connection $StubConnection | Remove-ArubaSWVlanIpAddress -Confirm:$false -connection $StubConnection
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 1 -Exactly -ParameterFilter { $method -eq 'DELETE' -and $uri -eq 'vlans/701/ipaddresses/IAAM_STATIC-198.51.100.1' }
        Mock -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest { Get-Fixture -Resource vlans-ipaddresses -Name get-dhcp }
        Get-ArubaSWVlanIpAddress -vlan_id 701 -connection $StubConnection | Remove-ArubaSWVlanIpAddress -Confirm:$false -connection $StubConnection
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 1 -Exactly -ParameterFilter { $method -eq 'DELETE' -and $uri -eq 'vlans/701/ipaddresses/IAAM_DHCP-0.0.0.0' }
    }

    It 'macht bei -WhatIf keinen Aufruf' {
        Remove-ArubaSWVlanIpAddress -vlan_id 701 -ip_address 198.51.100.1 -WhatIf -connection $StubConnection
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 0 -Exactly
    }
}
