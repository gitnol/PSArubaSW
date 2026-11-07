#
# Copyright 2026, PowerArubaSW contributors
# SPDX-License-Identifier: Apache-2.0
#
# Unit-Tests fuer Public/SwitchConfig.ps1 (Inkrement I15, I41).
# Save-ArubaSWConfig: POST + ShouldProcess (High-Impact) Action-Pattern.

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

Describe 'Save-ArubaSWConfig' -Tag 'Unit' {

    BeforeEach {
        $script:Body = $null
        Mock -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest {
            $script:Body = $body
            (Get-Fixture -Resource cli -Name post-write-memory).content
        }
    }

    It 'sendet write memory ueber POST cli (/switch-config gibt es am Switch nicht)' {
        $null = Save-ArubaSWConfig -Confirm:$false -connection $StubConnection
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 1 -Exactly `
            -ParameterFilter { $method -eq 'POST' -and $uri -eq 'cli' }
        $Body.cmd | Should -Be 'write memory'
    }

    It 'liefert das CLI-Ergebnis mit Status CCS_SUCCESS' {
        $r = Save-ArubaSWConfig -Confirm:$false -connection $StubConnection
        $r.status | Should -Be 'CCS_SUCCESS'
        $r.cmd | Should -Be 'write memory'
    }

    It 'macht KEINEN Aufruf bei -WhatIf' {
        Save-ArubaSWConfig -WhatIf -connection $StubConnection
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 0 -Exactly
    }
}

Describe 'Get-ArubaSWConfigStatus' -Tag 'Unit' {

    BeforeEach {
        $script:Body = $null
        Mock -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest {
            $script:Body = $body
            (Get-Fixture -Resource cli -Name post-show-config-status).content
        }
    }

    It 'sendet show config status ueber POST cli' {
        $null = Get-ArubaSWConfigStatus -connection $StubConnection
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 1 -Exactly `
            -ParameterFilter { $method -eq 'POST' -and $uri -eq 'cli' }
        $Body.cmd | Should -Be 'show config status'
    }

    It 'dekodiert die Ausgabe des Switches' {
        $r = Get-ArubaSWConfigStatus -connection $StubConnection
        $r.status | Should -Be 'CCS_SUCCESS'
        $r.result | Should -BeLike '*running configuration matches the saved configuration*'
    }
}
