#
# Copyright 2026, PowerArubaSW contributors
# SPDX-License-Identifier: Apache-2.0
#
# Unit-Tests fuer Public/Cdp.ps1 (Inkrement I15).
# Mockt den Transport-Wrapper Invoke-ArubaSWWebRequest und prueft das
# Read-Modify-Pattern eines global-config-Endpoints (GET + PUT /cdp).

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

Describe 'Get-ArubaSWCdp' -Tag 'Unit' {

    BeforeEach {
        Mock -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest {
            Get-Fixture -Resource cdp -Name get-default
        }
    }

    It 'ruft GET cdp ueber den Transport-Wrapper' {
        $null = Get-ArubaSWCdp -connection $StubConnection
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 1 -Exactly `
            -ParameterFilter { $method -eq 'GET' -and $uri -eq 'cdp' }
    }

    It 'parst die CDP-Felder aus dem JSON-Response' {
        $r = Get-ArubaSWCdp -connection $StubConnection
        $r.is_cdp_enabled | Should -BeTrue
        $r.mode           | Should -Be 'CDPM_RXONLY'
    }
}

Describe 'Set-ArubaSWCdp' -Tag 'Unit' {

    BeforeEach {
        $script:CapturedBody = $null
        Mock -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest {
            $script:CapturedBody = $body
            Get-Fixture -Resource cdp -Name put-disabled
        }
    }

    It 'ruft PUT cdp mit is_cdp_enabled=false auf, wenn -is_cdp_enabled:$false' {
        $null = Set-ArubaSWCdp -is_cdp_enabled:$false -confirm:$false -connection $StubConnection
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 1 -Exactly `
            -ParameterFilter { $method -eq 'PUT' -and $uri -eq 'cdp' }
        $CapturedBody.is_cdp_enabled | Should -BeFalse
    }

    It 'sendet nur die explizit uebergebenen Felder im Body (partial update)' {
        $null = Set-ArubaSWCdp -mode 'CDPM_RXONLY' -confirm:$false -connection $StubConnection
        $CapturedBody.mode | Should -Be 'CDPM_RXONLY'
        @($CapturedBody.PSObject.Properties.Name) | Should -Be @('mode')
    }

    It 'akzeptiert mehrere Felder im selben Aufruf' {
        $null = Set-ArubaSWCdp -is_cdp_enabled -mode 'CDPM_RXONLY' -confirm:$false -connection $StubConnection
        $CapturedBody.is_cdp_enabled | Should -BeTrue
        $CapturedBody.mode           | Should -Be 'CDPM_RXONLY'
    }

    It 'macht KEINEN Aufruf bei -WhatIf' {
        Set-ArubaSWCdp -is_cdp_enabled:$true -WhatIf -connection $StubConnection
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 0 -Exactly
    }

    It 'kennt die frueheren Parameter -cdp_holdtime und -cdp_timer nicht mehr (der Switch ignorierte sie)' {
        { Set-ArubaSWCdp -cdp_holdtime 60 -confirm:$false -connection $StubConnection -ErrorAction Stop } |
            Should -Throw -ErrorId 'NamedParameterNotFound,Set-ArubaSWCdp'
        { Set-ArubaSWCdp -cdp_timer 60 -confirm:$false -connection $StubConnection -ErrorAction Stop } |
            Should -Throw -ErrorId 'NamedParameterNotFound,Set-ArubaSWCdp'
    }
}
