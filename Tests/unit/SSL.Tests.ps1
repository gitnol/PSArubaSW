#
# Copyright 2026, PowerArubaSW contributors
# SPDX-License-Identifier: Apache-2.0
#
# Unit-Tests für Private/SSL.ps1 — sichern Inkrement I2 (Save/Restore-Pattern
# bei prozessweiter ServicePointManager-Mutation) als Regression.
#
# Lauf:
#   & .\Tests\pester.config.ps1 -Tag Unit | Invoke-Pester -Configuration $_

BeforeAll {
    $script:UnitDir    = Split-Path -Parent $PSCommandPath        # ...\Tests\unit
    $script:TestsRoot  = Split-Path -Parent $UnitDir              # ...\Tests
    $script:RepoRoot   = Split-Path -Parent $TestsRoot            # ...\PowerArubaSW-master
    $script:ModuleRoot = Join-Path $RepoRoot 'PowerArubaSW'
    $script:Manifest   = Join-Path $ModuleRoot 'PowerArubaSW.psd1'

    $loaded = Get-Module -Name 'PowerArubaSW' -ErrorAction SilentlyContinue
    if ($loaded) { Remove-Module $loaded -Force }
    Import-Module $Manifest -Force

    # Die SSL-Helfer sind seit I3 NICHT mehr exportiert — wir prüfen sie über
    # InModuleScope, was Pester 5 den Zugriff auf modul-interne Funktionen erlaubt.
}

Describe 'Set-ArubaSWCipherSSL / Restore-ArubaSWSSL — SecurityProtocol Round-Trip' -Tag 'Unit' {

    BeforeAll {
        $script:OriginalProtocol = [System.Net.ServicePointManager]::SecurityProtocol
    }

    AfterEach {
        # Sicherheitsnetz: nach jedem It den Originalzustand wiederherstellen,
        # damit ein fehlschlagender Test nicht die übrigen Tests verschmutzt.
        [System.Net.ServicePointManager]::SecurityProtocol = $OriginalProtocol
        InModuleScope PowerArubaSW {
            # interne Save-Flags zurücksetzen
            $script:ArubaSWSecurityProtocolSaved = $false
            $script:ArubaSWoldSecurityProtocol = $null
        }
    }

    It 'aktiviert TLS 1.2 und schaltet die schwachen Protokolle (SSL3/TLS1.0/1.1) ab' {
        InModuleScope PowerArubaSW { Set-ArubaSWCipherSSL }
        $proto = [System.Net.ServicePointManager]::SecurityProtocol
        ($proto.ToString()) | Should -Match 'Tls12'
        ($proto.ToString()) | Should -Not -Match 'Ssl3'
        ($proto.ToString()) | Should -Not -Match 'Tls11'
        # TLS 1.0 = "Tls" als blanker Begriff im Enum-String, mit Word-Boundary prüfen
        ($proto.ToString()) | Should -Not -Match '\bTls\b'
    }

    It 'stellt den ursprünglichen SecurityProtocol-Wert in Restore-ArubaSWSSL wieder her' {
        $orig = [System.Net.ServicePointManager]::SecurityProtocol
        InModuleScope PowerArubaSW { Set-ArubaSWCipherSSL }
        [System.Net.ServicePointManager]::SecurityProtocol | Should -Not -Be $orig
        InModuleScope PowerArubaSW { Restore-ArubaSWSSL }
        [System.Net.ServicePointManager]::SecurityProtocol | Should -Be $orig
    }

    It 'klobbert den gesicherten Wert nicht bei mehrfachem Set (Flag-Guard)' {
        $orig = [System.Net.ServicePointManager]::SecurityProtocol
        InModuleScope PowerArubaSW {
            Set-ArubaSWCipherSSL
            Set-ArubaSWCipherSSL   # zweiter Aufruf darf den gesicherten ORIGINAL-Wert nicht überschreiben
        }
        InModuleScope PowerArubaSW { Restore-ArubaSWSSL }
        [System.Net.ServicePointManager]::SecurityProtocol | Should -Be $orig
    }

    It 'Restore ist idempotent (zweiter Aufruf ohne vorheriges Set ist No-Op)' {
        $orig = [System.Net.ServicePointManager]::SecurityProtocol
        InModuleScope PowerArubaSW { Restore-ArubaSWSSL }
        [System.Net.ServicePointManager]::SecurityProtocol | Should -Be $orig
    }

}

Describe 'Set-ArubaSWuntrustedSSL — CertificatePolicy Round-Trip (nur Desktop)' -Tag 'Unit' {

    It 'wird auf Windows PowerShell (Desktop) ausgeführt; auf Core übersprungen, weil ICertificatePolicy nur im .NET Framework existiert' -Skip:($PSVersionTable.PSEdition -ne 'Desktop') {
        $orig = [System.Net.ServicePointManager]::CertificatePolicy
        try {
            InModuleScope PowerArubaSW { Set-ArubaSWuntrustedSSL }
            $pol = [System.Net.ServicePointManager]::CertificatePolicy
            $pol.GetType().Name | Should -Be 'TrustAllCertsPolicy'
            InModuleScope PowerArubaSW { Restore-ArubaSWSSL }
            ([object]::ReferenceEquals([System.Net.ServicePointManager]::CertificatePolicy, $orig)) |
                Should -BeTrue
        }
        finally {
            [System.Net.ServicePointManager]::CertificatePolicy = $orig
            InModuleScope PowerArubaSW {
                $script:ArubaSWCertificatePolicySaved = $false
                $script:ArubaSWoldCertificatePolicy = $null
            }
        }
    }
}
