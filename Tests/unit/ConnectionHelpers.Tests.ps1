#
# Copyright 2026, PowerArubaSW contributors
# SPDX-License-Identifier: Apache-2.0
#
# Unit-Tests fuer Private/ConnectionHelpers.ps1 (Inkrement I32, Zerlegung von Connect-ArubaSW). Die Helfer sind rein; die Edition
# wird als Parameter uebergeben, damit der Desktop-Zweig (Windows PowerShell 5.1) ohne Windows PowerShell geprueft werden kann.

BeforeAll {
    $script:UnitDir  = Split-Path -Parent $PSCommandPath
    $script:RepoRoot = Split-Path -Parent (Split-Path -Parent $UnitDir)
    $loaded = Get-Module -Name 'PowerArubaSW' -ErrorAction SilentlyContinue
    if ($loaded) { Remove-Module $loaded -Force }
    Import-Module (Join-Path $RepoRoot 'PowerArubaSW\PowerArubaSW.psd1') -Force
}

Describe 'Get-ArubaSWLoginInvokeParameter' -Tag 'Unit' {

    It 'Core: SkipCertificateCheck bleibt, UseBasicParsing entfaellt, DisableKeepAlive ist gesetzt' {
        $p = InModuleScope PowerArubaSW { Get-ArubaSWLoginInvokeParameter -SkipCertificateCheck -Edition 'Core' }
        $p.ContainsKey('SkipCertificateCheck') | Should -BeTrue
        $p['SkipCertificateCheck'] | Should -BeTrue
        $p.ContainsKey('UseBasicParsing') | Should -BeFalse
        $p['DisableKeepAlive'] | Should -BeTrue
    }

    It 'Core ohne -SkipCertificateCheck: Wert ist false' {
        $p = InModuleScope PowerArubaSW { Get-ArubaSWLoginInvokeParameter -Edition 'Core' }
        $p['SkipCertificateCheck'] | Should -BeFalse
    }

    It 'Desktop: SkipCertificateCheck entfaellt (dort nicht unterstuetzt), UseBasicParsing bleibt' {
        $p = InModuleScope PowerArubaSW { Get-ArubaSWLoginInvokeParameter -SkipCertificateCheck -Edition 'Desktop' }
        $p.ContainsKey('SkipCertificateCheck') | Should -BeFalse
        $p['UseBasicParsing'] | Should -BeTrue
        $p['DisableKeepAlive'] | Should -BeTrue
    }
}

Describe 'Get-ArubaSWLoginTarget' -Tag 'Unit' {

    It 'HTTPS ist Standard: Port 443, API v3' {
        $t = InModuleScope PowerArubaSW { Get-ArubaSWLoginTarget -Server 'sw1' }
        $t.Uri | Should -BeExactly 'https://sw1:443/rest/v3/login-sessions'
        $t.Port | Should -Be 443
    }

    It '-HttpOnly: http, Port 80' {
        $t = InModuleScope PowerArubaSW { Get-ArubaSWLoginTarget -Server 'sw1' -HttpOnly }
        $t.Uri | Should -BeExactly 'http://sw1:80/rest/v3/login-sessions'
        $t.Port | Should -Be 80
    }

    It 'ein genannter Port und eine genannte API-Version gelten' {
        $t = InModuleScope PowerArubaSW { Get-ArubaSWLoginTarget -Server 'sw1' -Port 4443 -ApiVersion 2 }
        $t.Uri | Should -BeExactly 'https://sw1:4443/rest/v2/login-sessions'
        $t.Port | Should -Be 4443
        $h = InModuleScope PowerArubaSW { Get-ArubaSWLoginTarget -Server 'sw1' -Port 8080 -HttpOnly -ApiVersion 10 }
        $h.Uri | Should -BeExactly 'http://sw1:8080/rest/v10/login-sessions'
    }
}

Describe 'Initialize-ArubaSWDesktopSSL' -Tag 'Unit' {

    BeforeEach {
        Mock -ModuleName PowerArubaSW Set-ArubaSWCipherSSL { }
        Mock -ModuleName PowerArubaSW Set-ArubaSWuntrustedSSL { }
    }

    It 'Desktop: TLS einschalten, Zertifikatskette nur mit -SkipCertificateCheck ignorieren' {
        InModuleScope PowerArubaSW { Initialize-ArubaSWDesktopSSL -Edition 'Desktop' }
        Should -Invoke -ModuleName PowerArubaSW Set-ArubaSWCipherSSL -Times 1 -Exactly
        Should -Invoke -ModuleName PowerArubaSW Set-ArubaSWuntrustedSSL -Times 0 -Exactly
        InModuleScope PowerArubaSW { Initialize-ArubaSWDesktopSSL -Edition 'Desktop' -SkipCertificateCheck }
        Should -Invoke -ModuleName PowerArubaSW Set-ArubaSWCipherSSL -Times 2 -Exactly
        Should -Invoke -ModuleName PowerArubaSW Set-ArubaSWuntrustedSSL -Times 1 -Exactly
    }

    It 'Core: keine Aenderung am TLS-Zustand' {
        InModuleScope PowerArubaSW { Initialize-ArubaSWDesktopSSL -Edition 'Core' -SkipCertificateCheck }
        Should -Invoke -ModuleName PowerArubaSW Set-ArubaSWCipherSSL -Times 0 -Exactly
        Should -Invoke -ModuleName PowerArubaSW Set-ArubaSWuntrustedSSL -Times 0 -Exactly
    }
}

Describe 'Get-ArubaSWApiVersionRange' -Tag 'Unit' {

    It 'bildet Min und Max aus den gemeldeten Versionen (v1.0 ... v8.0)' {
        $r = InModuleScope PowerArubaSW { Get-ArubaSWApiVersionRange -RestVersion ([pscustomobject]@{ version = @('v1.0', 'v2.0', 'v3.0', 'v8.0') }) }
        $r.Min | Should -Be 1
        $r.Max | Should -Be 8
    }

    It 'zweistellige Hauptversionen bleiben erhalten (v10.0 wird 10, nicht leer)' {
        $r = InModuleScope PowerArubaSW { Get-ArubaSWApiVersionRange -RestVersion ([pscustomobject]@{ version = @('v2.0', 'v9.0', 'v10.0') }) }
        $r.Min | Should -Be 2
        $r.Max | Should -Be 10
    }

    It 'schneidet auch die Endung .1 ab (v3.1 wird 3)' {
        $r = InModuleScope PowerArubaSW { Get-ArubaSWApiVersionRange -RestVersion ([pscustomobject]@{ version = @('v2.1', 'v5.1') }) }
        $r.Min | Should -Be 2
        $r.Max | Should -Be 5
    }
}

Describe 'Get-ArubaSWProductInfo' -Tag 'Unit' {

    It 'einzelner Switch: Nummer und Name des Status' {
        $i = InModuleScope PowerArubaSW { Get-ArubaSWProductInfo -SwitchStatus ([pscustomobject]@{ switch_type = 'ST_STANDALONE'; product_number = 'J1'; product_name = 'Name1' }) }
        $i.ProductNumber | Should -BeExactly 'J1'
        $i.ProductName | Should -BeExactly 'Name1'
    }

    It 'Stack mit einer Einheit' {
        $i = InModuleScope PowerArubaSW {
            Get-ArubaSWProductInfo -SwitchStatus ([pscustomobject]@{ switch_type = 'ST_STACKED'; blades = [pscustomobject]@{ product_number = 'J-ONE'; product_name = 'Eins' } })
        }
        $i.ProductNumber | Should -BeExactly 'J-ONE'
        $i.ProductName | Should -BeExactly 'Eins'
    }

    It 'Stack mit mehreren Einheiten: Nummer der ersten, Namen der benannten mit ", " verbunden' {
        $i = InModuleScope PowerArubaSW {
            Get-ArubaSWProductInfo -SwitchStatus ([pscustomobject]@{ switch_type = 'ST_STACKED'; blades = @(
                [pscustomobject]@{ product_number = 'J-A'; product_name = 'Alpha' },
                [pscustomobject]@{ product_number = 'J-B'; product_name = $null },
                [pscustomobject]@{ product_number = 'J-C'; product_name = 'Gamma' }) })
        }
        $i.ProductNumber | Should -BeExactly 'J-A'
        $i.ProductName | Should -BeExactly 'Alpha, Gamma'
    }
}

Describe 'Get-ArubaSWMstpApiVersion (I35)' -Tag 'Unit' {

    It 'deckelt die REST-Version auf 5, weil /mstp ab v6 am Switch 404 liefert' {
        $c = [pscustomobject]@{ api_version = @{ cur = 8; min = 1; max = 8 } }
        InModuleScope PowerArubaSW -Parameters @{ C = $c } { param($C) Get-ArubaSWMstpApiVersion -Connection $C } | Should -Be 5
    }

    It 'laesst eine niedrigere Standardversion der Verbindung unveraendert' {
        $c = [pscustomobject]@{ api_version = @{ cur = 3; min = 1; max = 8 } }
        InModuleScope PowerArubaSW -Parameters @{ C = $c } { param($C) Get-ArubaSWMstpApiVersion -Connection $C } | Should -Be 3
    }

    It 'Version 5 bleibt 5' {
        $c = [pscustomobject]@{ api_version = @{ cur = 5; min = 1; max = 5 } }
        InModuleScope PowerArubaSW -Parameters @{ C = $c } { param($C) Get-ArubaSWMstpApiVersion -Connection $C } | Should -Be 5
    }
}
