#
# Copyright 2026, PowerArubaSW contributors
# SPDX-License-Identifier: Apache-2.0
#
# Unit-Tests fuer Public/SystemIncludeCredentials.ps1 (Inkrement I24).
# Struktur nach Jumbo.Tests.ps1 (Referenz-First) plus das -Force-Pattern aus
# I7 (Connect-ArubaSW -httpOnly): Aktivieren ohne -Force bricht vor dem Request ab.

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

Describe 'Get-ArubaSWIncludeCredentials' -Tag 'Unit' {

    BeforeEach {
        Mock -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest {
            Get-Fixture -Resource system-include-credentials -Name get-default
        }
    }

    It 'ruft GET system/include-credentials ueber den Transport-Wrapper' {
        $null = Get-ArubaSWIncludeCredentials -connection $StubConnection
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 1 -Exactly `
            -ParameterFilter { $method -eq 'GET' -and $uri -eq 'system/include-credentials' }
    }

    It 'parst include_credentials_in_response und store_in_config aus dem JSON-Response (echte Feldnamen)' {
        $r = Get-ArubaSWIncludeCredentials -connection $StubConnection
        $r.include_credentials_in_response | Should -Be 'ICS_DISABLED'
        $r.store_in_config                 | Should -BeFalse
    }
}

Describe 'Set-ArubaSWIncludeCredentials' -Tag 'Unit' {

    BeforeEach {
        $script:CapturedBody = $null
        Mock -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest {
            $script:CapturedBody = $body
            Get-Fixture -Resource system-include-credentials -Name put-enabled
        }
    }

    It 'aktiviert mit -Force: PUT system/include-credentials, Body include_credentials_in_response=ICS_ENABLED' {
        $r = Set-ArubaSWIncludeCredentials -is_include_credentials_enabled -Force -Confirm:$false -connection $StubConnection
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 1 -Exactly `
            -ParameterFilter { $method -eq 'PUT' -and $uri -eq 'system/include-credentials' }
        $CapturedBody.include_credentials_in_response | Should -Be 'ICS_ENABLED'
        $r.include_credentials_in_response | Should -Be 'ICS_ENABLED'
    }

    It 'verweigert das Aktivieren ohne -Force und sendet NICHTS an den Switch' {
        { Set-ArubaSWIncludeCredentials -is_include_credentials_enabled -Confirm:$false -connection $StubConnection -WarningAction SilentlyContinue } |
            Should -Throw -ExpectedMessage '*without -Force*'
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 0 -Exactly
    }

    It 'gibt vor dem Abbruch drei Warnungen aus (Klartext, Mitleser, -Force)' {
        $w = $null
        try {
            Set-ArubaSWIncludeCredentials -is_include_credentials_enabled -Confirm:$false -connection $StubConnection -WarningVariable w -WarningAction SilentlyContinue
        } catch { $null = $_ }
        @($w).Count | Should -Be 3
    }

    It 'deaktivieren (:$false) braucht kein -Force' {
        $null = Set-ArubaSWIncludeCredentials -is_include_credentials_enabled:$false -Confirm:$false -connection $StubConnection
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 1 -Exactly
        $CapturedBody.include_credentials_in_response | Should -Be 'ICS_DISABLED'
    }

    It 'sendet leeren Body, wenn keine Felder uebergeben werden (partial-update)' {
        $null = Set-ArubaSWIncludeCredentials -Confirm:$false -connection $StubConnection
        $CapturedBody.PSObject.Properties.Name | Should -Not -Contain 'include_credentials_in_response'
    }

    It 'macht KEINEN Aufruf bei -WhatIf' {
        Set-ArubaSWIncludeCredentials -is_include_credentials_enabled -Force -WhatIf -connection $StubConnection
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 0 -Exactly
    }
}
