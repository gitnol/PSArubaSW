#
# Copyright 2026, PowerArubaSW contributors
# SPDX-License-Identifier: Apache-2.0
#
# Unit-Tests für Public/Connection.ps1 — sichert Inkrement I2 (Disconnect-ArubaSW
# ruft Restore-ArubaSWSSL) als Verhaltens-Regression, plus Parameter-Validierung.
# Connect-ArubaSW selbst orchestriert mehrere REST-Aufrufe (Login, Get-RestVersion,
# Get-SystemStatusSwitch, Get-System) und wird hier bewusst NICHT End-to-End gemockt
# (Aufwand-Nutzen-Verhältnis); seine Mechanik ist über die Integration-Tests abgedeckt.

# PSSA-Ausnahmen analog zu Tests/common.ps1:
#   - Plain-Text-SecureString ist hier ein DUMMY-Credential, das den interaktiven
#     Get-Credential-Prompt im Connect-ArubaSW unterdrückt; nie ein echtes Geheimnis.
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingConvertToSecureStringWithPlainText", "")]
Param()

BeforeAll {
    $script:UnitDir    = Split-Path -Parent $PSCommandPath        # ...\Tests\unit
    $script:TestsRoot  = Split-Path -Parent $UnitDir              # ...\Tests
    $script:RepoRoot   = Split-Path -Parent $TestsRoot            # ...\PowerArubaSW-master
    $script:ModuleRoot = Join-Path $RepoRoot 'PowerArubaSW'
    $script:Manifest   = Join-Path $ModuleRoot 'PowerArubaSW.psd1'

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

Describe 'Disconnect-ArubaSW' -Tag 'Unit' {

    BeforeEach {
        # DELETE soll geschehen, aber nicht über die Leitung gehen.
        Mock -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest { }
        # Restore wird im Disconnect aufgerufen — Mocken, um nur die Aufruf-Existenz zu prüfen.
        Mock -ModuleName PowerArubaSW Restore-ArubaSWSSL { }
        # Globale Variable simulieren, damit der Disconnect-Pfad sie entfernen kann.
        Set-Variable -Name DefaultArubaSWConnection -Value $StubConnection -Scope Global -Force
    }

    AfterEach {
        if (Test-Path variable:global:DefaultArubaSWConnection) {
            Remove-Variable -Name DefaultArubaSWConnection -Scope Global -Force
        }
    }

    It 'ruft DELETE login-sessions über den Transport-Wrapper auf' {
        Disconnect-ArubaSW -connection $StubConnection -confirm:$false
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 1 -Exactly `
            -ParameterFilter { $method -eq 'DELETE' -and $uri -eq 'login-sessions' }
    }

    It 'entfernt die globale Variable $DefaultArubaSWConnection' {
        Disconnect-ArubaSW -connection $StubConnection -confirm:$false
        (Test-Path variable:global:DefaultArubaSWConnection) | Should -BeFalse
    }

    It 'ruft Restore-ArubaSWSSL auf (Regression für I2)' {
        Disconnect-ArubaSW -connection $StubConnection -confirm:$false
        Should -Invoke -ModuleName PowerArubaSW Restore-ArubaSWSSL -Times 1 -Exactly
    }

    It 'macht KEINEN Aufruf bei -WhatIf' {
        Disconnect-ArubaSW -connection $StubConnection -WhatIf
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 0 -Exactly
        Should -Invoke -ModuleName PowerArubaSW Restore-ArubaSWSSL -Times 0 -Exactly
    }
}

Describe 'Connect-ArubaSW — Parameter-Validierung' -Tag 'Unit' {

    It 'lehnt -port außerhalb 1–65535 ab' {
        { Connect-ArubaSW -Server '198.51.100.1' -port 0 -ErrorAction Stop } |
            Should -Throw -ErrorId 'ParameterArgumentValidationError,Connect-ArubaSW'
        { Connect-ArubaSW -Server '198.51.100.1' -port 99999 -ErrorAction Stop } |
            Should -Throw -ErrorId 'ParameterArgumentValidationError,Connect-ArubaSW'
    }

    It 'lehnt -api_version außerhalb 1–10 ab' {
        { Connect-ArubaSW -Server '198.51.100.1' -api_version 0 -ErrorAction Stop } |
            Should -Throw -ErrorId 'ParameterArgumentValidationError,Connect-ArubaSW'
        { Connect-ArubaSW -Server '198.51.100.1' -api_version 11 -ErrorAction Stop } |
            Should -Throw -ErrorId 'ParameterArgumentValidationError,Connect-ArubaSW'
    }

    It 'verlangt -Server (Mandatory)' {
        { Connect-ArubaSW -ErrorAction Stop } | Should -Throw -ErrorId 'MissingMandatoryParameter,Connect-ArubaSW'
    }
}

Describe 'Connect-ArubaSW — -httpOnly muss -Force tragen (I7)' -Tag 'Unit' {

    BeforeAll {
        # Dummy-Credential, damit der interaktive Get-Credential-Prompt nicht startet
        # — der -Force-Check liegt VOR der Credential-Auflösung, deshalb reicht ein Stub.
        $secure = ConvertTo-SecureString 'pw' -AsPlainText -Force
        $script:DummyCred = [pscredential]::new('dummy', $secure)
    }

    It 'wirft mit "Refused" wenn -httpOnly ohne -Force gesetzt wird' {
        { Connect-ArubaSW -Server '198.51.100.1' -Credentials $DummyCred -httpOnly -ErrorAction Stop -WarningAction SilentlyContinue } |
            Should -Throw -ExpectedMessage '*Refused -httpOnly without -Force*'
    }

    It 'gibt vor dem Throw drei Klartext-Warnungen aus' {
        try {
            Connect-ArubaSW -Server '198.51.100.1' -Credentials $DummyCred -httpOnly `
                -ErrorAction Stop -WarningVariable warns -WarningAction SilentlyContinue
        } catch {
            # erwarteter Throw — uns interessieren hier nur die vorher abgegebenen Warnungen
            $null = $_
        }
        ($warns.Count) | Should -BeGreaterOrEqual 3
        ($warns -join ' ') | Should -Match 'Klartext'
        ($warns -join ' ') | Should -Match 'Force'
    }

    It 'mit -httpOnly -Force gibt es KEINEN "Refused"-Throw mehr (späterer Netz-Fehler ist OK)' {
        # Wir mocken Invoke-WebRequest auf Modul-Scope, damit der Call nicht echt ins
        # Netz geht. Der spätere Throw nach dem Mock ist "Unable to connect", NICHT
        # mehr "Refused -httpOnly without -Force".
        Mock -ModuleName PowerArubaSW Invoke-WebRequest { throw 'mocked: kein Netzwerk' }
        Mock -ModuleName PowerArubaSW Show-ArubaSWException { }
        $caught = $null
        try {
            Connect-ArubaSW -Server '198.51.100.1' -Credentials $DummyCred -httpOnly -Force `
                -ErrorAction Stop -WarningAction SilentlyContinue | Out-Null
        } catch { $caught = $_ }
        $caught | Should -Not -BeNullOrEmpty
        $caught.Exception.Message | Should -Not -Match 'Refused -httpOnly without -Force'
    }

    It '-Force ohne -httpOnly hat keine Wirkung (Parameter wird ignoriert, Validation OK)' {
        # Reine Parameter-Annahme: -Force ist optional und Switch — darf bei HTTPS-
        # Default-Pfad nichts ändern. Wir prüfen nur, dass die Parameter-Bind durchgeht;
        # echter Connect wird nicht ausgeführt (Mock).
        Mock -ModuleName PowerArubaSW Invoke-WebRequest { throw 'mocked' }
        Mock -ModuleName PowerArubaSW Show-ArubaSWException { }
        $caught = $null
        try {
            Connect-ArubaSW -Server '198.51.100.1' -Credentials $DummyCred -Force `
                -ErrorAction Stop -WarningAction SilentlyContinue | Out-Null
        } catch { $caught = $_ }
        $caught.Exception.Message | Should -Not -Match 'Refused'
    }
}

Describe 'Set-ArubaSWConnection' -Tag 'Unit' {

    It 'aktualisiert api_version.cur am übergebenen Connection-Objekt' {
        $conn = [PSCustomObject]@{
            server      = '198.51.100.1'
            api_version = @{ cur = 3 }
        }
        Set-ArubaSWConnection -api_version 7 -connection $conn -confirm:$false
        $conn.api_version.cur | Should -Be 7
    }

    It 'macht KEINE Änderung bei -WhatIf' {
        $conn = [PSCustomObject]@{
            server      = '198.51.100.1'
            api_version = @{ cur = 3 }
        }
        Set-ArubaSWConnection -api_version 7 -connection $conn -WhatIf
        $conn.api_version.cur | Should -Be 3
    }
}

Describe 'Connect-ArubaSW - Ende-zu-Ende mit gemocktem Transport (I30, Mutationspruefung)' -Tag 'Unit' {

    BeforeAll {
        $script:Cred = [pscredential]::new('cred-user', (ConvertTo-SecureString 'cred-pw' -AsPlainText -Force))
    }

    BeforeEach {
        $script:LoginUri = $null
        $script:LoginBody = $null
        # -SessionVariable laesst sich nicht mocken (L11): der Mock legt die Variable im Modul-Scope an, dort findet
        # Connect-ArubaSW sie ueber die dynamische Variablensuche.
        Mock -ModuleName PowerArubaSW Invoke-WebRequest {
            param($Uri, $Body, $SessionVariable)
            $script:LoginUri = $Uri
            $script:LoginBody = $Body
            $ws = [Microsoft.PowerShell.Commands.WebRequestSession]::new()
            & (Get-Module PowerArubaSW) { param($n, $v) Set-Variable -Name $n -Value $v -Scope Script } $SessionVariable $ws
            [pscustomobject]@{ content = '{"cookie":"sessionId=abc123"}' }
        }
        Mock -ModuleName PowerArubaSW Get-ArubaSWRestversion { [pscustomobject]@{ version = @('v3.0', 'v8.0') } }
        Mock -ModuleName PowerArubaSW Get-ArubaSWSystemStatusSwitch { [pscustomobject]@{ switch_type = 'ST_STANDALONE'; product_number = 'J1'; product_name = 'X' } }
        Mock -ModuleName PowerArubaSW Get-ArubaSWSystem { [pscustomobject]@{ name = 'sw1' } }
        Mock -ModuleName PowerArubaSW Test-ArubaSWCredentialStore { $true }
        Mock -ModuleName PowerArubaSW Get-ArubaSWStoredCredential { $null }
        Mock -ModuleName PowerArubaSW Get-Credential { throw 'Rueckfrage im Test gesperrt' }
    }

    AfterEach {
        if (Test-Path variable:global:DefaultArubaSWConnection) {
            Remove-Variable -Name DefaultArubaSWConnection -Scope Global -Force
        }
        & (Get-Module PowerArubaSW) { Remove-Variable -Name arubasw -Scope Script -ErrorAction SilentlyContinue }
    }

    It 'HTTPS ist Standard: Login-URL mit rest/v3, Standardport 443 (vom [Uri]-Cast im Mock verschluckt)' {
        $null = Connect-ArubaSW -Server '198.51.100.1' -Credentials $Cred -DefaultConnection:$false
        $LoginUri | Should -Be 'https://198.51.100.1/rest/v3/login-sessions'
    }

    It '-httpOnly -Force: http-URL, Standardport 80' {
        $null = Connect-ArubaSW -Server '198.51.100.1' -Credentials $Cred -httpOnly -Force -DefaultConnection:$false
        $LoginUri | Should -Be 'http://198.51.100.1/rest/v3/login-sessions'
    }

    It '-port und -api_version gehen in die Login-URL' {
        $null = Connect-ArubaSW -Server '198.51.100.1' -Credentials $Cred -port 4443 -api_version 2 -DefaultConnection:$false
        $LoginUri | Should -Be 'https://198.51.100.1:4443/rest/v2/login-sessions'
    }

    It '-Username/-Password landen im Login-Body' {
        $null = Connect-ArubaSW -Server '198.51.100.1' -Username 'pw-user' -Password (ConvertTo-SecureString 'pw-secret' -AsPlainText -Force) -DefaultConnection:$false
        $body = $LoginBody | ConvertFrom-Json
        $body.userName | Should -Be 'pw-user'
        $body.password | Should -Be 'pw-secret'
    }

    It '-CredentialTarget liest dieses Ziel aus dem Store, der Benutzer kommt aus dem Eintrag' {
        Mock -ModuleName PowerArubaSW Get-ArubaSWStoredCredential { [pscredential]::new('store-user', (ConvertTo-SecureString 'store-pw' -AsPlainText -Force)) }
        $null = Connect-ArubaSW -Server '198.51.100.1' -CredentialTarget 'SwitchLab' -DefaultConnection:$false
        Should -Invoke -ModuleName PowerArubaSW Get-ArubaSWStoredCredential -Times 1 -Exactly -ParameterFilter { $Target -eq 'SwitchLab' }
        ($LoginBody | ConvertFrom-Json).userName | Should -Be 'store-user'
    }

    It 'liefert die Verbindung mit Server, Port, api_version (min, max, cur) und Produktnummer' {
        $c = Connect-ArubaSW -Server '198.51.100.1' -Credentials $Cred -DefaultConnection:$false
        $c.server | Should -Be '198.51.100.1'
        $c.port | Should -Be 443
        $c.api_version.min | Should -Be 3
        $c.api_version.max | Should -Be 8
        $c.api_version.cur | Should -Be 8
        $c.product_number | Should -Be 'J1'
    }

    It 'DefaultConnection: Standard setzt die globale Verbindung, :$false nicht' {
        $null = Connect-ArubaSW -Server '198.51.100.1' -Credentials $Cred -DefaultConnection:$false
        (Test-Path variable:global:DefaultArubaSWConnection) | Should -BeFalse
        $null = Connect-ArubaSW -Server '198.51.100.1' -Credentials $Cred
        (Test-Path variable:global:DefaultArubaSWConnection) | Should -BeTrue
    }

    It 'ein fehlgeschlagener Login endet mit "Unable to connect"' {
        Mock -ModuleName PowerArubaSW Invoke-WebRequest { throw 'mocked: kein Netzwerk' }
        Mock -ModuleName PowerArubaSW Show-ArubaSWException { }
        { Connect-ArubaSW -Server '198.51.100.1' -Credentials $Cred -ErrorAction Stop } |
            Should -Throw -ExpectedMessage '*Unable to connect*'
    }

    It 'Stack mit einer Einheit: Produktnummer der einen Einheit' {
        Mock -ModuleName PowerArubaSW Get-ArubaSWSystemStatusSwitch {
            [pscustomobject]@{ switch_type = 'ST_STACKED'; blades = [pscustomobject]@{ product_number = 'J-ONE'; product_name = 'Eins' } }
        }
        $c = Connect-ArubaSW -Server '198.51.100.1' -Credentials $Cred -DefaultConnection:$false
        $c.switch_type | Should -Be 'ST_STACKED'
        $c.product_number | Should -Be 'J-ONE'
    }

    It 'Stack mit mehreren Einheiten: Produktnummer der ersten, Produktnamen im Verbose-Text mit Komma' {
        Mock -ModuleName PowerArubaSW Get-ArubaSWSystemStatusSwitch {
            [pscustomobject]@{ switch_type = 'ST_STACKED'; blades = @(
                [pscustomobject]@{ product_number = 'J-A'; product_name = 'Alpha' },
                [pscustomobject]@{ product_number = 'J-B'; product_name = $null },
                [pscustomobject]@{ product_number = 'J-C'; product_name = 'Gamma' }) }
        }
        $c = Connect-ArubaSW -Server '198.51.100.1' -Credentials $Cred -DefaultConnection:$false -Verbose 4>&1 | Where-Object { $_ -is [pscustomobject] -or $_ -is [hashtable] }
        $c.product_number | Should -Be 'J-A'
        $text = (Connect-ArubaSW -Server '198.51.100.1' -Credentials $Cred -DefaultConnection:$false -Verbose 4>&1 | Where-Object { $_ -is [System.Management.Automation.VerboseRecord] }).Message -join ' '
        $text | Should -BeExactly 'Welcome on sw1 -Alpha, Gamma'
    }

    It 'Einzelner Switch: Verbose-Text mit Systemname und Produktname' {
        $text = (Connect-ArubaSW -Server '198.51.100.1' -Credentials $Cred -DefaultConnection:$false -Verbose 4>&1 | Where-Object { $_ -is [System.Management.Automation.VerboseRecord] }).Message -join ' '
        $text | Should -BeExactly 'Welcome on sw1 -X'
    }

    It 'merkt Server, Cookie, Switch-Typ und Verbindungsart (httpOnly) in der Verbindung' {
        $c = Connect-ArubaSW -Server '198.51.100.1' -Credentials $Cred -httpOnly -Force -DefaultConnection:$false
        $c.httpOnly | Should -BeTrue
        $c.port | Should -Be 80
        $c.cookie | Should -BeExactly 'sessionId=abc123'
        $c.switch_type | Should -Be 'ST_STANDALONE'
        $c2 = Connect-ArubaSW -Server '198.51.100.1' -Credentials $Cred -DefaultConnection:$false
        $c2.httpOnly | Should -BeFalse
    }

    It 'legt den Session-Cookie (Wert hinter dem "=") in die Session' {
        $c = Connect-ArubaSW -Server '198.51.100.1' -Credentials $Cred -DefaultConnection:$false
        $c.session.Cookies.Count | Should -Be 1
        $cookie = $c.session.Cookies.GetCookies([uri]'https://198.51.100.1/')['sessionId']
        $cookie.Value | Should -BeExactly 'abc123'
    }

    It 'PowerShell Core: invokeParams enthaelt SkipCertificateCheck, aber kein UseBasicParsing' {
        $c = Connect-ArubaSW -Server '198.51.100.1' -Credentials $Cred -SkipCertificateCheck -DefaultConnection:$false
        $c.invokeParams.ContainsKey('SkipCertificateCheck') | Should -BeTrue
        $c.invokeParams['SkipCertificateCheck'] | Should -BeTrue
        $c.invokeParams.ContainsKey('UseBasicParsing') | Should -BeFalse
        $c.invokeParams['DisableKeepAlive'] | Should -BeTrue
    }

    It 'api_version-Spanne aus den gemeldeten Versionen (v3.0 bis v8.0), -api_version setzt nur cur' {
        $c = Connect-ArubaSW -Server '198.51.100.1' -Credentials $Cred -api_version 5 -DefaultConnection:$false
        $c.api_version.min | Should -Be 3
        $c.api_version.max | Should -Be 8
        $c.api_version.cur | Should -Be 5
    }
}

Describe 'Connect-ArubaSW - Grenzwerte der Parameter-Validierung (I30, Mutationspruefung)' -Tag 'Unit' {

    BeforeAll {
        $script:Cred = [pscredential]::new('cred-user', (ConvertTo-SecureString 'cred-pw' -AsPlainText -Force))
        function Get-ConnectErrorId {
            param([hashtable]$Parameter)
            try { Connect-ArubaSW -Server '198.51.100.1' -Credentials $Cred -DefaultConnection:$false -ErrorAction Stop @Parameter | Out-Null }
            catch { return $_.FullyQualifiedErrorId }
            return 'kein Fehler'
        }
    }

    BeforeEach {
        Mock -ModuleName PowerArubaSW Invoke-WebRequest { throw 'mocked: kein Netzwerk' }
        Mock -ModuleName PowerArubaSW Show-ArubaSWException { }
    }

    It '-port: 65535 ist gueltig, 65536 und 0 sind es nicht' {
        Get-ConnectErrorId @{ port = 65535 } | Should -Not -Match 'ParameterArgumentValidationError'
        Get-ConnectErrorId @{ port = 1 } | Should -Not -Match 'ParameterArgumentValidationError'
        Get-ConnectErrorId @{ port = 65536 } | Should -Match 'ParameterArgumentValidationError'
        Get-ConnectErrorId @{ port = 0 } | Should -Match 'ParameterArgumentValidationError'
    }

    It '-api_version: 10 ist gueltig, 11 und 0 sind es nicht' {
        Get-ConnectErrorId @{ api_version = 10 } | Should -Not -Match 'ParameterArgumentValidationError'
        Get-ConnectErrorId @{ api_version = 1 } | Should -Not -Match 'ParameterArgumentValidationError'
        Get-ConnectErrorId @{ api_version = 11 } | Should -Match 'ParameterArgumentValidationError'
        Get-ConnectErrorId @{ api_version = 0 } | Should -Match 'ParameterArgumentValidationError'
    }
}
