#
# Copyright 2026, PowerArubaSW contributors
# SPDX-License-Identifier: Apache-2.0
#
# Unit-Tests fuer Public/IpRoute.ps1 (Inkrement I40). Die Fixtures sind echte Antworten einer 2540 (YC.16.11.0010).

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

Describe 'Get-ArubaSWIpRoute' -Tag 'Unit' {

    It 'packt die Liste aus' {
        Mock -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest { Get-Fixture -Resource ip-route -Name get-list }
        $r = @(Get-ArubaSWIpRoute -connection $StubConnection)
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 1 -Exactly -ParameterFilter { $method -eq 'GET' -and $uri -eq 'ip-route' }
        $r.Count | Should -Be 2
        $r[0].ip_route_mode | Should -Be 'IRM_GATEWAY'
        $r[0].gateway.octets | Should -Be '198.51.100.254'
    }

    It 'liefert mit -id die einzelne Route' {
        Mock -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest { Get-Fixture -Resource ip-route -Name get-item }
        $id = '203.0.113.0-255.255.255.0-IRM_GATEWAY-198.51.100.254'
        $r = Get-ArubaSWIpRoute -id $id -connection $StubConnection
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 1 -Exactly -ParameterFilter { $method -eq 'GET' -and $uri -eq "ip-route/$id" }
        $r.id | Should -Be $id
    }
}

Describe 'Add-ArubaSWIpRoute' -Tag 'Unit' {

    BeforeEach {
        $script:Body = $null
        $script:PostUri = $null
        Mock -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest {
            $script:Body = $body
            $script:PostUri = $uri
            Get-Fixture -Resource ip-route -Name post-gateway
        }
    }

    It 'sendet POST mit destination, mask, ip_route_mode IRM_GATEWAY und gateway' {
        $r = Add-ArubaSWIpRoute -destination 203.0.113.0 -mask 255.255.255.0 -gateway 198.51.100.254 -Confirm:$false -connection $StubConnection
        $PostUri | Should -Be 'ip-route'
        $Body.destination.version | Should -Be 'IAV_IP_V4'
        $Body.destination.octets | Should -Be '203.0.113.0'
        $Body.mask.octets | Should -Be '255.255.255.0'
        $Body.ip_route_mode | Should -Be 'IRM_GATEWAY'
        $Body.gateway.octets | Should -Be '198.51.100.254'
        $Body.PSObject.Properties['metric'] | Should -BeNullOrEmpty
        $r.id | Should -Be '203.0.113.0-255.255.255.0-IRM_GATEWAY-198.51.100.254'
    }

    It 'rechnet -prefix_length in die Maske um' -ForEach @(
        @{ Prefix = 0; Mask = '0.0.0.0' }
        @{ Prefix = 8; Mask = '255.0.0.0' }
        @{ Prefix = 22; Mask = '255.255.252.0' }
        @{ Prefix = 24; Mask = '255.255.255.0' }
        @{ Prefix = 32; Mask = '255.255.255.255' }
    ) {
        $null = Add-ArubaSWIpRoute -destination 203.0.113.0 -prefix_length $Prefix -gateway 198.51.100.254 -Confirm:$false -connection $StubConnection
        $Body.mask.octets | Should -Be $Mask
    }

    It '-reject sendet IRM_REJECT ohne gateway' {
        $null = Add-ArubaSWIpRoute -destination 203.0.116.0 -prefix_length 24 -reject -Confirm:$false -connection $StubConnection
        $Body.ip_route_mode | Should -Be 'IRM_REJECT'
        $Body.PSObject.Properties['gateway'] | Should -BeNullOrEmpty
    }

    It 'sendet metric, distance, name und tag nur, wenn sie angegeben sind' {
        $null = Add-ArubaSWIpRoute -destination 203.0.114.0 -mask 255.255.255.0 -gateway 198.51.100.254 -metric 5 -distance 20 -name i40 -tag 7 -Confirm:$false -connection $StubConnection
        $Body.metric | Should -Be 5
        $Body.distance | Should -Be 20
        $Body.name | Should -Be 'i40'
        $Body.tag | Should -Be 7
    }

    It 'verlangt genau eines von -gateway und -reject' {
        { Add-ArubaSWIpRoute -destination 203.0.113.0 -prefix_length 24 -Confirm:$false -connection $StubConnection } | Should -Throw -ExpectedMessage '*either -gateway or -reject*'
        { Add-ArubaSWIpRoute -destination 203.0.113.0 -prefix_length 24 -gateway 198.51.100.254 -reject -Confirm:$false -connection $StubConnection } | Should -Throw -ExpectedMessage '*either -gateway or -reject*'
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 0 -Exactly
    }

    It 'prueft Praefixlaenge, Metrik und Distanz' {
        { Add-ArubaSWIpRoute -destination 203.0.113.0 -prefix_length 33 -reject -Confirm:$false -connection $StubConnection -ErrorAction Stop } |
            Should -Throw -ErrorId 'ParameterArgumentValidationError,Add-ArubaSWIpRoute'
        { Add-ArubaSWIpRoute -destination 203.0.113.0 -prefix_length 24 -reject -metric 0 -Confirm:$false -connection $StubConnection -ErrorAction Stop } |
            Should -Throw -ErrorId 'ParameterArgumentValidationError,Add-ArubaSWIpRoute'
    }

    It 'macht bei -WhatIf keinen Aufruf' {
        Add-ArubaSWIpRoute -destination 203.0.113.0 -prefix_length 24 -reject -WhatIf -connection $StubConnection
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 0 -Exactly
    }
}

Describe 'Add-ArubaSWIpRoute (Reject-Antwort)' -Tag 'Unit' {
    It 'liefert die Antwort mit gateway null' {
        Mock -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest { Get-Fixture -Resource ip-route -Name post-reject }
        $r = Add-ArubaSWIpRoute -destination 203.0.116.0 -prefix_length 24 -reject -Confirm:$false -connection $StubConnection
        $r.ip_route_mode | Should -Be 'IRM_REJECT'
        $r.gateway | Should -BeNullOrEmpty
    }
}

Describe 'Remove-ArubaSWIpRoute' -Tag 'Unit' {

    BeforeEach {
        Mock -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest { }
    }

    It 'sendet DELETE auf ip-route/<id>' {
        Remove-ArubaSWIpRoute -id 203.0.113.0-255.255.255.0-IRM_GATEWAY-198.51.100.254 -Confirm:$false -connection $StubConnection
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 1 -Exactly -ParameterFilter { $method -eq 'DELETE' -and $uri -eq 'ip-route/203.0.113.0-255.255.255.0-IRM_GATEWAY-198.51.100.254' }
    }

    It 'nimmt die Route aus Get-ArubaSWIpRoute aus der Pipeline' {
        Mock -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest { Get-Fixture -Resource ip-route -Name get-list }
        Get-ArubaSWIpRoute -connection $StubConnection | Where-Object { $_.destination.octets -eq '0.0.0.0' } | Remove-ArubaSWIpRoute -Confirm:$false -connection $StubConnection
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 1 -Exactly -ParameterFilter { $method -eq 'DELETE' -and $uri -eq 'ip-route/0.0.0.0-0.0.0.0-IRM_GATEWAY-198.51.100.254' }
    }

    It 'macht bei -WhatIf keinen Aufruf' {
        Remove-ArubaSWIpRoute -id x -WhatIf -connection $StubConnection
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 0 -Exactly
    }
}

Describe 'IpRouteSettings' -Tag 'Unit' {

    BeforeEach {
        $script:Body = $null
        Mock -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest {
            if ($method -eq 'PUT') { $script:Body = $body; Get-Fixture -Resource ip-route-settings -Name put-item }
            else { Get-Fixture -Resource ip-route-settings -Name get-item }
        }
    }

    It 'Get-ArubaSWIpRouteSettings liefert die echten Feldnamen (ohne d)' {
        $r = Get-ArubaSWIpRouteSettings -connection $StubConnection
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 1 -Exactly -ParameterFilter { $method -eq 'GET' -and $uri -eq 'ip-route/settings' }
        $r.is_ip_routing_enable | Should -BeTrue
        $r.is_ip_source_routing_enable | Should -BeTrue
    }

    It 'Set-ArubaSWIpRouteSettings sendet das vollstaendige Objekt ohne uri und aendert nur das Genannte' {
        $null = Set-ArubaSWIpRouteSettings -is_ip_source_routing_enable:$false -Confirm:$false -connection $StubConnection
        $Body.is_ip_source_routing_enable | Should -BeFalse
        $Body.is_ip_source_routing_enable | Should -BeOfType [bool]
        $Body.is_ip_routing_enable | Should -BeTrue
        $Body.PSObject.Properties['uri'] | Should -BeNullOrEmpty
    }

    It 'macht bei -WhatIf keinen PUT' {
        Set-ArubaSWIpRouteSettings -is_ip_routing_enable:$false -WhatIf -connection $StubConnection
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 0 -Exactly -ParameterFilter { $method -eq 'PUT' }
    }
}
