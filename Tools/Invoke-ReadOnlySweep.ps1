#
# Copyright 2026, PowerArubaSW contributors
# SPDX-License-Identifier: Apache-2.0
#
<#
    .SYNOPSIS
    Liest von einem echten Switch alle parameterlosen Get-Cmdlets des Moduls und sammelt die Antworten als JSON (nur lesend).

    .DESCRIPTION
    Meldet sich per REST an dem Switch an, ruft jedes Get-ArubaSW*-Cmdlet ohne Pflichtparameter genau einmal auf und schreibt je Cmdlet eine
    JSON-Datei, dazu _summary.txt (ok/Fehler/Anzahl) und ein ZIP. Es gibt keinen schreibenden Aufruf: das Skript ruft ausschliesslich Cmdlets
    mit dem Verb Get auf.

    Geheimnisse werden vor dem Speichern geschwaerzt (Felder, deren Name key, secret, password, community, passphrase oder token enthaelt).
    Die Portnamen enthalten oft Personennamen: sie werden standardmaessig durch "port-<id>" ersetzt (-KeepPortNames behaelt sie).
    Mit -AnonymizeAddresses werden IPv4-Adressen durch 192.0.2.x ersetzt (gleiche Adresse -> gleicher Ersatz).

    Das Ergebnis dient dazu, Feldnamen und Antwortformen gegen echte Konfigurationen zu pruefen (Request-Vertrag, Fixtures, Spec).
    Vor dem Weitergeben die Dateien kurz ansehen.

    .EXAMPLE
    .\Invoke-ReadOnlySweep.ps1 -Server 192.0.2.10 -SkipCertificateCheck

    HTTPS mit selbstsigniertem Zertifikat; fragt nach Benutzer und Kennwort, wenn kein gespeicherter Eintrag da ist.
#>
[CmdletBinding()]
Param(
    [Parameter(Mandatory = $true)]
    [string]$Server,
    [string]$OutDir = (Join-Path (Get-Location) ('sweep-' + ($env:COMPUTERNAME) + '-' + (Get-Date -Format 'yyyyMMdd-HHmm'))),
    [string]$ModulePath = (Join-Path (Split-Path -Parent $PSScriptRoot) 'PowerArubaSW'),
    [switch]$SkipCertificateCheck,
    [switch]$HttpOnly,
    [switch]$KeepPortNames,
    [switch]$AnonymizeAddresses
)

$ErrorActionPreference = 'Stop'
if (-not (Test-Path (Join-Path $ModulePath 'PowerArubaSW.psd1'))) {
    # Aufruf aus dem Ordner, in dem Modul und Skript nebeneinander liegen
    $ModulePath = Join-Path $PSScriptRoot 'PowerArubaSW'
}
Import-Module (Join-Path $ModulePath 'PowerArubaSW.psd1') -Force

$secretPattern = '"(?<k>[^"]*(?:key|secret|password|community|passphrase|token)[^"]*)"\s*:\s*"[^"]*"'
$script:ipMap = @{}
function Convert-IpAddress([string]$text) {
    [regex]::Replace($text, '\b(?:\d{1,3}\.){3}\d{1,3}\b', {
        param($m)
        $ip = $m.Value
        if (-not $script:ipMap.ContainsKey($ip)) { $script:ipMap[$ip] = '192.0.2.' + (($script:ipMap.Count % 254) + 1) }
        $script:ipMap[$ip]
    })
}

New-Item -ItemType Directory -Path $OutDir -Force | Out-Null

$connect = @{ Server = $Server }
if ($SkipCertificateCheck) { $connect.SkipCertificateCheck = $true }
if ($HttpOnly) { $connect.httpOnly = $true; $connect.Force = $true }
$null = Connect-ArubaSW @connect

$skip = 'Get-ArubaSWCli', 'Get-ArubaSWCliBatchStatus', 'Get-ArubaSWDefaultConnection'
$commands = Get-Command -Module PowerArubaSW -CommandType Function -Name 'Get-*' | Sort-Object Name | Where-Object { $_.Name -notin $skip }
$summary = foreach ($c in $commands) {
    $mandatory = @($c.Parameters.Values | Where-Object { $_.Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] -and $_.Mandatory } })
    if ($mandatory.Count -gt 0) { '{0,-40} uebersprungen (Pflichtparameter)' -f $c.Name; continue }
    try {
        $data = & $c.Name -ErrorAction Stop -WarningAction SilentlyContinue
        if (-not $KeepPortNames -and $c.Name -eq 'Get-ArubaSWPort') {
            foreach ($p in @($data)) { if ($p.PSObject.Properties['name']) { $p.name = 'port-' + $p.id } }
        }
        $json = ConvertTo-Json -InputObject $data -Depth 12
        $json = [regex]::Replace($json, $secretPattern, '"${k}": "***"')
        if ($AnonymizeAddresses) { $json = Convert-IpAddress $json }
        [System.IO.File]::WriteAllText((Join-Path $OutDir ($c.Name + '.json')), $json, [System.Text.UTF8Encoding]::new($false))
        '{0,-40} ok ({1} Zeichen)' -f $c.Name, $json.Length
    }
    catch {
        $msg = ($_.Exception.Message -replace '\s+', ' ')
        '{0,-40} FEHLER {1}' -f $c.Name, $msg
    }
}
$summary | Set-Content -Path (Join-Path $OutDir '_summary.txt') -Encoding UTF8
Disconnect-ArubaSW -Confirm:$false

$zip = $OutDir + '.zip'
Compress-Archive -Path (Join-Path $OutDir '*') -DestinationPath $zip -Force
$summary
''
"Fertig: $zip"
