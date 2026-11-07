#
# Copyright 2026, PowerArubaSW contributors
# SPDX-License-Identifier: Apache-2.0
#
# Loader für Recorded Fixtures (Inkrement I10, „Cassette"-Pattern).
# Liefert ein Response-aehnliches PSObject, das Pesters Mock-Replacement fuer
# Invoke-ArubaSWWebRequest direkt zurueckgeben kann.
#
# Verwendung in einem Test:
#
#   . "$PSScriptRoot\_helpers\Get-Fixture.ps1"
#   Mock -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest {
#       Get-Fixture -Resource vlans -Name get-default
#   }
#
# Layout der Fixtures:
#   Tests/fixtures/v<api>/<resource>/<scenario>.json
#
# Jede Fixture-Datei hat die Struktur:
#   {
#     "meta":    { uri, method, api_version, status_code, recorded_at,
#                  firmware, switch_model, anonymized },
#     "content": "<die JSON-Antwort des Switches als String>"
#   }
#
# Die Rueckgabe traegt zusaetzlich `_meta` mit, damit Tests Assertions ueber die
# Fixture selbst stellen koennen (z.B. "wurde die richtige Fixture geladen?").

function Get-Fixture {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$Resource,

        [int]$ApiVersion = 8
    )

    # $PSScriptRoot zeigt auf den _helpers-Ordner; Fixtures liegen zwei Ebenen drueber.
    # [System.IO.Path]::Combine akzeptiert mehrere Segmente in einem Aufruf —
    # vermeidet Join-Path-positionsweise und ist PS5.1+PS7 portabel.
    $testsRoot    = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    $fixturesRoot = Join-Path -Path $testsRoot -ChildPath 'fixtures'
    $path = [System.IO.Path]::Combine($fixturesRoot, "v$ApiVersion", $Resource, "$Name.json")

    if (-not (Test-Path -LiteralPath $path)) {
        throw "Fixture '$Name' für Ressource '$Resource' (v$ApiVersion) nicht gefunden unter: $path"
    }

    $fixture = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json

    [PSCustomObject]@{
        StatusCode = $fixture.meta.status_code
        Content    = $fixture.content
        _meta      = $fixture.meta
    }
}
