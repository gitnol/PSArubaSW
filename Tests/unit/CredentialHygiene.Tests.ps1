#
# Copyright 2026, PowerArubaSW contributors
# SPDX-License-Identifier: Apache-2.0
#
# Repo-Hygiene-Regression (Inkrement I8): stellt sicher, dass die in Inkrement I1
# / BOOTSTRAP.md festgelegten sensiblen Dateien dauerhaft NICHT in git landen.
#
# Anlass: Tests/credential.ps1 enthaelt das administrative Switch-Passwort im
# Klartext. Wuerde es jemand versehentlich committen (z.B. via `git add .`),
# liefe die Switch-Admin-Credential im git-Verlauf - genau der Threat-Model-Punkt
# 4 aus I1. Dieser Test laeuft mit Tag 'Unit' in CI (siehe .github/workflows/tests.yml)
# und kippt sofort den PR.

BeforeAll {
    $script:UnitDir    = Split-Path -Parent $PSCommandPath        # ...\Tests\unit
    $script:TestsRoot  = Split-Path -Parent $UnitDir              # ...\Tests
    $script:RepoRoot   = Split-Path -Parent $TestsRoot            # ...\PowerArubaSW-master
    $script:GitIgnore  = Join-Path $RepoRoot '.gitignore'
}

Describe 'Credential-Datei-Hygiene (I8)' -Tag 'Unit' {

    It '.gitignore enthaelt Tests/credential.ps1' {
        Test-Path -LiteralPath $GitIgnore | Should -BeTrue
        $content = Get-Content -LiteralPath $GitIgnore -Raw
        # Backslash vs. forward-slash beide moeglich; .gitignore-Konvention ist '/'.
        $content | Should -Match 'Tests/credential\.ps1' `
            -Because '.gitignore muss credential.ps1 ausschliessen, sonst landet das Switch-Passwort im Repo'
    }

    It '.gitignore enthaelt die generischen Secret-Muster (*.secret, config.ps1)' {
        $content = Get-Content -LiteralPath $GitIgnore -Raw
        $content | Should -Match '(?m)^\*\.secret\b'
        $content | Should -Match '(?m)^config\.ps1\b'
    }

    It 'Tests/credential.ps1 ist NICHT in git getrackt' -Skip:(-not (Get-Command git -ErrorAction SilentlyContinue)) {
        # `git ls-files` listet nur getrackte Dateien (gitignored != untracked).
        # Wenn credential.ps1 hier auftaucht, wurde es VOR der gitignore-Regel
        # committet und muss per `git rm --cached` aus dem Tracking geholt werden.
        Push-Location -LiteralPath $RepoRoot
        try {
            $tracked = & git ls-files 'Tests/credential.ps1' 2>$null
        } finally {
            Pop-Location
        }
        $tracked | Should -BeNullOrEmpty `
            -Because 'wenn credential.ps1 getrackt waere, stuende das Switch-Admin-Passwort im git-Verlauf'
    }

    It 'keine *.secret- oder config.ps1-Datei im Repo ist getrackt' -Skip:(-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Push-Location -LiteralPath $RepoRoot
        try {
            $tracked = & git ls-files 2>$null
        } finally {
            Pop-Location
        }
        $offenders = $tracked | Where-Object {
            $_ -match '\.secret$' -or
            ($_ -match '(^|/)config\.ps1$')
        }
        $offenders | Should -BeNullOrEmpty `
            -Because 'Dateinamen aus dem .gitignore-Secret-Block duerfen nie getrackt sein'
    }
}
