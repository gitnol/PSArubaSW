#
# Copyright 2026, PowerArubaSW contributors
# SPDX-License-Identifier: Apache-2.0
#
# Zentrale Pester-Konfiguration. Gibt ein PesterConfiguration-Objekt zurück.
#
# Verwendung:
#   $cfg = & .\pester.config.ps1                    # default: Unit-Tests
#   $cfg = & .\pester.config.ps1 -Tag Integration   # Hardware-Tests gegen echten Switch
#   Invoke-Pester -Configuration $cfg
#
# Layout:
#   Tests/PowerArubaSW.Tests.ps1   = Modul-/Manifest-/Export-Surface-Tests (Tag 'Unit')
#   Tests/unit/                    = weitere Unit-Tests mit Mocks (Tag 'Unit', wird in I5 befüllt)
#   Tests/integration/             = Tests gegen echten Switch (Tag 'Integration')

[CmdletBinding()]
param(
    [ValidateSet('Unit', 'Integration', 'All')]
    [string]$Tag = 'Unit',
    [switch]$CodeCoverage
)

$here = Split-Path -Parent $PSCommandPath

$config = New-PesterConfiguration

# Pfade in Abhängigkeit vom gewählten Tag — Path-Filter ist schneller und
# robuster als Tag-Filter, weil das Layout selbst die Trennung kodiert.
switch ($Tag) {
    'Unit' {
        $config.Run.Path = @(
            (Join-Path $here 'PowerArubaSW.Tests.ps1'),
            (Join-Path $here 'unit')
        )
        $config.Filter.Tag = 'Unit'
    }
    'Integration' {
        $config.Run.Path = @( (Join-Path $here 'integration') )
        $config.Filter.Tag = 'Integration'
    }
    'All' {
        $config.Run.Path = @(
            (Join-Path $here 'PowerArubaSW.Tests.ps1'),
            (Join-Path $here 'unit'),
            (Join-Path $here 'integration')
        )
    }
}

$config.Run.PassThru = $true
$config.Output.Verbosity = 'Detailed'

# Code-Coverage wird in I5 (Unit-Tests mit Mocks) sinnvoll. Hier per Schalter.
if ($CodeCoverage) {
    $config.CodeCoverage.Enabled = $true
    $config.CodeCoverage.Path = @(
        (Join-Path (Split-Path $here -Parent) 'PowerArubaSW\Public\*.ps1'),
        (Join-Path (Split-Path $here -Parent) 'PowerArubaSW\Private\*.ps1')
    )
    $config.CodeCoverage.OutputFormat = 'JaCoCo'
    $config.CodeCoverage.OutputPath = (Join-Path $here 'coverage.xml')
}

$config
