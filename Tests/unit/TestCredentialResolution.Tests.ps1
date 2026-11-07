#
# Copyright 2026, PowerArubaSW contributors
# SPDX-License-Identifier: Apache-2.0
#
# Unit-Tests fuer Tests/_helpers/Resolve-TestCredential.ps1 (Inkrement I28):
# Reihenfolge Credential Store -> ARUBASW_TEST_PASSWORD -> $password aus credential.ps1.

# PSSA-Ausnahme: Dummy-Passwoerter fuer die Tests, nie ein echtes Geheimnis.
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingConvertToSecureStringWithPlainText", "")]
Param()

BeforeAll {
    $script:UnitDir   = Split-Path -Parent $PSCommandPath
    $script:TestsRoot = Split-Path -Parent $UnitDir
    . (Join-Path $TestsRoot '_helpers\Resolve-TestCredential.ps1')

    $script:Stored = [pscredential]::new('store-user', (ConvertTo-SecureString 'store-pw' -AsPlainText -Force))

    function Get-PlainPassword {
        param([securestring]$Secure)
        [System.Net.NetworkCredential]::new('', $Secure).Password
    }
}

Describe 'Resolve-ArubaSWTestCredential' -Tag 'Unit' {

    It 'Credential Store hat Vorrang vor Umgebungsvariable und Datei; Benutzer kommt aus dem Store' {
        $r = Resolve-ArubaSWTestCredential -Server 'sw1' -FileLogin 'file-user' -FilePassword 'file-pw' `
            -EnvPassword 'env-pw' -StoreCredential $Stored
        $r.Source | Should -Be 'CredentialStore'
        $r.Login | Should -Be 'store-user'
        Get-PlainPassword $r.Password | Should -BeExactly 'store-pw'
    }

    It 'ohne Store: Umgebungsvariable vor dem Klartext in der Datei, Benutzer aus der Datei' {
        $r = Resolve-ArubaSWTestCredential -Server 'sw1' -FileLogin 'file-user' -FilePassword 'file-pw' -EnvPassword 'env-pw'
        $r.Source | Should -Be 'Environment'
        $r.Login | Should -Be 'file-user'
        Get-PlainPassword $r.Password | Should -BeExactly 'env-pw'
    }

    It 'ohne Store und Umgebungsvariable: Klartext-Rueckfall aus credential.ps1' {
        $r = Resolve-ArubaSWTestCredential -Server 'sw1' -FileLogin 'file-user' -FilePassword 'file-pw'
        $r.Source | Should -Be 'credential.ps1'
        Get-PlainPassword $r.Password | Should -BeExactly 'file-pw'
    }

    It 'ohne jede Quelle: klare Fehlermeldung mit den drei Moeglichkeiten und dem Server' {
        { Resolve-ArubaSWTestCredential -Server 'sw1' -FileLogin 'file-user' } |
            Should -Throw -ExpectedMessage '*sw1*Save-ArubaSWCredential*ARUBASW_TEST_PASSWORD*'
    }

    It 'ohne Benutzer aus der Datei und ohne Store: Fehler, auch wenn eine Quelle ein Passwort hat' {
        { Resolve-ArubaSWTestCredential -Server 'sw1' -EnvPassword 'env-pw' } | Should -Throw -ExpectedMessage "*Keine Test-Zugangsdaten fuer 'sw1'*"
    }
}

Describe 'Tests/common.ps1: Passwort ist optional' -Tag 'Unit' {

    It 'verlangt nur $ipaddress und $login und nutzt den Resolver' {
        $text = Get-Content -LiteralPath (Join-Path $TestsRoot 'common.ps1') -Raw
        $text | Should -Match 'Resolve-ArubaSWTestCredential'
        $text | Should -Not -Match '-not \$password'
    }

    It 'credential.example.ps1 setzt kein Klartext-Passwort mehr aktiv' {
        $text = Get-Content -LiteralPath (Join-Path $TestsRoot 'credential.example.ps1') -Raw
        $text | Should -Not -Match '(?m)^\s*\$script:password\s*='
    }
}
