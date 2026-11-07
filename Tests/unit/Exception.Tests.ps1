#
# Copyright 2026, PowerArubaSW contributors
# SPDX-License-Identifier: Apache-2.0
#
# Unit-Tests für Private/Exception.ps1 (Show-ArubaSWException).
# Auslöser (I35): Am echten Switch (HTTP 404) warf die Funktion unter PowerShell 7 im Strict Mode
# "Die Variable $responseBody kann nicht abgerufen werden", weil sie nur im Desktop-Zweig gesetzt wurde.
# Die Meldung des Switches ging verloren. Webrequest.Tests mockt die Funktion, daher fiel das nie auf.

BeforeAll {
    $script:UnitDir    = Split-Path -Parent $PSCommandPath
    $script:TestsRoot  = Split-Path -Parent $UnitDir
    $script:RepoRoot   = Split-Path -Parent $TestsRoot
    $script:Manifest   = Join-Path (Join-Path $RepoRoot 'PowerArubaSW') 'PowerArubaSW.psd1'

    $loaded = Get-Module -Name 'PowerArubaSW' -ErrorAction SilentlyContinue
    if ($loaded) { Remove-Module $loaded -Force }
    Import-Module $Manifest -Force

    # ErrorRecord mit Response-Eigenschaft (wie ihn Invoke-WebRequest unter Core liefert, Details in ErrorDetails).
    function script:New-HttpErrorRecord {
        param([int]$Code, [string]$Beschreibung, [string]$Details)
        $ex = [System.InvalidOperationException]::new('Antwort mit Fehlerstatus')
        $antwort = [pscustomobject]@{ StatusDescription = $Beschreibung; StatusCode = [System.Net.HttpStatusCode]$Code }
        Add-Member -InputObject $ex -MemberType NoteProperty -Name Response -Value $antwort
        $rec = [System.Management.Automation.ErrorRecord]::new($ex, 'HttpFehler', [System.Management.Automation.ErrorCategory]::InvalidOperation, $null)
        if ($Details) { $rec.ErrorDetails = [System.Management.Automation.ErrorDetails]::new($Details) }
        $rec
    }
}

Describe 'Show-ArubaSWException — Antwort mit Statuscode (Core, Strict Mode)' -Tag 'Unit' {
    It 'wirft nicht und gibt Statuscode und Beschreibung aus (ohne ErrorDetails)' {
        $rec = New-HttpErrorRecord -Code 404 -Beschreibung 'Not Found'
        $warnungen = & { InModuleScope PowerArubaSW -Parameters @{ Rec = $rec } { param($Rec) Show-ArubaSWException -Exception $Rec 3>&1 } }
        $text = ($warnungen | ForEach-Object { "$_" }) -join "`n"
        $text | Should -Match 'Not Found'
        $text | Should -Match '\(404\)'
    }

    It 'gibt die Fehlerdetails der Antwort aus, wenn ErrorDetails gesetzt ist' {
        $rec = New-HttpErrorRecord -Code 400 -Beschreibung 'Bad Request' -Details 'Ungueltiger Wert im Feld name'
        $warnungen = & { InModuleScope PowerArubaSW -Parameters @{ Rec = $rec } { param($Rec) Show-ArubaSWException -Exception $Rec 3>&1 } }
        (($warnungen | ForEach-Object { "$_" }) -join "`n") | Should -Match 'Ungueltiger Wert im Feld name'
    }
}

Describe 'Show-ArubaSWException — echte HttpResponseMessage (Core: ReasonPhrase statt StatusDescription)' -Tag 'Unit' {
    It 'gibt die ReasonPhrase als Beschreibung aus und wirft auch unter Strict Mode 3.0 nicht' {
        $ex = [System.InvalidOperationException]::new('Antwort mit Fehlerstatus')
        $antwort = [System.Net.Http.HttpResponseMessage]::new([System.Net.HttpStatusCode]::NotFound)
        Add-Member -InputObject $ex -MemberType NoteProperty -Name Response -Value $antwort
        $rec = [System.Management.Automation.ErrorRecord]::new($ex, 'HttpFehler', [System.Management.Automation.ErrorCategory]::InvalidOperation, $null)
        $warnungen = & { InModuleScope PowerArubaSW -Parameters @{ Rec = $rec } { param($Rec) Set-StrictMode -Version 3.0; Show-ArubaSWException -Exception $Rec 3>&1 } }
        $text = ($warnungen | ForEach-Object { "$_" }) -join "`n"
        $text | Should -Match 'Not Found'
        $text | Should -Match '\(404\)'
    }
}

Describe 'Show-ArubaSWException — ohne Antwort' -Tag 'Unit' {
    It 'gibt nichts aus und wirft auch unter Strict Mode 3.0 nicht (Verbindungsfehler ohne Response-Eigenschaft)' {
        $rec = [System.Management.Automation.ErrorRecord]::new([System.InvalidOperationException]::new('kein Netz'), 'x', 'InvalidOperation', $null)
        $warnungen = & { InModuleScope PowerArubaSW -Parameters @{ Rec = $rec } { param($Rec) Set-StrictMode -Version 3.0; Show-ArubaSWException -Exception $Rec 3>&1 } }
        @($warnungen).Count | Should -Be 0
    }
}
