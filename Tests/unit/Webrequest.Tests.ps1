#
# Copyright 2026, PowerArubaSW contributors
# SPDX-License-Identifier: Apache-2.0
#
# Unit-Tests für Private/Webrequest.ps1 — den zentralen Transport-Wrapper.
# Mockt die eingebaute Invoke-WebRequest auf Modul-Scope und prüft URL-Aufbau,
# HTTPS/HTTP-Pfad, api_version-Behandlung und Body-Serialisierung.

BeforeAll {
    $script:UnitDir    = Split-Path -Parent $PSCommandPath
    $script:TestsRoot  = Split-Path -Parent $UnitDir
    $script:RepoRoot   = Split-Path -Parent $TestsRoot
    $script:ModuleRoot = Join-Path $RepoRoot 'PowerArubaSW'
    $script:Manifest   = Join-Path $ModuleRoot 'PowerArubaSW.psd1'

    $loaded = Get-Module -Name 'PowerArubaSW' -ErrorAction SilentlyContinue
    if ($loaded) { Remove-Module $loaded -Force }
    Import-Module $Manifest -Force

    # Bewusst NICHT-Standard-Ports verwenden: .NETs System.Uri normalisiert
    # 443 bei https / 80 bei http weg, sobald Pesters Mock den Wert als [Uri]
    # binded — der Test würde dann den explizit gesetzten Port nicht mehr im
    # Mock sehen. 4443/8080 stehen im URI sichtbar und prüfen die Port-Logik.
    $script:StubConnection = [PSCustomObject]@{
        server       = '198.51.100.1'
        port         = 4443
        httpOnly     = $false
        invokeParams = @{}
        session      = $null
        api_version  = @{ cur = 8 }
    }
    $script:StubConnectionHttp = [PSCustomObject]@{
        server       = '198.51.100.1'
        port         = 8080
        httpOnly     = $true
        invokeParams = @{}
        session      = $null
        api_version  = @{ cur = 3 }
    }
}

Describe 'Invoke-ArubaSWWebRequest — Connection-Handling' -Tag 'Unit' {

    AfterEach {
        if (Test-Path variable:global:DefaultArubaSWConnection) {
            Remove-Variable -Name DefaultArubaSWConnection -Scope Global -Force
        }
    }

    It 'wirft "Not Connected" wenn weder -connection noch $DefaultArubaSWConnection gesetzt ist' {
        { Invoke-ArubaSWWebRequest -method GET -uri 'vlans' -ErrorAction Stop } |
            Should -Throw -ExpectedMessage '*Not Connected*'
    }

    It 'fällt auf $DefaultArubaSWConnection zurück, wenn -connection nicht übergeben wird' {
        Set-Variable -Name DefaultArubaSWConnection -Value $StubConnection -Scope Global -Force
        Mock -ModuleName PowerArubaSW Invoke-WebRequest {
            [PSCustomObject]@{ Content = '{}' }
        }
        $null = Invoke-ArubaSWWebRequest -method GET -uri 'vlans'
        Should -Invoke -ModuleName PowerArubaSW Invoke-WebRequest -Times 1 -Exactly
    }
}

Describe 'Invoke-ArubaSWWebRequest — URL-Aufbau' -Tag 'Unit' {

    BeforeEach {
        $script:CapturedUrl = $null
        $script:CapturedMethod = $null
        Mock -ModuleName PowerArubaSW Invoke-WebRequest {
            param($Uri, $Method)
            $script:CapturedUrl = $Uri
            $script:CapturedMethod = $Method
            [PSCustomObject]@{ Content = '{}' }
        }
    }

    It 'baut eine HTTPS-URL mit Port und api_version aus dem Connection-Objekt' {
        $null = Invoke-ArubaSWWebRequest -method GET -uri 'vlans' -connection $StubConnection
        $CapturedUrl | Should -Be 'https://198.51.100.1:4443/rest/v8/vlans'
        $CapturedMethod | Should -Be 'GET'
    }

    It 'baut eine HTTP-URL bei httpOnly=$true' {
        $null = Invoke-ArubaSWWebRequest -method GET -uri 'vlans' -connection $StubConnectionHttp
        $CapturedUrl | Should -Be 'http://198.51.100.1:8080/rest/v3/vlans'
    }

    It 'überschreibt api_version aus dem Connection-Objekt mit dem -api_version-Parameter' {
        $null = Invoke-ArubaSWWebRequest -method GET -uri 'vlans' -api_version 4 -connection $StubConnection
        $CapturedUrl | Should -Be 'https://198.51.100.1:4443/rest/v4/vlans'
    }

    It 'lässt das "rest/vX/"-Präfix weg bei -api_version 0 (absolute URIs)' {
        $null = Invoke-ArubaSWWebRequest -method GET -uri '/rest/v8/system' -api_version 0 -connection $StubConnection
        $CapturedUrl | Should -Be 'https://198.51.100.1:4443//rest/v8/system'
    }
}

Describe 'Invoke-ArubaSWWebRequest — Body-Serialisierung' -Tag 'Unit' {

    BeforeEach {
        $script:CapturedBody = $null
        Mock -ModuleName PowerArubaSW Invoke-WebRequest {
            param($Body)
            $script:CapturedBody = $Body
            [PSCustomObject]@{ Content = '{}' }
        }
    }

    It 'serialisiert -body via ConvertTo-Json' {
        $payload = [PSCustomObject]@{ vlan_id = 85; name = 'PowerArubaSW' }
        $null = Invoke-ArubaSWWebRequest -method POST -uri 'vlans' -body $payload -connection $StubConnection
        $obj = $CapturedBody | ConvertFrom-Json
        $obj.vlan_id | Should -Be 85
        $obj.name    | Should -Be 'PowerArubaSW'
    }

    It 'sendet keinen Body wenn -body nicht angegeben' {
        $null = Invoke-ArubaSWWebRequest -method GET -uri 'vlans' -connection $StubConnection
        $CapturedBody | Should -BeNullOrEmpty
    }
}

Describe 'Invoke-ArubaSWWebRequest — Fehlerpfad' -Tag 'Unit' {

    It 'wandelt Invoke-WebRequest-Fehler in "Unable to use switch API" um' {
        Mock -ModuleName PowerArubaSW Invoke-WebRequest { throw 'simulated network error' }
        # Show-ArubaSWException mocken, damit die Fehler-Ausgabe nicht den Test-Output flutet
        Mock -ModuleName PowerArubaSW Show-ArubaSWException { }
        { Invoke-ArubaSWWebRequest -method GET -uri 'vlans' -connection $StubConnection -ErrorAction Stop } |
            Should -Throw -ExpectedMessage '*Unable to use switch API*'
        Should -Invoke -ModuleName PowerArubaSW Show-ArubaSWException -Times 1 -Exactly
    }
}

Describe 'Invoke-ArubaSWWebRequest — Parameter-Validierung' -Tag 'Unit' {

    It 'lehnt ungültiges -method ab (ValidateSet GET/POST/DELETE/PUT)' {
        { Invoke-ArubaSWWebRequest -method PATCH -uri 'vlans' -connection $StubConnection -ErrorAction Stop } |
            Should -Throw -ErrorId 'ParameterArgumentValidationError,Invoke-ArubaSWWebRequest'
    }

    It 'lehnt -api_version außerhalb 0–10 ab' {
        { Invoke-ArubaSWWebRequest -method GET -uri 'vlans' -api_version -1 -connection $StubConnection -ErrorAction Stop } |
            Should -Throw -ErrorId 'ParameterArgumentValidationError,Invoke-ArubaSWWebRequest'
        { Invoke-ArubaSWWebRequest -method GET -uri 'vlans' -api_version 11 -connection $StubConnection -ErrorAction Stop } |
            Should -Throw -ErrorId 'ParameterArgumentValidationError,Invoke-ArubaSWWebRequest'
    }
}

Describe 'Invoke-ArubaSWWebRequest - Standardwerte und Durchreichen (I30, Mutationspruefung)' -Tag 'Unit' {

    BeforeEach {
        $script:Captured = @{}
        Mock -ModuleName PowerArubaSW Invoke-WebRequest {
            param($Method, $WebSession, $MaximumRedirection)
            $script:Captured = @{ Method = $Method; WebSession = $WebSession; MaximumRedirection = $MaximumRedirection }
            [PSCustomObject]@{ Content = '{}' }
        }
    }

    It 'ohne -method wird GET gesendet' {
        $null = Invoke-ArubaSWWebRequest -uri 'vlans' -connection $StubConnection
        $Captured.Method | Should -Be 'GET'
    }

    It 'reicht invokeParams der Verbindung an Invoke-WebRequest durch' {
        $conn = [PSCustomObject]@{
            server = '198.51.100.1'; port = 443; httpOnly = $false; session = $null
            invokeParams = @{ MaximumRedirection = 3 }; api_version = @{ cur = 8 }
        }
        $null = Invoke-ArubaSWWebRequest -method GET -uri 'vlans' -connection $conn
        $Captured.MaximumRedirection | Should -Be 3
    }

    It 'sendet die Session (Cookie) der Verbindung mit' {
        $session = [Microsoft.PowerShell.Commands.WebRequestSession]::new()
        $conn = [PSCustomObject]@{
            server = '198.51.100.1'; port = 443; httpOnly = $false; session = $session
            invokeParams = @{}; api_version = @{ cur = 8 }
        }
        $null = Invoke-ArubaSWWebRequest -method GET -uri 'vlans' -connection $conn
        [object]::ReferenceEquals($Captured.WebSession, $session) | Should -BeTrue
    }
}
