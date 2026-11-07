#
# Copyright 2026, PowerArubaSW contributors
# SPDX-License-Identifier: Apache-2.0
#
<#
    .SYNOPSIS
    Schreibt Tests/unit/_data/RequestVertrag.json neu (Inkrement I34).

    .DESCRIPTION
    Ruft jedes exportierte Cmdlet je Parametersatz und Profil (pflicht, voll, aus) mit gemocktem Transport auf und speichert die entstehenden
    Anfragen (Methode, URI, Body). Tests/unit/RequestVertrag.Tests.ps1 vergleicht das Ergebnis mit dieser Datei. Ein Unterschied nach einer
    Code-Aenderung ist ein Verhaltenswechsel: Diff der JSON-Datei lesen, bewusst entscheiden, dann neu schreiben. Die Datei ist ein Schnappschuss
    des Ist-Verhaltens; die Uebereinstimmung der URIs mit der Spec prueft Tools/Report-EndpointCoverage.py (Drift soll 0 sein).
#>
[CmdletBinding()]
Param(
    [string]$Ziel = (Join-Path (Split-Path -Parent $PSScriptRoot) 'Tests\unit\_data\RequestVertrag.json')
)

Set-StrictMode -Version 3.0
$ErrorActionPreference = 'Stop'

$repo = Split-Path -Parent $PSScriptRoot
. (Join-Path $repo 'Tests\_helpers\Get-RequestSnapshot.ps1')

$snapshot = Get-RequestSnapshot -Manifest (Join-Path $repo 'PowerArubaSW\PowerArubaSW.psd1')
$null = New-Item -ItemType Directory -Path (Split-Path -Parent $Ziel) -Force
$json = $snapshot | ConvertTo-Json -Depth 12
[System.IO.File]::WriteAllText($Ziel, ($json -replace "`r`n", "`n") + "`n", [System.Text.UTF8Encoding]::new($false))
Write-Verbose "Eintraege: $(@($snapshot).Count) -> $Ziel"
"{0} Eintraege nach {1}" -f @($snapshot).Count, $Ziel
