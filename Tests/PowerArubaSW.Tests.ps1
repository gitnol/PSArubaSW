#
# Copyright 2026, PowerArubaSW contributors
# SPDX-License-Identifier: Apache-2.0
#
# Modul- / Manifest- / Export-Surface-Tests. Hardware-frei, läuft in CI.
#
# Lauf:
#   Invoke-Pester ./Tests/PowerArubaSW.Tests.ps1 -Output Detailed
#
# Diese Tests sichern unter anderem ab:
#   - Manifest-Gültigkeit (I1 / Bootstrap-Voraussetzung)
#   - FunctionsToExport ist eine explizite Liste, kein '*'                 (Regression für I3)
#   - jede Funktion aus PowerArubaSW/Public/*.ps1 ist exportiert             (Regression für I3)
#   - die internen Helfer aus PowerArubaSW/Private/ sind NICHT exportiert    (Regression für I3)

BeforeAll {
    $script:TestsRoot   = Split-Path -Parent $PSCommandPath
    $script:RepoRoot    = Split-Path -Parent $TestsRoot
    $script:ModuleRoot  = Join-Path $RepoRoot 'PowerArubaSW'
    $script:Manifest    = Join-Path $ModuleRoot 'PowerArubaSW.psd1'
    $script:PublicPath  = Join-Path $ModuleRoot 'Public'
    $script:PrivatePath = Join-Path $ModuleRoot 'Private'

    # Frischen Modul-Stand erzwingen, damit Re-Runs nicht den vorherigen Import sehen
    $loaded = Get-Module -Name 'PowerArubaSW' -ErrorAction SilentlyContinue
    if ($loaded) { Remove-Module $loaded -Force }
    Import-Module $Manifest -Force

    # Funktionsnamen aus den Public-/Private-Dateien per Source ermitteln —
    # die einzige stack-unabhängige Wahrheitsquelle für „was ist gedacht-öffentlich?"
    function Get-FunctionsInPath {
        param([Parameter(Mandatory)][string]$Path)
        Get-ChildItem $Path -Filter *.ps1 | ForEach-Object {
            Select-String -Path $_.FullName -Pattern '^\s*function\s+([A-Za-z][A-Za-z0-9-]+)' -AllMatches |
                ForEach-Object { $_.Matches.Groups[1].Value }
        } | Sort-Object -Unique
    }

    $script:PublicFunctions  = Get-FunctionsInPath -Path $PublicPath
    $script:PrivateFunctions = Get-FunctionsInPath -Path $PrivatePath
    $script:ExportedFunctions = (Get-Command -Module PowerArubaSW -CommandType Function).Name | Sort-Object

    # Bewusste öffentliche Ausnahme aus Private/: der Transport-Wrapper, der laut
    # README öffentlich nutzbar sein soll.
    $script:DocumentedPublicPrivateExceptions = @('Invoke-ArubaSWWebRequest')
}

Describe 'Manifest' -Tag 'Unit' {

    It 'PowerArubaSW.psd1 ist ein gültiges Modul-Manifest' {
        { Test-ModuleManifest -Path $Manifest } | Should -Not -Throw
    }

    It 'meldet ModuleVersion 1.0.0' {
        (Test-ModuleManifest -Path $Manifest).Version | Should -Be ([Version]'1.0.0')
    }

    It 'pinnt FunctionsToExport auf eine explizite Liste (kein ''*'')' {
        # Regression für I3: '*' würde private Helfer leaken.
        $data = Import-PowerShellDataFile -Path $Manifest
        $data.FunctionsToExport | Should -Not -Be '*'
        ($data.FunctionsToExport -is [Array]) | Should -BeTrue -Because 'FunctionsToExport muss ein Array sein, nicht ein Einzel-String'
        $data.FunctionsToExport.Count | Should -BeGreaterThan 1
    }

}

Describe 'Exportierte Oberfläche' -Tag 'Unit' {

    It 'jede Funktion aus Public/ ist exportiert' {
        $missing = $PublicFunctions | Where-Object { $ExportedFunctions -notcontains $_ }
        $missing | Should -BeNullOrEmpty -Because "fehlend: $($missing -join ', ')"
    }

    It 'keine interne Funktion aus Private/ wird ungewollt exportiert' {
        # Erlaubt sind nur explizit dokumentierte Ausnahmen (Invoke-ArubaSWWebRequest).
        $leaked = $PrivateFunctions |
            Where-Object { $ExportedFunctions -contains $_ } |
            Where-Object { $DocumentedPublicPrivateExceptions -notcontains $_ }
        $leaked | Should -BeNullOrEmpty -Because "leaked: $($leaked -join ', ')"
    }

    It 'die dokumentierte öffentliche Ausnahme aus Private/ ist exportiert' {
        $ExportedFunctions | Should -Contain 'Invoke-ArubaSWWebRequest'
    }

    It 'kein-mehr-exportierter interner Helfer aus Inkrement I3 ist wieder aufgetaucht' {
        # Explizite Regression für I3 (2026-05-27): diese Funktionen DÜRFEN nicht exportiert sein.
        $forbidden = @(
            'Set-Cookie',
            'Show-ArubaSWException',
            'Set-ArubaSWuntrustedSSL',
            'Set-ArubaSWCipherSSL',
            'Restore-ArubaSWSSL'
        )
        $resurrected = $forbidden | Where-Object { $ExportedFunctions -contains $_ }
        $resurrected | Should -BeNullOrEmpty -Because "wieder exportiert: $($resurrected -join ', ')"
    }

}
