#
# Copyright 2026, PowerArubaSW contributors
# SPDX-License-Identifier: Apache-2.0
#
# Unit-Tests fuer Set-ArubaSWSystem (Public/System.ps1), Inkrement I31. Anlass: Der Robustheitstest fand unter Strict Mode (I23)
# eine ungesetzte Variable (`$port` als ShouldProcess-Ziel, Copy-Paste-Rest aus dem STP-Port-Cmdlet) - das Cmdlet war damit
# in jedem Aufruf mit Bestaetigung kaputt. Die PUT-Antwort ist nicht aufgezeichnet; als Antwort dient die GET-Fixture `system/get-default`
# (Annahme: der Switch liefert nach PUT das Systemobjekt zurueck, wie bei den uebrigen Konfigurations-PUTs - Hypothese, kein Befund).

BeforeAll {
    $script:UnitDir  = Split-Path -Parent $PSCommandPath
    $script:RepoRoot = Split-Path -Parent (Split-Path -Parent $UnitDir)
    $loaded = Get-Module -Name 'PowerArubaSW' -ErrorAction SilentlyContinue
    if ($loaded) { Remove-Module $loaded -Force }
    Import-Module (Join-Path $RepoRoot 'PowerArubaSW\PowerArubaSW.psd1') -Force
    . "$UnitDir\_helpers\Get-Fixture.ps1"

    $script:StubConnection = [PSCustomObject]@{ server = '198.51.100.1'; port = 443; httpOnly = $false; api_version = @{ cur = 8 } }
}

Describe 'Set-ArubaSWSystem' -Tag 'Unit' {

    BeforeEach {
        $script:CapturedBody = $null
        Mock -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest {
            $script:CapturedBody = $body
            Get-Fixture -Resource system -Name get-default
        }
    }

    It 'sendet PUT system mit den gesetzten Feldern und ruft nur einmal auf' {
        $null = Set-ArubaSWSystem -name 'sw1' -location 'Lab' -contact 'ops' -Confirm:$false -connection $StubConnection
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 1 -Exactly `
            -ParameterFilter { $method -eq 'PUT' -and $uri -eq 'system' }
        $CapturedBody.name     | Should -BeExactly 'sw1'
        $CapturedBody.location | Should -BeExactly 'Lab'
        $CapturedBody.contact  | Should -BeExactly 'ops'
    }

    It 'laesst nicht gesetzte Felder weg' {
        $null = Set-ArubaSWSystem -name 'sw1' -Confirm:$false -connection $StubConnection
        $CapturedBody.PSObject.Properties.Name | Should -Be @('name')
    }

    It 'laeuft unter Strict Mode ohne Fehler (ShouldProcess-Ziel ist gesetzt)' {
        { Set-ArubaSWSystem -name 'sw1' -Confirm:$false -connection $StubConnection -ErrorAction Stop } | Should -Not -Throw
    }

    It 'macht KEINEN Aufruf bei -WhatIf' {
        Set-ArubaSWSystem -name 'sw1' -WhatIf -connection $StubConnection
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 0 -Exactly
    }
}
