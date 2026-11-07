#
# Copyright 2026, PowerArubaSW contributors
# SPDX-License-Identifier: Apache-2.0
#
# Inkrement I11/2 — kontinuierliche Verifikation der I10-Fixtures gegen die
# OpenAPI-Spec (Tests/schema/openapi.yaml, optional, siehe Tests/schema/README.md). Jede aufgenommene oder
# hand-gefertigte Fixture wird gegen das Response-Schema validiert; jede
# Schema-Drift (durch Firmware-Upgrade, manuellen YAML-Edit oder Fehler in
# der Fixture selbst) bricht sofort den CI-Lauf.
#
# Engine: Tools/Validate-Fixture.py (jsonschema-basiert). Python ist im
# CI-Setup ohnehin verfuegbar (Pester-Dev-Maschine + GitHub-Actions ubuntu/
# windows-latest haben Python vorinstalliert). Auf Windows-PS5.1 muss Python
# im PATH sein — der Test wird sonst geskippt.

# Discovery-Zeit-Logik: alle Fixture-Pfade enumerieren, damit Pester pro Datei
# einen It-Block erzeugt.
$script:I11RepoRoot     = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath))
$script:I11FixturesRoot = Join-Path $I11RepoRoot 'Tests/fixtures'
$script:I11OpenApiSpec  = Join-Path $I11RepoRoot 'Tests/schema/openapi.yaml'
$script:I11Validator    = Join-Path $I11RepoRoot 'Tools/Validate-Fixture.py'

$script:I11Cases = @()
if (Test-Path -LiteralPath $I11FixturesRoot) {
    $script:I11Cases = Get-ChildItem -LiteralPath $I11FixturesRoot -Recurse -Filter '*.json' |
        ForEach-Object {
            $rel = $_.FullName.Substring($I11FixturesRoot.Length).TrimStart('\','/')
            @{ Name = $rel; Path = $_.FullName }
        }
}

Describe 'Fixtures vs OpenAPI schema (I11)' -Tag 'Unit' {

    BeforeAll {
        # Python im PATH? Sonst skip — Pester soll nicht haengen.
        $script:I11Python = (Get-Command python -ErrorAction SilentlyContinue)?.Source
        if (-not $I11Python) { $script:I11Python = (Get-Command python3 -ErrorAction SilentlyContinue)?.Source }
    }

    It 'Spec-Datei existiert' {
        if (-not (Test-Path -LiteralPath $I11OpenApiSpec)) { Set-ItResult -Skipped -Because 'Tests/schema/openapi.yaml fehlt (optional, siehe Tests/schema/README.md)'; return }
        Test-Path -LiteralPath $I11OpenApiSpec | Should -BeTrue
    }

    It 'Validator-Tool existiert' {
        Test-Path -LiteralPath $I11Validator | Should -BeTrue
    }

    Context 'Per-Fixture-Validierung' {

        It 'Fixture <Name>' -ForEach $I11Cases {
            if (-not (Test-Path -LiteralPath $I11OpenApiSpec)) {
                Set-ItResult -Skipped -Because 'Tests/schema/openapi.yaml fehlt (optional)'
                return
            }
            if (-not $I11Python) {
                Set-ItResult -Skipped -Because 'python nicht im PATH — Validator nicht ausfuehrbar'
                return
            }
            $output = & $I11Python $I11Validator --spec $I11OpenApiSpec --fixture $Path 2>&1
            $exit = $LASTEXITCODE
            # DeprecationWarning rauswerfen, sonst floodet das die Fehlermeldung
            $clean = ($output | Where-Object { $_ -notmatch 'DeprecationWarning|RefResolver is deprecated|from jsonschema|jsonschema.RefResolver|providing more compliant' }) -join "`n"
            $exit | Should -Be 0 -Because $clean
        }
    }
}
