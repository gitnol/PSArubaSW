#
# Copyright 2026, PowerArubaSW contributors
# SPDX-License-Identifier: Apache-2.0
#
# Unit-Tests fuer Public/Jumbo.ps1 (Inkrement I19).
# Strukturell ein Klon von Cdp.Tests.ps1 (Referenz-First): Read-Modify
# global-config Pattern mit einem einzelnen is_*_enabled-Switch.

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

Describe 'Get-ArubaSWJumbo' -Tag 'Unit' {

    BeforeEach {
        Mock -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest {
            Get-Fixture -Resource jumbo -Name get-default
        }
    }

    It 'ruft GET jumbo ueber den Transport-Wrapper' {
        $null = Get-ArubaSWJumbo -connection $StubConnection
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 1 -Exactly `
            -ParameterFilter { $method -eq 'GET' -and $uri -eq 'jumbo' }
    }

    It 'parst max_frame_size und ip_mtu_size aus dem JSON-Response (echte Feldnamen)' {
        $r = Get-ArubaSWJumbo -connection $StubConnection
        $r.max_frame_size | Should -Be 9216
        $r.ip_mtu_size    | Should -Be 9198
    }
}

Describe 'Set-ArubaSWJumbo' -Tag 'Unit' {

    BeforeEach {
        $script:CapturedBody = $null
        Mock -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest {
            $script:CapturedBody = $body
            Get-Fixture -Resource jumbo -Name put-enabled
        }
    }

    It 'ruft PUT jumbo mit max_frame_size im Body' {
        $r = Set-ArubaSWJumbo -max_frame_size 9000 -Confirm:$false -connection $StubConnection
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 1 -Exactly `
            -ParameterFilter { $method -eq 'PUT' -and $uri -eq 'jumbo' }
        $CapturedBody.max_frame_size | Should -Be 9000
        @($CapturedBody.PSObject.Properties.Name) | Should -Be @('max_frame_size')
        $r.max_frame_size | Should -Be 9000
    }

    It 'sendet ip_mtu_size nur, wenn angegeben' {
        $null = Set-ArubaSWJumbo -max_frame_size 9216 -ip_mtu_size 9100 -Confirm:$false -connection $StubConnection
        $CapturedBody.ip_mtu_size | Should -Be 9100
        $null = Set-ArubaSWJumbo -ip_mtu_size 1500 -Confirm:$false -connection $StubConnection
        @($CapturedBody.PSObject.Properties.Name) | Should -Be @('ip_mtu_size')
    }

    It 'lehnt Werte ausserhalb der Grenzen des Switches ab (Frame 1518..9216, MTU 1500..9198)' {
        foreach ($v in 1517, 9217) {
            { Set-ArubaSWJumbo -max_frame_size $v -Confirm:$false -connection $StubConnection -ErrorAction Stop } |
                Should -Throw -ErrorId 'ParameterArgumentValidationError,Set-ArubaSWJumbo'
        }
        foreach ($v in 1499, 9199) {
            { Set-ArubaSWJumbo -ip_mtu_size $v -Confirm:$false -connection $StubConnection -ErrorAction Stop } |
                Should -Throw -ErrorId 'ParameterArgumentValidationError,Set-ArubaSWJumbo'
        }
    }

    It 'kennt den frueheren Schalter -is_jumbo_enabled nicht mehr (der Switch ignorierte ihn)' {
        { Set-ArubaSWJumbo -is_jumbo_enabled -Confirm:$false -connection $StubConnection -ErrorAction Stop } |
            Should -Throw -ErrorId 'NamedParameterNotFound,Set-ArubaSWJumbo'
    }

    It 'macht KEINEN Aufruf bei -WhatIf' {
        Set-ArubaSWJumbo -max_frame_size 9216 -WhatIf -connection $StubConnection
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 0 -Exactly
    }
}
