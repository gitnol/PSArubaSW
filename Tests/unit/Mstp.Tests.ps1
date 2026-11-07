#
# Copyright 2026, PowerArubaSW contributors
# SPDX-License-Identifier: Apache-2.0
#
# Unit-Tests fuer Public/Mstp.ps1 (Inkrement I20).
# Strukturell ein Klon von Sntp.Tests.ps1 (BeforeAll-Bootstrap + Get-Fixture-
# Loader + BeforeEach-Mocks + Should -Invoke + CapturedBody-Verifikation).
# Ueberschneidende Patterns: global Get+Set, Collection-Get-mit-optionalem-
# Filter, Pipeline-Input via ValueFromPipelineByPropertyName.

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

Describe 'Get-ArubaSWMstp' -Tag 'Unit' {

    BeforeEach {
        Mock -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest {
            Get-Fixture -Resource mstp -Name get-default
        }
    }

    It 'ruft GET mstp ueber den Transport-Wrapper' {
        $null = Get-ArubaSWMstp -connection $StubConnection
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 1 -Exactly `
            -ParameterFilter { $method -eq 'GET' -and $uri -eq 'mstp' }
    }

    It 'parst die globalen Felder' {
        $r = Get-ArubaSWMstp -connection $StubConnection
        $r.is_mstp_enabled  | Should -BeFalse
        $r.region_revision  | Should -Be 0
        $r.max_hops         | Should -Be 20
    }
}

Describe 'Set-ArubaSWMstp' -Tag 'Unit' {

    BeforeEach {
        $script:CapturedBody = $null
        Mock -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest {
            $script:CapturedBody = $body
            Get-Fixture -Resource mstp -Name put-enabled
        }
    }

    It 'sendet nur explizit gesetzte Felder im Body (partial-update)' {
        $null = Set-ArubaSWMstp -is_mstp_enabled -Confirm:$false -connection $StubConnection
        $CapturedBody.is_mstp_enabled | Should -BeTrue
        $CapturedBody.PSObject.Properties.Name | Should -Not -Contain 'region_name'
        $CapturedBody.PSObject.Properties.Name | Should -Not -Contain 'max_hops'
    }

    It 'akzeptiert region_name, region_revision und max_hops gemeinsam' {
        $null = Set-ArubaSWMstp -region_name 'CORE' -region_revision 1 -max_hops 20 `
            -Confirm:$false -connection $StubConnection
        $CapturedBody.region_name     | Should -Be 'CORE'
        $CapturedBody.region_revision | Should -Be 1
        $CapturedBody.max_hops        | Should -Be 20
    }

    It 'lehnt max_hops ausserhalb 1..40 ab (ValidateRange)' {
        { Set-ArubaSWMstp -max_hops 0 -Confirm:$false -connection $StubConnection -ErrorAction Stop } |
            Should -Throw -ErrorId 'ParameterArgumentValidationError,Set-ArubaSWMstp'
        { Set-ArubaSWMstp -max_hops 41 -Confirm:$false -connection $StubConnection -ErrorAction Stop } |
            Should -Throw -ErrorId 'ParameterArgumentValidationError,Set-ArubaSWMstp'
    }

    It 'macht KEINEN Aufruf bei -WhatIf' {
        Set-ArubaSWMstp -is_mstp_enabled -WhatIf -connection $StubConnection
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 0 -Exactly
    }
}

Describe 'Get-ArubaSWMstpPort' -Tag 'Unit' {

    Context 'ohne -port_id (List-Modus)' {
        BeforeEach {
            Mock -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest {
                Get-Fixture -Resource mstp-port -Name get-default
            }
        }

        It 'ruft GET mstp/port auf und unwrapt mstp_port_element' {
            $r = @(Get-ArubaSWMstpPort -connection $StubConnection)
            Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 1 -Exactly `
                -ParameterFilter { $method -eq 'GET' -and $uri -eq 'mstp/port' }
            $r.Count           | Should -Be 2
            $r[0].id           | Should -Be '1'
            $r[1].root_guard   | Should -Be 'true'
        }
    }

    Context 'mit -port_id (Single-Port-Modus)' {
        BeforeEach {
            Mock -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest {
                Get-Fixture -Resource mstp-port -Name get-port5
            }
        }

        It 'ruft GET mstp/port/<id> auf' {
            $r = Get-ArubaSWMstpPort -port_id 5 -connection $StubConnection
            Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 1 -Exactly `
                -ParameterFilter { $method -eq 'GET' -and $uri -eq 'mstp/port/5' }
            $r.id            | Should -Be '5'
            $r.admin_status  | Should -Be 'true'
        }
    }
}

Describe 'Set-ArubaSWMstpPort (echte Felder id, admin_status, root_guard)' -Tag 'Unit' {

    BeforeEach {
        $script:CapturedBody = $null
        $script:CapturedUri  = $null
        $script:PutCount     = 0
        Mock -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -ParameterFilter { $method -eq 'GET' } {
            Get-Fixture -Resource mstp-port -Name get-port5
        }
        Mock -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -ParameterFilter { $method -eq 'PUT' } {
            $script:CapturedBody = $body
            $script:CapturedUri  = $uri
            $script:PutCount++
            Get-Fixture -Resource mstp-port -Name put-port5
        }
    }

    It 'baut URI mstp/port/<id> und sendet id, admin_status und root_guard als echte Booleans' {
        $null = Set-ArubaSWMstpPort -port_id 5 -admin_status -root_guard -Confirm:$false -connection $StubConnection
        $CapturedUri | Should -Be 'mstp/port/5'
        $CapturedBody.id | Should -Be '5'
        $CapturedBody.admin_status | Should -BeOfType [bool]
        $CapturedBody.root_guard   | Should -BeOfType [bool]
        $CapturedBody.admin_status | Should -BeTrue
        $CapturedBody.root_guard   | Should -BeTrue
        @($CapturedBody.PSObject.Properties.Name | Sort-Object) | Should -Be @('admin_status', 'id', 'root_guard')
    }

    It 'fuellt ein nicht angegebenes Feld aus dem aktuellen Zustand des Ports (Switch verlangt beide)' {
        # Fixture get-port5: admin_status "true", root_guard "false"
        $null = Set-ArubaSWMstpPort -port_id 5 -root_guard -Confirm:$false -connection $StubConnection
        $CapturedBody.admin_status | Should -BeTrue
        $CapturedBody.root_guard   | Should -BeTrue
        $null = Set-ArubaSWMstpPort -port_id 5 -admin_status:$false -Confirm:$false -connection $StubConnection
        $CapturedBody.admin_status | Should -BeFalse
        $CapturedBody.root_guard   | Should -BeFalse
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 2 -Exactly -ParameterFilter { $method -eq 'GET' -and $uri -eq 'mstp/port/5' }
    }

    It 'liest den Port nicht, wenn beide Felder angegeben sind' {
        $null = Set-ArubaSWMstpPort -port_id 5 -admin_status:$false -root_guard:$false -Confirm:$false -connection $StubConnection
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 0 -Exactly -ParameterFilter { $method -eq 'GET' }
        $CapturedBody.admin_status | Should -BeFalse
        $CapturedBody.root_guard   | Should -BeFalse
    }

    It 'akzeptiert die Antwort des Switches aus der Pipeline (Eigenschaft id)' {
        $port = [PSCustomObject]@{ uri = '/mstp/port/7'; id = '7'; admin_status = 'false'; root_guard = 'false' }
        $port | Set-ArubaSWMstpPort -root_guard -Confirm:$false -connection $StubConnection
        $CapturedUri | Should -Be 'mstp/port/7'
        $CapturedBody.id | Should -Be '7'
    }

    It 'kennt die frueheren Parameter nicht mehr (der Endpunkt kennt sie nicht)' {
        foreach ($sb in @(
                { Set-ArubaSWMstpPort -port_id 5 -priority 64 -Confirm:$false -connection $StubConnection -ErrorAction Stop },
                { Set-ArubaSWMstpPort -port_id 5 -path_cost 100 -Confirm:$false -connection $StubConnection -ErrorAction Stop },
                { Set-ArubaSWMstpPort -port_id 5 -admin_edge_port -Confirm:$false -connection $StubConnection -ErrorAction Stop },
                { Set-ArubaSWMstpPort -port_id 5 -bpdu_protection_enabled -Confirm:$false -connection $StubConnection -ErrorAction Stop },
                { Set-ArubaSWMstpPort -port_id 5 -root_guard_enabled -Confirm:$false -connection $StubConnection -ErrorAction Stop })) {
            $sb | Should -Throw -ErrorId 'NamedParameterNotFound,Set-ArubaSWMstpPort'
        }
    }

    It 'macht KEINEN PUT bei -WhatIf' {
        Set-ArubaSWMstpPort -port_id 5 -root_guard -WhatIf -connection $StubConnection
        $PutCount | Should -Be 0
    }
}
