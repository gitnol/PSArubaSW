#
# Copyright 2026, PowerArubaSW contributors
# SPDX-License-Identifier: Apache-2.0
#
# Robustheitstest ueber alle exportierten Funktionen (Inkrement I30; Regel "Feindliche Eingaben"). Jede Funktion wird je Parametersatz mit
# feindlichen Werten aufgerufen. Ein Fehler ist in Ordnung - ein Haenger (Timeout) oder ein kaputter Runspace nicht.
# Die Liste kommt aus dem Modul-Export, neue Funktionen werden ohne Zutun mitgeprueft.
#
# Isolation: eigener Runspace (nur so laesst sich ein Haenger per Timeout abbrechen). Dort ersetzen Funktionen im
# Modul-Scope Netz (Invoke-ArubaSWWebRequest, Invoke-WebRequest), Credential Manager, Rueckfragen und Wartezeiten.
# Es wird nichts an einen Switch gesendet und nichts im echten Credential Manager gelesen oder geschrieben.

# PSSA-Ausnahme: Dummy-Passwort fuer die Test-Eingaben, nie ein echtes Geheimnis.
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingConvertToSecureStringWithPlainText", "")]
Param()

BeforeDiscovery {
    $manifest = Join-Path (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath))) 'PowerArubaSW\PowerArubaSW.psd1'
    Import-Module $manifest -Force
    $script:Funktionen = @((Get-Module PowerArubaSW).ExportedFunctions.Keys | Sort-Object | ForEach-Object { @{ Name = $_ } })
}

BeforeAll {
    $script:Manifest = Join-Path (Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath))) 'PowerArubaSW\PowerArubaSW.psd1'
    $script:Timeout  = [TimeSpan]::FromSeconds(10)
    $script:Profile  = 'leer', 'riesig', 'bereich', 'falscherTyp', 'minimal', 'pflicht'
    $script:Common   = [System.Management.Automation.PSCmdlet]::CommonParameters +
                       [System.Management.Automation.PSCmdlet]::OptionalCommonParameters

    function New-ArubaTestRunspace {
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Test-Fixture: Runspace nur fuer diesen Test.')]
        param([string] $Arbeitsordner)
        $rs = [runspacefactory]::CreateRunspace()
        $rs.Open()
        $ps = [powershell]::Create()
        $ps.Runspace = $rs
        $null = $ps.AddScript({
            param($Modul, $Ordner)
            Set-Location -LiteralPath $Ordner
            Import-Module $Modul -Force
            $stub = [pscustomobject]@{
                server = '198.51.100.1'; port = 443; httpOnly = $false; invokeParams = @{}; session = $null
                cookie = 'x'; api_version = @{ cur = 8; min = 1; max = 8 }; switch_type = 'ST_STANDALONE'; product_number = 'X'
            }
            Set-Variable -Name DefaultArubaSWConnection -Value $stub -Scope Global
            & (Get-Module PowerArubaSW) {
                function script:Invoke-ArubaSWWebRequest      { [pscustomobject]@{ content = '{}' } }
                function script:Invoke-WebRequest            { throw 'Netz im Robustheitstest gesperrt' }
                function script:Invoke-RestMethod            { throw 'Netz im Robustheitstest gesperrt' }
                function script:Test-ArubaSWCredentialStore  { $true }
                function script:Get-ArubaSWStoredCredential  { $null }
                function script:Set-ArubaSWStoredCredential  { }
                function script:Remove-ArubaSWStoredCredential { $true }
                function script:Get-Credential               { throw 'Rueckfrage im Robustheitstest gesperrt' }
                function script:Read-Host                    { throw 'Rueckfrage im Robustheitstest gesperrt' }
                function script:Start-Sleep                  { }
            }
        }).AddArgument($script:Manifest).AddArgument($Arbeitsordner)
        $null = $ps.Invoke()
        $ps.Dispose()
        return $rs
    }

    # Ein Aufruf mit Timeout. Ergebnis: 'ok' (fertig, auch mit Fehler), 'haenger' oder 'strict' (Strict-Mode-Fehler: eine Variable
    # wurde gelesen, bevor sie gesetzt war - ein Programmierfehler, kein Eingabefehler; I31, L44).
    function Invoke-ArubaTestAufruf {
        param($Runspace, [string] $Name, [hashtable] $Argumente, [TimeSpan] $Grenze)
        $ps = [powershell]::Create()
        $ps.Runspace = $Runspace
        $null = $ps.AddCommand($Name)
        foreach ($k in $Argumente.Keys) { $null = $ps.AddParameter($k, $Argumente[$k]) }
        $async = $ps.BeginInvoke()
        if (-not $async.AsyncWaitHandle.WaitOne($Grenze)) {
            $null = $ps.BeginStop($null, $null)   # nicht warten: ein blockierter Aufruf soll den Test nicht mitreissen
            return 'haenger'
        }
        $strict = $false
        try { $null = $ps.EndInvoke($async) } catch {   # Fehler sind erlaubt, ausser VariableIsUndefined
            $e = $_.Exception
            while ($e) { if ($e -is [System.Management.Automation.IContainsErrorRecord] -and $e.ErrorRecord.FullyQualifiedErrorId -eq 'VariableIsUndefined') { $strict = $true }; $e = $e.InnerException }
        }
        if (@($ps.Streams.Error | Where-Object { $_.FullyQualifiedErrorId -eq 'VariableIsUndefined' }).Count) { $strict = $true }
        $ps.Dispose()
        if ($strict) { return 'strict' }
        return 'ok'
    }

    # Wert je Parametertyp und Profil. ',$wert' haelt Arrays beim Zurueckgeben zusammen.
    function Get-ArubaTestWert {
        param($Parameter, [string] $Profil)
        $typ = $Parameter.ParameterType
        $art = if ($typ.IsArray) { 'array' }
               elseif ($typ -eq [string]) { 'string' }
               elseif ($typ -in [int], [long], [double]) { 'zahl' }
               elseif ($typ -eq [bool]) { 'bool' }
               elseif ($typ -eq [hashtable]) { 'hash' }
               elseif ($typ -eq [securestring]) { 'secure' }
               elseif ($typ -eq [pscredential]) { 'cred' }
               else { 'objekt' }
        $v = switch ($Profil) {
            'leer' {
                switch ($art) { 'string' { '' } 'zahl' { 0 } 'bool' { $false } 'hash' { @{} } 'array' { , @() } default { $null } }
            }
            'riesig' {
                switch ($art) {
                    'string' { 'x' * 100000 }
                    'zahl'   { [int]::MaxValue }
                    'bool'   { $true }
                    'hash'   { $h = @{}; foreach ($i in 1..1000) { $h["k$i"] = 'v' * 100 }; $h }
                    'array'  { , @(foreach ($i in 1..10000) { "e$i" }) }
                    'secure' { ConvertTo-SecureString ('p' * 4000) -AsPlainText -Force }
                    default  { [pscustomobject]@{ Id = 'x' * 100000; Name = 'x' * 100000 } }
                }
            }
            'bereich' {
                switch ($art) {
                    'string' { "..\..\robust<>|*?`"'`$(x)`0`r`n" }
                    'zahl'   { -1 }
                    'bool'   { $false }
                    'hash'   { @{ '' = $null; '..\..' = "<>`0" } }
                    'array'  { , @($null, '', -1, "a`r`nb") }
                    default  { [pscustomobject]@{} }
                }
            }
            'falscherTyp' {
                switch ($art) {
                    'string' { @{ a = 1 } } 'zahl' { 'keine Zahl' } 'bool' { 'vielleicht' } 'hash' { 'kein Hashtable' }
                    'array'  { 'kein Array' } 'secure' { 'Klartext' } 'cred' { 'kein Credential' } default { 'kein Objekt' }
                }
            }
            { $_ -in 'minimal', 'pflicht' } {
                # plausible, gueltige Werte, damit auch Code hinter der Parameterbindung laeuft;
                # 'pflicht' bindet davon nur die Pflichtparameter des Satzes (sonst bleiben Zweige ohne optionale Parameter ungeprueft)
                $set = $Parameter.Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] } | Select-Object -First 1
                $range = $Parameter.Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateRangeAttribute] } | Select-Object -First 1
                switch ($art) {
                    'string' { if ($set) { $set.ValidValues[0] } else { 'a' } }
                    'zahl'   { if ($range) { $range.MinRange } else { 1 } }
                    'bool'   { $true }
                    'hash'   { @{ a = 1 } }
                    'array'  { , @('a') }
                    'secure' { ConvertTo-SecureString 'dummy-pw' -AsPlainText -Force }
                    'cred'   { [pscredential]::new('u', (ConvertTo-SecureString 'dummy-pw' -AsPlainText -Force)) }
                    default  { [pscustomobject]@{ a = 1 } }
                }
            }
        }
        return , $v
    }

    $ordner = Join-Path $TestDrive 'robust\a\b'
    $null = New-Item -ItemType Directory -Path $ordner -Force
    $script:Arbeitsordner = $ordner
    $script:Rs = New-ArubaTestRunspace -Arbeitsordner $ordner
}

AfterAll {
    if ($script:Rs) { $script:Rs.Dispose() }
}

Describe 'Robustheit: feindliche Parameter fuer jede exportierte Funktion (I30)' -Tag 'Unit' {

    It 'prueft den vollstaendigen Export (Liste aus dem Modul, deckungsgleich mit dem Manifest)' {
        $manifest = (Import-PowerShellDataFile $script:Manifest).FunctionsToExport
        $export = @((Get-Module PowerArubaSW).ExportedFunctions.Keys)
        $export.Count | Should -Be @($manifest).Count
        $export.Count | Should -BeGreaterThan 90
    }

    It 'haengt nicht, bricht den Runspace nicht und liest keine ungesetzte Variable: <Name>' -ForEach $script:Funktionen {
        $cmd = Get-Command -Name $Name -Module PowerArubaSW
        $befund = foreach ($set in $cmd.ParameterSets) {
            $params = @($set.Parameters | Where-Object { $_.Name -notin $script:Common -and $_.ParameterType -ne [switch] })
            foreach ($profil in $script:Profile) {
                $argumente = @{}
                $gebunden = if ($profil -eq 'pflicht') { @($params | Where-Object IsMandatory) } else { $params }
                foreach ($p in $gebunden) { $argumente[$p.Name] = Get-ArubaTestWert -Parameter $p -Profil $profil }
                if ($cmd.Parameters.ContainsKey('Confirm')) { $argumente['Confirm'] = $false }   # Logik hinter ShouldProcess mitpruefen
                $r = Invoke-ArubaTestAufruf -Runspace $script:Rs -Name $Name -Argumente $argumente -Grenze $script:Timeout
                if ($r -ne 'ok') {
                    "$Name [$($set.Name)/$profil]: $r"
                }
                if ($r -eq 'haenger') {
                    $script:Rs = New-ArubaTestRunspace -Arbeitsordner $script:Arbeitsordner   # blockierten Runspace ersetzen
                }
            }
        }
        $script:Rs.RunspaceStateInfo.State | Should -Be 'Opened'
        @($befund) | Should -BeNullOrEmpty
    }
}
