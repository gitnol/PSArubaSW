#
# Copyright 2026, PowerArubaSW contributors
# SPDX-License-Identifier: Apache-2.0
#
# Unit-Tests fuer Public/SystemConfigReset.ps1 (Inkrement I21).
# Strukturell ein minimaler Klon von SystemReboot.Tests.ps1 (Commander-
# Path) ohne ParameterSet-Vielfalt -- Reset hat nur einen Pfad.

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

Describe 'Reset-ArubaSWConfiguration' -Tag 'Unit' {

    BeforeEach {
        Mock -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest {
            Get-Fixture -Resource system-configuration-reset -Name post-reset
        }
    }

    It 'ruft POST system/configuration-reset ueber den Transport-Wrapper' {
        Reset-ArubaSWConfiguration -Confirm:$false -connection $StubConnection
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 1 -Exactly `
            -ParameterFilter { $method -eq 'POST' -and $uri -eq 'system/configuration-reset' }
    }

    It 'sendet KEINEN Request-Body (Reset hat keinen Body)' {
        Reset-ArubaSWConfiguration -Confirm:$false -connection $StubConnection
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 1 -Exactly `
            -ParameterFilter { $null -eq $body }
    }

    It 'akzeptiert leeren Response-Body (Reset quittiert oft mit content="")' {
        # Edge case getrennt von Fixture testen: echter leerer Content statt
        # des Fixture-Minimal-"{}"; Cmdlet darf nicht throwen
        # (`if ($response.content)`-Guard im Reset-Cmdlet faengt das ab).
        Mock -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest { @{ content = '' } }
        { Reset-ArubaSWConfiguration -Confirm:$false -connection $StubConnection } |
            Should -Not -Throw
    }

    It 'macht KEINEN Aufruf bei -WhatIf' {
        Reset-ArubaSWConfiguration -WhatIf -connection $StubConnection
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 0 -Exactly
    }
}
