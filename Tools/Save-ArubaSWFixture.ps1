#
# Copyright 2026, PowerArubaSW contributors
# SPDX-License-Identifier: Apache-2.0
#
# Recording-Helper fuer Recorded Fixtures (Inkrement I10).
# WIRD GEGEN EINEN ECHTEN SWITCH AUSGEFUEHRT — speichert die rohe API-Antwort
# als Fixture-Datei. Direkt danach .\Anonymize-Fixture.ps1 ueber die erzeugte
# Datei laufen lassen, BEVOR sie ins Repo committet wird.
#
# Voraussetzung: Connect-ArubaSW wurde bereits in der Session aufgerufen, oder
# eine Connection wird per -Connection uebergeben.
#
# Verwendung:
#   Connect-ArubaSW -Server 192.0.2.1 -SkipCertificateCheck
#   .\Tools\Save-ArubaSWFixture.ps1 -Resource vlans -Name get-default `
#     -Method GET -Uri vlans
#
#   .\Tools\Save-ArubaSWFixture.ps1 -Resource vlans -Name post-add `
#     -Method POST -Uri vlans -Body @{ vlan_id = 85; name = 'TestFixture' }
#
#   .\Tools\Anonymize-Fixture.ps1 -Path Tests\fixtures\v8\vlans\get-default.json

[CmdletBinding()]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '',
    Justification = 'Tool-Skript: Write-Host ist hier korrekte UI-Ausgabe an den interaktiven Benutzer, kein Diagnose-Log.')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', '',
    Justification = 'Zugriff auf die globale Variable DefaultArubaSWConnection ist Teil der dokumentierten PowerArubaSW-API (Connect-ArubaSW legt sie an, Disconnect-ArubaSW raeumt sie weg).')]
param(
    [Parameter(Mandatory)][string]$Name,
    [Parameter(Mandatory)][string]$Resource,
    [Parameter(Mandatory)][ValidateSet('GET','POST','PUT','DELETE')][string]$Method,
    [Parameter(Mandatory)][string]$Uri,

    [int]$ApiVersion = 8,
    [object]$Body = $null,
    [psobject]$Connection = $null,

    [string]$FixturesRoot = $null,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

# Modul laden, falls noch nicht
if (-not (Get-Module -Name PowerArubaSW)) {
    $repoRoot = Split-Path -Parent $PSScriptRoot
    $manifest = [System.IO.Path]::Combine($repoRoot, 'PowerArubaSW', 'PowerArubaSW.psd1')
    Import-Module $manifest -Force
}

# Connection auswaehlen
if (-not $Connection) {
    if (Test-Path variable:global:DefaultArubaSWConnection) {
        $Connection = $global:DefaultArubaSWConnection
    } else {
        throw 'Keine Verbindung. Vorher Connect-ArubaSW aufrufen oder -Connection uebergeben.'
    }
}

# Fixtures-Wurzel
$repoRoot = Split-Path -Parent $PSScriptRoot
if (-not $FixturesRoot) {
    $FixturesRoot = [System.IO.Path]::Combine($repoRoot, 'Tests', 'fixtures')
}

$dir  = [System.IO.Path]::Combine($FixturesRoot, "v$ApiVersion", $Resource)
$path = [System.IO.Path]::Combine($dir, "$Name.json")

if ((Test-Path -LiteralPath $path) -and -not $Force) {
    throw "Fixture existiert bereits: $path  —  mit -Force ueberschreiben."
}

if (-not (Test-Path -LiteralPath $dir)) {
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
}

# Echter Call gegen den Switch
$statusCode = $null
$contentStr = $null
try {
    if ($Body) {
        $response = Invoke-ArubaSWWebRequest -method $Method -uri $Uri -body $Body -connection $Connection -api_version $ApiVersion
    } else {
        $response = Invoke-ArubaSWWebRequest -method $Method -uri $Uri -connection $Connection -api_version $ApiVersion
    }
    $statusCode = $response.StatusCode
    $contentStr = [string]$response.Content
} catch {
    Write-Warning "Aufruf gegen Switch lieferte einen Fehler — Fixture wird trotzdem erzeugt (Status/Content evtl. leer): $_"
}

$fixture = [ordered]@{
    meta = [ordered]@{
        uri          = $Uri
        method       = $Method.ToUpperInvariant()
        api_version  = $ApiVersion
        status_code  = $statusCode
        recorded_at  = (Get-Date -Format 'yyyy-MM-dd')
        firmware     = 'TODO — manuell eintragen oder via Anonymize ersetzen'
        switch_model = 'TODO — manuell eintragen oder via Anonymize ersetzen'
        anonymized   = $false
        note         = "Recorded by Save-ArubaSWFixture.ps1. RUN Anonymize-Fixture.ps1 BEFORE COMMIT."
    }
    content = $contentStr
}

$fixture | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $path -Encoding UTF8

Write-Host "Fixture gespeichert: $path"
Write-Warning "WICHTIG: Vor dem Commit anonymisieren:"
Write-Warning "  .\Tools\Anonymize-Fixture.ps1 -Path '$path'"
Write-Warning "Manuell pruefen: Seriennummern, MAC-Adressen, Hostnames, RADIUS-Secrets, SNMP-Communities."
