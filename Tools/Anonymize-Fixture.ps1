#
# Copyright 2026, PowerArubaSW contributors
# SPDX-License-Identifier: Apache-2.0
#
# Anonymisierungs-Skript fuer Recorded Fixtures (Inkrement I10).
# Default-Scrubs: IPv4 (-> TEST-NET-2 RFC 5737), MAC-Adressen (colon/dash/dot)
# -> IANA-Reserved (00:00:5E:00:53:00).
#
# Weitere projekt-spezifische Werte (RADIUS-Secrets, Seriennummern, Hostnames,
# SNMP-Communities, ...) ueber -AdditionalReplacements als Hashtable
# Pattern -> Ersatz uebergeben.
#
# Verwendung:
#   .\Tools\Anonymize-Fixture.ps1 -Path Tests\fixtures\v8\vlans\get-default.json
#
#   .\Tools\Anonymize-Fixture.ps1 -Path Tests\fixtures\v8\radius-server\get-default.json `
#     -AdditionalReplacements @{
#       '"shared_secret"\s*:\s*"[^"]+"' = '"shared_secret":"ANONYMIZED-SHARED-SECRET"'
#       'lab-switch-01\.corp\.example\.com' = 'test-switch.example.com'
#     }
#
# Modifiziert die Datei IN PLACE. Stellt am Ende `meta.anonymized = true` und
# erinnert an manuelle Pruefung.

[CmdletBinding(SupportsShouldProcess)]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '',
    Justification = 'Tool-Skript: Write-Host ist hier korrekte UI-Ausgabe an den interaktiven Benutzer, kein Diagnose-Log.')]
param(
    [Parameter(Mandatory)][string]$Path,
    [hashtable]$AdditionalReplacements = @{}
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $Path)) {
    throw "Fixture nicht gefunden: $Path"
}

$raw = Get-Content -LiteralPath $Path -Raw

# Default-Patterns (paranoid, aber sicher fuer alles ausser absichtlichen Test-Daten)
$defaults = [ordered]@{
    # IPv4 (alle Vorkommen) -> 198.51.100.1 (TEST-NET-2, RFC 5737)
    '\b(?:\d{1,3}\.){3}\d{1,3}\b' = '198.51.100.1'

    # MAC colon-/dash-separiert -> 00:00:5E:00:53:00 (IANA documentation range)
    '(?i)\b([0-9a-f]{2}[:\-]){5}[0-9a-f]{2}\b' = '00:00:5E:00:53:00'

    # MAC Cisco/Aruba-Stil (4-4-4 Hex mit Punkten) -> 0000.5E00.5300
    '(?i)\b[0-9a-f]{4}\.[0-9a-f]{4}\.[0-9a-f]{4}\b' = '0000.5E00.5300'
}

$result = $raw
foreach ($pattern in $defaults.Keys) {
    $result = [regex]::Replace($result, $pattern, [string]$defaults[$pattern])
}
foreach ($pattern in $AdditionalReplacements.Keys) {
    $result = [regex]::Replace($result, $pattern, [string]$AdditionalReplacements[$pattern])
}

# meta.anonymized = true setzen (Roundtrip ueber ConvertFrom-Json / ConvertTo-Json)
try {
    $obj = $result | ConvertFrom-Json
    if ($obj.PSObject.Properties.Name -contains 'meta') {
        if ($obj.meta.PSObject.Properties.Name -contains 'anonymized') {
            $obj.meta.anonymized = $true
        } else {
            $obj.meta | Add-Member -NotePropertyName 'anonymized' -NotePropertyValue $true -Force
        }
    } else {
        Write-Warning "Datei hat kein meta-Objekt — meta.anonymized wird NICHT gesetzt."
    }
    $result = $obj | ConvertTo-Json -Depth 20
} catch {
    Write-Warning "JSON-Roundtrip fehlgeschlagen ($_); meta.anonymized wurde NICHT gesetzt. Ersetzungen wurden trotzdem appliziert."
}

if ($PSCmdlet.ShouldProcess($Path, 'In-place anonymize')) {
    Set-Content -LiteralPath $Path -Value $result -Encoding UTF8
    Write-Host "Anonymisiert: $Path"
    Write-Warning "Manuell pruefen — die Default-Patterns decken NICHT ab:"
    Write-Warning "  - Seriennummern (Format projekt-spezifisch)"
    Write-Warning "  - RADIUS Shared Secrets (Feldnamen variieren)"
    Write-Warning "  - SNMP Communities"
    Write-Warning "  - Custom-Hostnames / Domain-Namen"
    Write-Warning "  - URLs / E-Mail-Adressen in 'location'/'contact'-Feldern"
    Write-Warning "Gefundene Treffer ggf. ueber -AdditionalReplacements im naechsten Lauf scrubben."
}
