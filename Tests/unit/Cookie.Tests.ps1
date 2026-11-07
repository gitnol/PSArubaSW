#
# Copyright 2026, PowerArubaSW contributors
# SPDX-License-Identifier: Apache-2.0
#
# Unit-Tests für Private/Cookie.ps1 (Set-Cookie). Die Funktion ist nicht
# exportiert; Zugriff erfolgt über InModuleScope.

BeforeAll {
    $script:UnitDir    = Split-Path -Parent $PSCommandPath
    $script:TestsRoot  = Split-Path -Parent $UnitDir
    $script:RepoRoot   = Split-Path -Parent $TestsRoot
    $script:ModuleRoot = Join-Path $RepoRoot 'PowerArubaSW'
    $script:Manifest   = Join-Path $ModuleRoot 'PowerArubaSW.psd1'

    $loaded = Get-Module -Name 'PowerArubaSW' -ErrorAction SilentlyContinue
    if ($loaded) { Remove-Module $loaded -Force }
    Import-Module $Manifest -Force
}

Describe 'Set-Cookie (privat)' -Tag 'Unit' {

    It 'erzeugt ein System.Net.Cookie mit Name, Value und Domain' {
        $c = InModuleScope PowerArubaSW {
            Set-Cookie -name 'sessionId' -value 'abc123' -domain '198.51.100.1'
        }
        $c              | Should -BeOfType ([System.Net.Cookie])
        $c.Name         | Should -Be 'sessionId'
        $c.Value        | Should -Be 'abc123'
        $c.Domain       | Should -Be '198.51.100.1'
    }

    It 'verwendet "/" als Default-Path' {
        $c = InModuleScope PowerArubaSW {
            Set-Cookie -name 'sessionId' -value 'abc' -domain 'host'
        }
        $c.Path | Should -Be '/'
    }

    It 'übernimmt expliziten -path' {
        $c = InModuleScope PowerArubaSW {
            Set-Cookie -name 'sessionId' -value 'abc' -domain 'host' -path '/rest/v3'
        }
        $c.Path | Should -Be '/rest/v3'
    }
}
