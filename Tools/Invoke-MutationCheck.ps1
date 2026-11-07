#
# Copyright 2026, PowerArubaSW contributors
# SPDX-License-Identifier: Apache-2.0
#
<#
    .SYNOPSIS
    Mutationspruefung von Hand (Inkrement I30, ohne externes Werkzeug).

    .DESCRIPTION
    Arbeitet auf einer TEMPORAEREN KOPIE des Repos (PowerArubaSW/ und Tests/ ohne integration/), nie im Arbeitsverzeichnis.
    Je Mutant aus der Datendatei (Standard: Tools/MutationCheck.Mutants.psd1): eine Textstelle in einer Modul-Datei ersetzen,
    die zugehoerigen Pester-Dateien in einem EIGENEN pwsh-Prozess laufen lassen (nie im Prozess dieses Skripts), danach die
    Datei aus der Sicherung zurueckkopieren und per Hash gegenpruefen.
      killed    mindestens ein Test schlaegt fehl (oder der Lauf bricht ab / laeuft in das Zeitlimit)
      survived  alle Tests bestehen trotz Mutation -> Testluecke oder aequivalenter Mutant (von Hand begruenden)
    Vorher laeuft je Testmenge ein Basislauf ohne Mutation; schlaegt er fehl, bricht das Skript ab.
    Die Fundstelle (Find) muss genau einmal vorkommen, sonst ist der Mutant fehlerhaft definiert - oder der Mutant nennt mit Nth die
    n-te Fundstelle (1-basiert) einer mehrfach vorkommenden Zeichenkette.

    .PARAMETER MutantsFile
    psd1 (oder json) mit @( @{ Id; File; Find; Replace; Tests; Note; Nth (optional) } ), json: { "Mutants": [ ... ] }. File relativ zum Repo-Root, Tests relativ zum Repo-Root.

    .PARAMETER OnlyId
    Nur diese Mutant-Ids ausfuehren.

    .PARAMETER TimeoutSeconds
    Zeitlimit je Pester-Lauf (Standard 240).

    .PARAMETER OutFile
    Optional: Ergebnis als JSON speichern.

    .EXAMPLE
    pwsh -NoProfile -File Tools\Invoke-MutationCheck.ps1

    Alle Mutanten ausfuehren und die Tabelle ausgeben.
#>
[CmdletBinding()]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Interaktives Werkzeug - Ausgabe gehoert an den Host.')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'TimeoutSeconds', Justification = 'Wird in der verschachtelten Funktion Invoke-PesterIsoliert gelesen (PSSA sieht das nicht).')]
Param(
    [string]$MutantsFile = (Join-Path $PSScriptRoot 'MutationCheck.Mutants.psd1'),
    [string[]]$OnlyId,
    [int]$TimeoutSeconds = 240,
    [string]$OutFile
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$repo = Split-Path -Parent $PSScriptRoot
# .psd1 (Import-PowerShellDataFile erlaubt hoechstens 500 Schluessel je Datei) oder .json fuer grosse Mutantenmengen
$mutants = if ($MutantsFile -like '*.json') {
    @((Get-Content -LiteralPath $MutantsFile -Raw -Encoding UTF8 | ConvertFrom-Json -AsHashtable).Mutants)
}
else {
    @(Import-PowerShellDataFile -LiteralPath $MutantsFile).Mutants
}
if ($OnlyId) {
    $OnlyId = @($OnlyId | ForEach-Object { $_ -split ',' })   # -File uebergibt eine Komma-Liste als einen String
    $mutants = @($mutants | Where-Object { $_.Id -in $OnlyId })
}
if (-not $mutants) { throw 'Keine Mutanten ausgewaehlt.' }

# --- temporaere Kopie ---------------------------------------------------------------------------------------------
$work = Join-Path ([System.IO.Path]::GetTempPath()) ('arubasw-mut-' + [guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $work
Copy-Item -LiteralPath (Join-Path $repo 'PowerArubaSW') -Destination (Join-Path $work 'PowerArubaSW') -Recurse
$null = New-Item -ItemType Directory -Path (Join-Path $work 'Tests')
foreach ($d in Get-ChildItem -LiteralPath (Join-Path $repo 'Tests') -Directory | Where-Object Name -ne 'integration') {
    Copy-Item -LiteralPath $d.FullName -Destination (Join-Path $work 'Tests') -Recurse
}
Get-ChildItem -LiteralPath (Join-Path $repo 'Tests') -File | Where-Object { $_.Name -notmatch 'credential\.ps1$|\.xml$' } |
    Copy-Item -Destination (Join-Path $work 'Tests')
$backup = Join-Path $work '_original'
$null = New-Item -ItemType Directory -Path $backup

# --- Hilfen -------------------------------------------------------------------------------------------------------
$runner = Join-Path $work '_run.ps1'
@'
param([string]$Tests, [string]$OutJson)
Import-Module Pester -RequiredVersion 5.7.1
$cfg = New-PesterConfiguration
$cfg.Run.Path = [string[]]($Tests -split ';')
$cfg.Run.PassThru = $true
$cfg.Output.Verbosity = 'None'
$r = Invoke-Pester -Configuration $cfg 6>$null 3>$null
[pscustomobject]@{ Passed = $r.PassedCount; Failed = $r.FailedCount; Total = $r.TotalCount; Result = "$($r.Result)" } | ConvertTo-Json -Compress | Set-Content -LiteralPath $OutJson
'@ | Set-Content -LiteralPath $runner -Encoding utf8

function Invoke-PesterIsoliert {
    param([string[]]$Tests)
    $json = Join-Path $work ('res-' + [guid]::NewGuid().ToString('N') + '.json')
    # -NonInteractive: sonst fragt PowerShell bei fehlenden Pflichtparametern (z. B. Connect-ArubaSW ohne -Server) auf der Konsole nach und haengt.
    $argList = @('-NoProfile', '-NonInteractive', '-File', $runner, '-OutJson', $json, '-Tests', (($Tests | ForEach-Object { Join-Path $work $_ }) -join ';'))
    $p = Start-Process -FilePath 'pwsh' -ArgumentList $argList -PassThru -WindowStyle Hidden `
        -RedirectStandardOutput (Join-Path $work 'out.txt') -RedirectStandardError (Join-Path $work 'err.txt')
    if (-not $p.WaitForExit($TimeoutSeconds * 1000)) {
        $p.Kill($true)
        return [pscustomobject]@{ Passed = 0; Failed = -1; Total = 0; Result = 'Timeout' }
    }
    if (-not (Test-Path -LiteralPath $json)) { return [pscustomobject]@{ Passed = 0; Failed = -1; Total = 0; Result = "Abbruch (Exit $($p.ExitCode))" } }
    Get-Content -LiteralPath $json -Raw | ConvertFrom-Json
}

function Read-TextBom {
    param([string]$Path)
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    $bom = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
    [pscustomobject]@{ Text = [System.Text.UTF8Encoding]::new($false).GetString($bytes, $(if ($bom) { 3 } else { 0 }), $bytes.Length - $(if ($bom) { 3 } else { 0 })); Bom = $bom }
}

function Write-TextBom {
    param([string]$Path, [string]$Text, [bool]$Bom)
    [System.IO.File]::WriteAllBytes($Path, ($(if ($Bom) { [byte[]](0xEF, 0xBB, 0xBF) } else { [byte[]]@() }) + [System.Text.UTF8Encoding]::new($false).GetBytes($Text)))
}

try {
    # --- Basislaeufe ----------------------------------------------------------------------------------------------
    $testSets = $mutants | ForEach-Object { , ($_.Tests -join '|') } | Select-Object -Unique
    foreach ($set in $testSets) {
        $r = Invoke-PesterIsoliert -Tests ($set -split '\|')
        if ($r.Failed -ne 0) { throw "Basislauf nicht gruen fuer [$set]: $($r.Result), Failed=$($r.Failed)" }
        Write-Host "Basislauf [$set]: $($r.Passed)/$($r.Total) bestanden"
    }

    # --- Mutanten -------------------------------------------------------------------------------------------------
    $results = foreach ($m in $mutants) {
        $path = Join-Path $work $m.File
        $orig = Join-Path $backup ($m.File -replace '[\\/]', '__')
        if (-not (Test-Path -LiteralPath $orig)) { Copy-Item -LiteralPath $path -Destination $orig }
        $hashVorher = (Get-FileHash -LiteralPath $orig -Algorithm SHA256).Hash
        $file = Read-TextBom -Path $orig
        $alle = [regex]::Matches($file.Text, [regex]::Escape($m.Find))
        $treffer = $alle.Count
        if ($m.ContainsKey('Nth')) {
            # Nth: mehrfach vorkommende Fundstelle, nur die n-te (1-basiert) wird ersetzt
            if ($treffer -lt $m.Nth) { throw "Mutant $($m.Id): Fundstelle kommt $treffer-mal vor, Nth=$($m.Nth) in $($m.File)" }
            $z = $alle[$m.Nth - 1]
            $mutiert = $file.Text.Substring(0, $z.Index) + $m.Replace + $file.Text.Substring($z.Index + $z.Length)
        }
        else {
            if ($treffer -ne 1) { throw "Mutant $($m.Id): Fundstelle kommt $treffer-mal vor (erwartet: genau 1) in $($m.File)" }
            $mutiert = $file.Text.Replace($m.Find, $m.Replace)
        }
        Write-TextBom -Path $path -Text $mutiert -Bom $file.Bom
        try {
            $r = Invoke-PesterIsoliert -Tests $m.Tests
        }
        finally {
            Copy-Item -LiteralPath $orig -Destination $path -Force
            if ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ne $hashVorher) { throw "Wiederherstellung von $($m.File) fehlgeschlagen" }
        }
        $status = if ($r.Failed -ne 0) { 'killed' } else { 'survived' }
        Write-Host ("{0,-8} {1,-9} {2}" -f $m.Id, $status, $m.Note)
        [pscustomobject]@{ Id = $m.Id; File = $m.File; Status = $status; Failed = $r.Failed; Result = $r.Result; Note = $m.Note }
    }
}
finally {
    Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
}

$killed = @($results | Where-Object Status -eq 'killed').Count
$total = @($results).Count
Write-Host ("`nMutationsscore: {0}/{1} getoetet ({2:P0}); ueberlebt: {3}" -f $killed, $total, ($killed / [math]::Max(1, $total)), ($total - $killed))
if ($OutFile) { $results | ConvertTo-Json | Set-Content -LiteralPath $OutFile -Encoding utf8 }
$results | Where-Object Status -eq 'survived' | ForEach-Object { Write-Host "  ueberlebt: $($_.Id) - $($_.Note)" }
