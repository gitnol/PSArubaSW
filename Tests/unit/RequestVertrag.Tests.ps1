#
# Copyright 2026, PowerArubaSW contributors
# SPDX-License-Identifier: Apache-2.0
#
# Request-Vertrag (Inkrement I34): Jedes exportierte Cmdlet wird je Parametersatz und Profil (pflicht, voll, aus) mit gemocktem Transport aufgerufen;
# Methode, URI und Body der entstehenden Anfragen muessen mit dem Schnappschuss Tests/unit/_data/RequestVertrag.json uebereinstimmen.
# Anlass: Rund 20 der 36 Public-Dateien hatten keine eigene Testdatei (Banner, DNS, LACP, LLDP, Led, Poe, Port, RADIUS*, STP, Trunk ...); die
# Mutationsstichprobe zeigte, dass genau dort Luecken liegen. Der Schnappschuss haelt das Ist-Verhalten fest (Regressionsnetz, kein Orakel):
# Die URIs stimmen mit der Spec ueberein (Tools/Report-EndpointCoverage.py, Drift 0). Aenderung bewusst: Tools/New-RequestVertrag.ps1, Diff lesen.

BeforeDiscovery {
    $repo = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath))
    $daten = Get-Content -LiteralPath (Join-Path $repo 'Tests\unit\_data\RequestVertrag.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    $script:Faelle = @($daten | ForEach-Object {
        @{ Schluessel = "$($_.name)|$($_.satz)|$($_.profil)"; Name = $_.name; Satz = $_.satz; Profil = $_.profil; Erwartet = ($_ | ConvertTo-Json -Depth 12 -Compress) }
    })
}

BeforeAll {
    $script:UnitDir  = Split-Path -Parent $PSCommandPath
    $script:RepoRoot = Split-Path -Parent (Split-Path -Parent $UnitDir)
    $script:Manifest = Join-Path $RepoRoot 'PowerArubaSW\PowerArubaSW.psd1'
    . (Join-Path $RepoRoot 'Tests\_helpers\Get-RequestSnapshot.ps1')

    $loaded = Get-Module -Name 'PowerArubaSW' -ErrorAction SilentlyContinue
    if ($loaded) { Remove-Module $loaded -Force }
    Import-Module $Manifest -Force

    # Ein Lauf ueber alle Cmdlets (eigener Runspace), danach nur noch Vergleiche. Durch JSON geschickt, damit Typen wie in der Datei aussehen.
    $live = Get-RequestSnapshot -Manifest $Manifest | ConvertTo-Json -Depth 12 | ConvertFrom-Json
    $script:Live = @{}
    foreach ($e in @($live)) { $script:Live["$($e.name)|$($e.satz)|$($e.profil)"] = ($e | ConvertTo-Json -Depth 12 -Compress) }
}

Describe 'Request-Vertrag: Methode, URI und Body je Cmdlet (I34)' -Tag 'Unit' {

    It 'deckt jede exportierte Funktion ab (Schnappschuss oder ausdrueckliche Ausnahme)' {
        $export = @((Get-Module PowerArubaSW).ExportedFunctions.Keys)
        $imVertrag = @($script:Live.Keys | ForEach-Object { ($_ -split '\|')[0] } | Select-Object -Unique)
        $fehlt = @($export | Where-Object { $_ -notin $imVertrag -and $_ -notin $script:RequestVertragAusnahmen })
        $fehlt | Should -BeNullOrEmpty -Because "neue Funktionen brauchen einen Schnappschuss (Tools/New-RequestVertrag.ps1) oder eine begruendete Ausnahme: $($fehlt -join ', ')"
    }

    It 'enthaelt keine Eintraege fuer Funktionen, die es nicht mehr gibt' {
        $namen = @($script:Faelle | ForEach-Object { $_.Name } | Select-Object -Unique)
        $export = @((Get-Module PowerArubaSW).ExportedFunctions.Keys)
        @($namen | Where-Object { $_ -notin $export }) | Should -BeNullOrEmpty
    }

    It '<Schluessel>' -ForEach $script:Faelle {
        $script:Live.ContainsKey($Schluessel) | Should -BeTrue -Because 'der Satz/das Profil kommt im Code nicht mehr vor'
        $script:Live[$Schluessel] | Should -BeExactly $Erwartet
    }
}
