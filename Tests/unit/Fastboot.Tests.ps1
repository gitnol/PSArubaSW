#
# Copyright 2026, PowerArubaSW contributors
# SPDX-License-Identifier: Apache-2.0
#
# Unit-Tests fuer Public/Fastboot.ps1 (Inkrement I25).
# Strukturell ein Klon von Jumbo.Tests.ps1 (Referenz-First): Read-Modify
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

Describe 'Get-ArubaSWFastboot' -Tag 'Unit' {

    BeforeEach {
        Mock -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest {
            Get-Fixture -Resource fastboot -Name get-default
        }
    }

    It 'ruft GET fastboot ueber den Transport-Wrapper' {
        $null = Get-ArubaSWFastboot -connection $StubConnection
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 1 -Exactly `
            -ParameterFilter { $method -eq 'GET' -and $uri -eq 'fastboot' }
    }

    It 'parst is_fastboot_enabled aus dem JSON-Response' {
        $r = Get-ArubaSWFastboot -connection $StubConnection
        $r.is_fastboot_enabled | Should -BeFalse
    }
}

Describe 'Set-ArubaSWFastboot' -Tag 'Unit' {

    BeforeEach {
        $script:CapturedBody = $null
        Mock -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest {
            $script:CapturedBody = $body
            Get-Fixture -Resource fastboot -Name put-enabled
        }
    }

    It 'ruft PUT fastboot mit is_fastboot_enabled=$true im Body' {
        $r = Set-ArubaSWFastboot -is_fastboot_enabled -Confirm:$false -connection $StubConnection
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 1 -Exactly `
            -ParameterFilter { $method -eq 'PUT' -and $uri -eq 'fastboot' }
        $CapturedBody.is_fastboot_enabled | Should -BeTrue
        $r.is_fastboot_enabled | Should -BeTrue
    }

    It 'akzeptiert is_fastboot_enabled:$false als expliziten Deaktivierungs-Aufruf' {
        $null = Set-ArubaSWFastboot -is_fastboot_enabled:$false -Confirm:$false -connection $StubConnection
        $CapturedBody.is_fastboot_enabled | Should -BeFalse
    }

    It 'sendet leeren Body, wenn keine Felder uebergeben werden (partial-update)' {
        $null = Set-ArubaSWFastboot -Confirm:$false -connection $StubConnection
        $CapturedBody.PSObject.Properties.Name | Should -Not -Contain 'is_fastboot_enabled'
    }

    It 'macht KEINEN Aufruf bei -WhatIf' {
        Set-ArubaSWFastboot -is_fastboot_enabled -WhatIf -connection $StubConnection
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 0 -Exactly
    }
}
