#
# Copyright 2026, PowerArubaSW contributors
# SPDX-License-Identifier: Apache-2.0
#
# Tests fuer den Cross-Family-Dependency-Helper (Inkrement I13).
# Reine Pure-Function-Tests, ohne Hardware/Connection -- laeuft mit Tag 'Unit'
# in CI (siehe .github/workflows/tests.yml).
#
# Schuetzt die zwei Kern-Verhalten:
#   1. Skip-Kaskade: Test-ArubaSWPrereq folgt der deklarierten DependsOn-Liste.
#   2. Reverse-Cleanup: Get-ArubaSWCleanupOrder liefert Children vor Parents.

[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSUseDeclaredVarsMoreThanAssignments', '',
    Justification = 'Pester Discovery-Phase: vars sind in It-Bloecken referenziert.')]
Param()

BeforeAll {
    $script:UnitDir   = Split-Path -Parent $PSCommandPath
    $script:TestsRoot = Split-Path -Parent $UnitDir
    $script:Helper    = Join-Path $TestsRoot 'integration/_helpers/Use-DependencyOrder.ps1'
    . $script:Helper
}

Describe 'Test-ArubaSWPrereq (Skip-Kaskade)' -Tag 'Unit' {

    BeforeEach {
        Reset-ArubaSWFamilyStatus
    }

    It 'gibt $true zurueck, wenn die Familie keine Deklaration hat' {
        # 'NoDepsFamily' steht nicht im ArubaSWFamilyDeps-Hashtable
        Test-ArubaSWPrereq -Family 'NoDepsFamily' | Should -BeTrue
    }

    It 'gibt $true zurueck, wenn alle deklarierten Prereqs Pass sind' {
        Register-ArubaSWFamilyResult -Family 'Vlans' -Status 'Pass'
        Register-ArubaSWFamilyResult -Family 'Port'  -Status 'Pass'
        Test-ArubaSWPrereq -Family 'Vlans-Ports' | Should -BeTrue
    }

    It 'gibt $false zurueck, wenn ein Prereq Fail ist' {
        Register-ArubaSWFamilyResult -Family 'Vlans' -Status 'Fail'
        Register-ArubaSWFamilyResult -Family 'Port'  -Status 'Pass'
        Test-ArubaSWPrereq -Family 'Vlans-Ports' | Should -BeFalse
    }

    It 'gibt $false zurueck, wenn ein Prereq Skip ist (Kaskade)' {
        Register-ArubaSWFamilyResult -Family 'RADIUSServer' -Status 'Skip'
        Test-ArubaSWPrereq -Family 'RADIUSServerGroup' | Should -BeFalse
    }

    It 'behandelt unbekannte (= nicht registrierte) Prereqs als OK' {
        # Konservativ: Skip-Kaskade greift nur, wenn EXPLIZIT Fail/Skip registriert.
        Test-ArubaSWPrereq -Family 'Vlans-Ports' | Should -BeTrue
    }
}

Describe 'Get-ArubaSWCleanupOrder (Reverse-Cleanup)' -Tag 'Unit' {

    It 'liefert Children vor Parents (Vlans-Ports vor Vlans)' {
        $order = Get-ArubaSWCleanupOrder -Families 'Vlans', 'Port', 'Vlans-Ports'
        # Vlans-Ports MUSS vor Vlans und vor Port stehen.
        $idxChild  = [Array]::IndexOf($order, 'Vlans-Ports')
        $idxVlans  = [Array]::IndexOf($order, 'Vlans')
        $idxPort   = [Array]::IndexOf($order, 'Port')
        $idxChild  | Should -BeLessThan $idxVlans
        $idxChild  | Should -BeLessThan $idxPort
    }

    It 'sortiert RADIUS-Kette: Profile -> ServerGroup -> Server' {
        $order = Get-ArubaSWCleanupOrder -Families 'RADIUSServer', 'RADIUSServerGroup', 'RADIUSProfile'
        $idxProfile = [Array]::IndexOf($order, 'RADIUSProfile')
        $idxGroup   = [Array]::IndexOf($order, 'RADIUSServerGroup')
        $idxServer  = [Array]::IndexOf($order, 'RADIUSServer')
        $idxProfile | Should -BeLessThan $idxGroup
        $idxGroup   | Should -BeLessThan $idxServer
    }

    It 'ignoriert Deklarationen ausserhalb der Input-Liste' {
        # Nur 'Vlans-Ports' uebergeben -- 'Vlans' und 'Port' sind nicht in der Liste,
        # also irrelevant, und 'Vlans-Ports' ist der einzige Output.
        $order = Get-ArubaSWCleanupOrder -Families 'Vlans-Ports'
        ($order -is [Array]) | Should -BeTrue
        $order.Count | Should -Be 1
        $order[0] | Should -Be 'Vlans-Ports'
    }

    It 'akzeptiert Familien ohne deklarierte Deps und sortiert sie alphabetisch' {
        $order = Get-ArubaSWCleanupOrder -Families 'Banner', 'DNS', 'STP'
        $order.Count | Should -Be 3
        # alle haben in_degree = 0, also sortiert nach Sort-Object (alphabetisch)
        $order | Should -Be @('Banner', 'DNS', 'STP')
    }
}
