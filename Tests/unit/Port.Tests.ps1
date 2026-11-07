#
# Copyright 2026, PowerArubaSW contributors
# SPDX-License-Identifier: Apache-2.0
#
# Unit-Tests fuer Public/Port.ps1 (Set-ArubaSWPort).
# Auslöser (I35): Der echte Switch akzeptiert einen leeren Portnamen (so wird der Name geloescht),
# die Validierung verlangte aber mindestens ein Zeichen.

BeforeAll {
    $script:UnitDir    = Split-Path -Parent $PSCommandPath
    $script:TestsRoot  = Split-Path -Parent $UnitDir
    $script:RepoRoot   = Split-Path -Parent $TestsRoot
    $script:Manifest   = Join-Path (Join-Path $RepoRoot 'PowerArubaSW') 'PowerArubaSW.psd1'

    $loaded = Get-Module -Name 'PowerArubaSW' -ErrorAction SilentlyContinue
    if ($loaded) { Remove-Module $loaded -Force }
    Import-Module $Manifest -Force

    $script:StubConnection = [PSCustomObject]@{
        server      = '198.51.100.1'
        port        = 443
        httpOnly    = $false
        api_version = @{ cur = 8 }
    }
}

Describe 'Set-ArubaSWPort -name' -Tag 'Unit' {

    BeforeEach {
        $script:CapturedBody = $null
        $script:CapturedUri  = $null
        Mock -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest {
            $script:CapturedBody = $body
            $script:CapturedUri  = $uri
            '{"id":"21","name":""}'
        }
    }

    It 'sendet einen leeren Namen (loescht den Portnamen)' {
        $null = Set-ArubaSWPort -port_id 21 -name '' -Confirm:$false -connection $StubConnection
        $CapturedBody.name | Should -BeExactly ''
        $CapturedBody.id   | Should -Be '21'
    }

    It 'sendet einen normalen Namen unveraendert' {
        $null = Set-ArubaSWPort -port_id 21 -name 'Uplink' -Confirm:$false -connection $StubConnection
        $CapturedBody.name | Should -Be 'Uplink'
    }

    It 'lehnt einen Namen ueber 64 Zeichen ab' {
        { Set-ArubaSWPort -port_id 21 -name ('x' * 65) -Confirm:$false -connection $StubConnection -ErrorAction Stop } |
            Should -Throw -ErrorId 'ParameterArgumentValidationError,Set-ArubaSWPort'
    }
}
