#
# Copyright 2026, PowerArubaSW contributors
# SPDX-License-Identifier: Apache-2.0
#
# Unit-Tests fuer die Portspiegelung in Public/Transceiver.ps1 (Inkrement I44). Die Fixtures sind echte Antworten einer 2540 (YC.16.11.0010).

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

Describe 'Get-ArubaSWPortMirror' -Tag 'Unit' {

    It 'packt die Liste aus und liefert destination_port_id und source_port_id' {
        Mock -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest { Get-Fixture -Resource port-mirror -Name get-list }
        $r = @(Get-ArubaSWPortMirror -connection $StubConnection)
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 1 -Exactly -ParameterFilter { $method -eq 'GET' -and $uri -eq 'port-mirror' }
        $r.Count | Should -Be 1
        $r[0].destination_port_id | Should -Be '22'
        @($r[0].source_port_id) | Should -Be @('21', '23')
    }

    It 'liefert mit -session_id die einzelne Session' {
        Mock -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest { Get-Fixture -Resource port-mirror -Name get-item }
        $r = Get-ArubaSWPortMirror -session_id 0 -connection $StubConnection
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 1 -Exactly -ParameterFilter { $method -eq 'GET' -and $uri -eq 'port-mirror/0' }
        $r.session_id | Should -Be 0
    }
}

Describe 'Add-ArubaSWPortMirror' -Tag 'Unit' {

    BeforeEach {
        $script:Body = $null
        $script:PostUri = $null
        Mock -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest {
            $script:Body = $body
            $script:PostUri = $uri
            Get-Fixture -Resource port-mirror -Name post-session
        }
    }

    It 'sendet POST mit session_id 0, destination_port_id als String und source_port_id als Array' {
        $r = Add-ArubaSWPortMirror -destination_port_id 22 -source_port_id 21, 23 -Confirm:$false -connection $StubConnection
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 1 -Exactly -ParameterFilter { $method -eq 'POST' }
        $PostUri | Should -Be 'port-mirror'
        $Body.session_id | Should -Be 0
        $Body.destination_port_id | Should -Be '22'
        $Body.destination_port_id | Should -BeOfType [string]
        @($Body.source_port_id) | Should -Be @('21', '23')
        $r.uri | Should -Be '/port-mirror/0'
    }

    It 'bleibt auch mit nur einem Quellport ein Array im JSON' {
        $null = Add-ArubaSWPortMirror -destination_port_id 22 -source_port_id 21 -Confirm:$false -connection $StubConnection
        ($Body | ConvertTo-Json -Compress) | Should -Match '"source_port_id":\["21"\]'
    }

    It 'erlaubt eine leere Quellliste (Session nur mit Zielport)' {
        $null = Add-ArubaSWPortMirror -destination_port_id 22 -source_port_id @() -Confirm:$false -connection $StubConnection
        @($Body.source_port_id).Count | Should -Be 0
        ($Body | ConvertTo-Json -Compress) | Should -Match '"source_port_id":\[\]'
    }

    It 'prueft den Bereich von -session_id' {
        { Add-ArubaSWPortMirror -destination_port_id 22 -source_port_id 21 -session_id 5 -Confirm:$false -connection $StubConnection -ErrorAction Stop } |
            Should -Throw -ErrorId 'ParameterArgumentValidationError,Add-ArubaSWPortMirror'
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 0 -Exactly
    }

    It 'macht bei -WhatIf keinen Aufruf' {
        Add-ArubaSWPortMirror -destination_port_id 22 -source_port_id 21 -WhatIf -connection $StubConnection
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 0 -Exactly
    }
}

Describe 'Set-ArubaSWPortMirror' -Tag 'Unit' {

    BeforeEach {
        $script:Body = $null
        $script:PutUri = $null
        Mock -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest {
            if ($method -eq 'PUT') {
                $script:Body = $body
                $script:PutUri = $uri
                Get-Fixture -Resource port-mirror -Name put-item
            }
            else { Get-Fixture -Resource port-mirror -Name get-item }
        }
    }

    It 'sendet das vollstaendige Objekt ohne uri mit den neuen Quellports' {
        $null = Set-ArubaSWPortMirror -source_port_id 21 -Confirm:$false -connection $StubConnection
        $PutUri | Should -Be 'port-mirror/0'
        @($Body.source_port_id) | Should -Be @('21')
        $Body.destination_port_id | Should -Be '22'
        $Body.session_id | Should -Be 0
        $Body.PSObject.Properties['uri'] | Should -BeNullOrEmpty
        ($Body | ConvertTo-Json -Compress) | Should -Match '"source_port_id":\["21"\]'
    }

    It 'leert mit einer leeren Liste die Quellports' {
        $null = Set-ArubaSWPortMirror -source_port_id @() -Confirm:$false -connection $StubConnection
        ($Body | ConvertTo-Json -Compress) | Should -Match '"source_port_id":\[\]'
    }

    It 'macht bei -WhatIf keinen PUT' {
        Set-ArubaSWPortMirror -source_port_id 21 -WhatIf -connection $StubConnection
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 0 -Exactly -ParameterFilter { $method -eq 'PUT' }
    }
}

Describe 'Remove-ArubaSWPortMirror' -Tag 'Unit' {

    BeforeEach {
        Mock -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest { }
    }

    It 'sendet DELETE auf port-mirror/0' {
        Remove-ArubaSWPortMirror -Confirm:$false -connection $StubConnection
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 1 -Exactly -ParameterFilter { $method -eq 'DELETE' -and $uri -eq 'port-mirror/0' }
    }

    It 'nimmt die Session aus Get-ArubaSWPortMirror aus der Pipeline' {
        Mock -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest { Get-Fixture -Resource port-mirror -Name get-list }
        Get-ArubaSWPortMirror -connection $StubConnection | Remove-ArubaSWPortMirror -Confirm:$false -connection $StubConnection
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 1 -Exactly -ParameterFilter { $method -eq 'DELETE' -and $uri -eq 'port-mirror/0' }
    }

    It 'macht bei -WhatIf keinen Aufruf' {
        Remove-ArubaSWPortMirror -WhatIf -connection $StubConnection
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 0 -Exactly
    }
}
