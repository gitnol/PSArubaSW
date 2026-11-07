#
# Copyright 2026, PowerArubaSW contributors
# SPDX-License-Identifier: Apache-2.0
#
# Cross-family dependency helper for ArubaSW integration tests
# (Inkrement I13).
#
# Two problems this solves:
#
#  1. *Skip-Kaskade.* If `Vlans` tests fail against the live switch, running
#     `Vlans-Ports` tests right after just produces redundant red -- the
#     prerequisite is missing. Each Describe gates itself via Test-ArubaSWPrereq
#     and skips when an upstream family already failed.
#
#  2. *Reverse-Cleanup.* When a coordinated harness cleans up across multiple
#     families in one AfterAll (rare today but useful for nightly runs), the
#     order matters: children (Vlans-Ports) must be removed before their
#     parents (Vlans). Get-ArubaSWCleanupOrder gives the topological order.
#
# OPT-IN. Existing tests keep working unchanged; tests adopt this incrementally
# by dot-sourcing this file and calling the helpers.
#
# Usage skeleton:
#
#   . "$PSScriptRoot\_helpers\Use-DependencyOrder.ps1"
#
#   Describe "Vlans-Ports" -Tag 'Integration' -Skip:(-not (Test-ArubaSWPrereq 'Vlans-Ports')) {
#       AfterAll {
#           # ... real cleanup ...
#           Register-ArubaSWFamilyResult -Family 'Vlans-Ports' `
#               -Status ($(if ($error.Count -eq 0) {'Pass'} else {'Fail'}))
#       }
#       It "..." {}
#   }
#
# The dependency-graph itself stays *here*; the helper
# is the runtime contract.

# ---------------------------------------------------------------------------
# Dependency declarations
# ---------------------------------------------------------------------------
# Each entry: '<family>' = @('parent-family-1', 'parent-family-2', ...)
# Family names match Tests/Integration/<Family>.Tests.ps1 file stem.
$script:ArubaSWFamilyDeps = @{
    # Hierarchical resource dependencies (auto-derivable; mirrored from
    # REST_API_DEPENDENCIES.md section 1 / 2 -- kept in code for runtime use)
    'Vlans-Ports'       = @('Vlans', 'Port')
    'Trunk'             = @('Port')
    'LACP'              = @('Port')

    # Functional preconditions (manual section 3 of REST_API_DEPENDENCIES.md)
    'RADIUSServerGroup' = @('RADIUSServer')
    'RADIUSProfile'     = @('RADIUSServerGroup')

    # Note: Mode-flag chains (section 3.6 -- STP, LLDP, IGMP, Dot1x globals
    # before per-port endpoints) are NOT listed here on purpose. They're
    # advisory rather than strict; a failing global-mode test signals noise
    # in per-port tests but does not invalidate them. Add here if a future
    # integration-test failure shows the advisory turning into a hard prereq.
}

# Per-family status registry (Pass / Fail / Skip). Mutated by
# Register-ArubaSWFamilyResult; read by Test-ArubaSWPrereq.
$script:ArubaSWFamilyStatus = @{}


function Register-ArubaSWFamilyResult {
<#
.SYNOPSIS
Records the outcome of an integration-test family's run.

.DESCRIPTION
Call this from a Describe's `AfterAll` once cleanup is complete. The
status feeds the Skip-Kaskade for downstream families (Test-ArubaSWPrereq).

.PARAMETER Family
Family name (matches the *.Tests.ps1 file stem).

.PARAMETER Status
'Pass' if the Describe ran without failures; 'Fail' if any It failed
or threw; 'Skip' if the Describe was skipped (e.g. by an upstream
Test-ArubaSWPrereq returning false).

.EXAMPLE
Register-ArubaSWFamilyResult -Family 'Vlans' -Status 'Pass'
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $Family,
        [Parameter(Mandatory)] [ValidateSet('Pass', 'Fail', 'Skip')] [string] $Status
    )
    $script:ArubaSWFamilyStatus[$Family] = $Status
}


function Test-ArubaSWPrereq {
<#
.SYNOPSIS
Returns $true if all declared prerequisites for $Family have passed.

.DESCRIPTION
Use in `Describe ... -Skip:(-not (Test-ArubaSWPrereq 'X'))` so a failed
parent family cascades into a skip rather than redundant red downstream.
Families without declared dependencies always return $true. A prereq that
is neither Pass nor Fail nor Skip (= never registered) is treated as
'unknown', and we conservatively return $true -- Skip-Kaskade activates
only when a prereq is EXPLICITLY registered as Fail/Skip.

.PARAMETER Family
Family name to check prereqs for.

.EXAMPLE
Describe 'Vlans-Ports' -Tag 'Integration' -Skip:(-not (Test-ArubaSWPrereq 'Vlans-Ports')) {
    It "..." {}
}
#>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)] [string] $Family
    )
    $deps = $script:ArubaSWFamilyDeps[$Family]
    if (-not $deps) { return $true }
    foreach ($parent in $deps) {
        $status = $script:ArubaSWFamilyStatus[$parent]
        if ($status -eq 'Fail' -or $status -eq 'Skip') {
            return $false
        }
    }
    return $true
}


function Reset-ArubaSWFamilyStatus {
<#
.SYNOPSIS
Clears the family-status registry (intended for test-of-tests).

.DESCRIPTION
Pesters fuer den Helper selbst koennen mit Reset zwischen Cases einen
sauberen Ausgangszustand erzwingen. Normaler Integration-Lauf braucht
das nicht -- der Zustand wird je Pester-Run einmal aufgebaut.
#>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseShouldProcessForStateChangingFunctions',
        '',
        Justification = 'In-process test-state reset, no external side effects.')]
    param()
    $script:ArubaSWFamilyStatus = @{}
}


function Get-ArubaSWCleanupOrder {
<#
.SYNOPSIS
Returns the given families in cleanup order (children first, parents last).

.DESCRIPTION
Topological sort on the dependency graph: a node can be cleaned when
nothing in the remaining set depends on it any more. Cycles are detected
and the remaining nodes are appended in alphabetical order with a warning.

.PARAMETER Families
The families to sort. Members of $script:ArubaSWFamilyDeps that are not
in this list are ignored -- only intra-list dependencies count.

.EXAMPLE
Get-ArubaSWCleanupOrder -Families 'Vlans','Port','Vlans-Ports'
# Vlans-Ports
# Port
# Vlans

.NOTES
Edge `child -> parent` means "child depends on parent".
in_degree[parent] = number of children pointing in. When in_degree == 0,
nothing depends on the node any more, so it is safe to clean.
#>
    [CmdletBinding()]
    # Leading-comma-Trick (L7) erzeugt object[] -- daher OutputType passend.
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)] [string[]] $Families
    )

    $inDeg = @{}
    foreach ($f in $Families) { $inDeg[$f] = 0 }
    foreach ($f in $Families) {
        $parents = $script:ArubaSWFamilyDeps[$f]
        if (-not $parents) { continue }
        foreach ($p in $parents) {
            if ($inDeg.ContainsKey($p)) { $inDeg[$p]++ }
        }
    }

    $remaining = New-Object 'System.Collections.Generic.HashSet[string]'
    foreach ($f in $Families) { [void] $remaining.Add($f) }

    $order = New-Object 'System.Collections.Generic.List[string]'
    while ($remaining.Count -gt 0) {
        $ready = @($remaining | Where-Object { $inDeg[$_] -eq 0 } | Sort-Object)
        if ($ready.Count -eq 0) {
            Write-Warning ("Get-ArubaSWCleanupOrder: cycle detected; " +
                "remaining families appended alphabetically: " +
                ($remaining -join ', '))
            foreach ($r in ($remaining | Sort-Object)) { $order.Add($r) }
            break
        }
        foreach ($r in $ready) {
            $order.Add($r)
            [void] $remaining.Remove($r)
            $parents = $script:ArubaSWFamilyDeps[$r]
            if ($parents) {
                foreach ($p in $parents) {
                    if ($inDeg.ContainsKey($p)) { $inDeg[$p]-- }
                }
            }
        }
    }
    # Leading-comma "array-of-array" trick verhindert, dass PowerShell ein
    # Single-Element-Array auf den Skalar entpackt (Lesson L7).
    return , $order.ToArray()
}
