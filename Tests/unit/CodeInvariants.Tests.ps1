#
# Copyright 2026, PowerArubaSW contributors
# SPDX-License-Identifier: Apache-2.0
#
# Waechter fuer Code-Invarianten (Inkrement I22).
# Hardware-frei, laeuft mit Tag 'Unit'.
#
#   1. .gitignore verschluckt keine Projektdateien           (L11)
#   2. jede Funktion hat [CmdletBinding()]                   (L13: sonst landen unbekannte
#                                                            Parameter still in $args, und
#                                                            -Verbose/-ErrorAction fehlen)
#   3. HTTP nur ueber Invoke-ArubaSWWebRequest               (CONVENTIONS 3, Schichtregel)
#   4. kein Write-Host im Modul                              (CONVENTIONS 2)
#   5. Manifest filtert jede Exportart ausdruecklich
#   6. Strict Mode im Modul, Standardverbindung nur ueber    (I23, CONVENTIONS 2: unter Strict Mode ist
#      Get-ArubaSWDefaultConnection                          das Lesen einer fehlenden Variable ein Fehler)
#   7. Mindestversion 5.1 und Editionen im Manifest          (I23, L38)
#   8. Should -Throw nie ohne Fehlerart                      (I31)
#   9. keine Variable lesen, die in der Funktion nie gesetzt wird (I34, L45: `$port` als ShouldProcess-Ziel in Set-ArubaSWSystem)

BeforeDiscovery {
    $repo = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSCommandPath))
    $script:DateiFaelle = @(
        Get-ChildItem -Path (Join-Path $repo 'PowerArubaSW\Public'), (Join-Path $repo 'PowerArubaSW\Private') -Filter '*.ps1' |
            ForEach-Object { @{ Datei = $_.Name } }
    )
}

BeforeAll {
    $script:UnitDir    = Split-Path -Parent $PSCommandPath
    $script:RepoRoot   = Split-Path -Parent (Split-Path -Parent $UnitDir)
    $script:ModuleRoot = Join-Path $RepoRoot 'PowerArubaSW'

    $script:ModuleFiles = @(
        Get-ChildItem -Path (Join-Path $ModuleRoot 'Public'), (Join-Path $ModuleRoot 'Private') -Filter '*.ps1'
    )

    function Get-FileAst {
        param([Parameter(Mandatory)][string]$Path)
        $tokens = $null; $errors = $null
        [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$errors)
    }

    $script:Asts = @{}
    foreach ($f in $ModuleFiles) { $script:Asts[$f.Name] = Get-FileAst -Path $f.FullName }
}

Describe 'Repo-Hygiene: .gitignore verschluckt keine Projektdateien (L11)' -Tag 'Unit' {

    It 'keine Datei unter PowerArubaSW/, Tests/, Tools/ ist ignoriert (ausser bewusst lokale Dateien)' -Skip:(-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Push-Location -LiteralPath $RepoRoot
        try {
            $inRepo = & git rev-parse --is-inside-work-tree 2>$null
            if ($inRepo -ne 'true') { Set-ItResult -Skipped -Because 'kein Git-Worktree'; return }
            # Bewusst ignoriert: lokale Zugangsdaten und Testergebnisse; Tests/schema/openapi.yaml (lokal erzeugt).
            $erlaubt = @('Tests/credential.ps1', 'Tests/coverage.xml', 'Tests/test-results.xml')
            $ignored = @(
                & git ls-files --others --ignored --exclude-standard -- PowerArubaSW/ Tests/ Tools/ ':(exclude)Tests/schema/openapi.yaml' |
                    Where-Object { $_ -notin $erlaubt }
            )
        } finally {
            Pop-Location
        }
        $ignored | Should -BeNullOrEmpty -Because "diese Dateien wuerden nie committet: $($ignored -join ', ')"
    }
}

Describe 'Funktionen tragen [CmdletBinding()] (L13)' -Tag 'Unit' {

    It '<Datei> : jede Funktion hat [CmdletBinding()]' -ForEach $script:DateiFaelle {
        $ast = $script:Asts[$Datei]
        $funktionen = $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)
        $ohne = @(
            foreach ($fn in $funktionen) {
                $pb = $fn.Body.ParamBlock
                if (-not $pb -or $pb.Attributes.TypeName.Name -notcontains 'CmdletBinding') { $fn.Name }
            }
        )
        $ohne | Should -BeNullOrEmpty -Because "ohne [CmdletBinding()] schluckt die Funktion unbekannte Parameter still: $($ohne -join ', ')"
    }
}

Describe 'Schichtregel: HTTP nur ueber den Transport-Wrapper' -Tag 'Unit' {

    It 'Invoke-WebRequest/Invoke-RestMethod nur in Webrequest.ps1 und Connection.ps1' {
        $erlaubt = 'Webrequest.ps1', 'Connection.ps1'
        $treffer = @(
            foreach ($f in $ModuleFiles) {
                $cmds = $Asts[$f.Name].FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] }, $true)
                foreach ($c in $cmds) {
                    if ($c.GetCommandName() -in 'Invoke-WebRequest', 'Invoke-RestMethod' -and $f.Name -notin $erlaubt) {
                        "$($f.Name):$($c.Extent.StartLineNumber)"
                    }
                }
            }
        )
        $treffer | Should -BeNullOrEmpty -Because "Resource-Cmdlets rufen ausschliesslich Invoke-ArubaSWWebRequest: $($treffer -join ', ')"
    }
}

Describe 'Ausgabe: kein Write-Host im Modul' -Tag 'Unit' {

    It 'Write-Host kommt in Public/ und Private/ nicht vor' {
        $treffer = @(
            foreach ($f in $ModuleFiles) {
                $cmds = $Asts[$f.Name].FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] }, $true)
                foreach ($c in $cmds) {
                    if ($c.GetCommandName() -eq 'Write-Host') { "$($f.Name):$($c.Extent.StartLineNumber)" }
                }
            }
        )
        $treffer | Should -BeNullOrEmpty -Because "Diagnose gehoert in Write-Verbose/Write-Warning: $($treffer -join ', ')"
    }
}

Describe 'Manifest filtert jede Exportart ausdruecklich' -Tag 'Unit' {

    It '<Schluessel> ist gesetzt und enthaelt keinen Platzhalter' -ForEach @(
        @{ Schluessel = 'FunctionsToExport' }
        @{ Schluessel = 'CmdletsToExport' }
        @{ Schluessel = 'VariablesToExport' }
        @{ Schluessel = 'AliasesToExport' }
    ) {
        $daten = Import-PowerShellDataFile -Path (Join-Path $ModuleRoot 'PowerArubaSW.psd1')
        $daten.ContainsKey($Schluessel) | Should -BeTrue -Because "ohne $Schluessel filtert das Manifest nicht"
        @($daten[$Schluessel]) -contains '*' | Should -BeFalse -Because "$Schluessel enthaelt '*'"
    }

    It 'das Modul exportiert keine Variablen, Aliase und Cmdlets' {
        $m = Import-Module -Name (Join-Path $ModuleRoot 'PowerArubaSW.psd1') -Force -PassThru
        $m.ExportedVariables.Count | Should -Be 0
        $m.ExportedAliases.Count   | Should -Be 0
        $m.ExportedCmdlets.Count   | Should -Be 0
    }
}

Describe 'Strict Mode und Standardverbindung (I23)' -Tag 'Unit' {

    It 'PowerArubaSW.psm1 setzt Set-StrictMode mit fester Version' {
        $text = Get-Content -LiteralPath (Join-Path $ModuleRoot 'PowerArubaSW.psm1') -Raw
        $text | Should -Match '(?m)^\s*Set-StrictMode\s+-Version\s+[0-9]'
    }

    It '<Datei> : liest $DefaultArubaSWConnection nicht direkt (Ausnahme Connection.ps1)' -ForEach $script:DateiFaelle {
        if ($Datei -eq 'Connection.ps1') { Set-ItResult -Skipped -Because 'setzt und entfernt die Variable'; return }
        $vars = $Asts[$Datei].FindAll({ param($n) $n -is [System.Management.Automation.Language.VariableExpressionAst] -and $n.VariablePath.UserPath -eq 'DefaultArubaSWConnection' }, $true)
        @($vars).Count | Should -Be 0 -Because 'unter Strict Mode ist das Lesen einer fehlenden Variable ein Fehler; Get-ArubaSWDefaultConnection verwenden'
    }
}

Describe 'Manifest: Mindestversion und Editionen (I23, L38)' -Tag 'Unit' {

    It 'PowerShellVersion ist mindestens 5.1 und CompatiblePSEditions nennt Desktop und Core' {
        $daten = Import-PowerShellDataFile -Path (Join-Path $ModuleRoot 'PowerArubaSW.psd1')
        [version]$daten.PowerShellVersion | Should -BeGreaterOrEqual ([version]'5.1')
        @($daten.CompatiblePSEditions) | Should -Contain 'Desktop'
        @($daten.CompatiblePSEditions) | Should -Contain 'Core'
    }
}

BeforeDiscovery {
    $script:TestDateiFaelle = @(
        Get-ChildItem -Path (Split-Path -Parent $PSCommandPath) -Filter '*.Tests.ps1' |
            ForEach-Object { @{ Test = $_.Name; Pfad = $_.FullName } }
    )
}

Describe 'Should -Throw nennt immer die Fehlerart (I31, UNIT_TESTS 7.11, L43)' -Tag 'Unit' {

    # Ein blosses `Should -Throw` besteht mit JEDEM Fehler, auch mit einem Parameterbindungsfehler oder einem spaeteren Prompt.
    # Erlaubt: -ExpectedMessage, -ErrorId oder -ExceptionType. Geprueft per AST, nicht per Regex (mehrzeilige Aufrufe).
    It '<Test> : kein Should -Throw ohne -ExpectedMessage, -ErrorId oder -ExceptionType' -ForEach $script:TestDateiFaelle {
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($Pfad, [ref]$null, [ref]$null)
        $cmds = $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] -and $n.GetCommandName() -eq 'Should' }, $true)
        $bloss = foreach ($c in $cmds) {
            $namen = @($c.CommandElements | Where-Object { $_ -is [System.Management.Automation.Language.CommandParameterAst] } | ForEach-Object ParameterName)
            # `Should -Not -Throw` ist legitim ("kein Fehler"); gemeint ist nur das positive Throw.
            if ($namen -contains 'Throw' -and $namen -notcontains 'Not' -and -not ($namen | Where-Object { $_ -in 'ExpectedMessage', 'ErrorId', 'ExceptionType' })) {
                "Zeile $($c.Extent.StartLineNumber)"
            }
        }
        @($bloss) | Should -BeNullOrEmpty -Because 'Should -Throw ohne Fehlerart besteht mit jedem Fehler (UNIT_TESTS 7.11)'
    }
}

Describe 'Variablen werden nur gelesen, wenn die Funktion sie irgendwo setzt (I34, L45)' -Tag 'Unit' {

    # Statische Naeherung (AST): Gelesen = unqualifizierte Variable; gesetzt = Parameter, Zuweisung, foreach-Variable, -*Variable-Argument.
    # Faengt Tippfehler und Copy-Paste-Reste (`$port` statt `$id`), die unter Strict Mode zur Laufzeit werfen. Nicht erkannt: Variable nur auf
    # einem Pfad gesetzt (Muster `$oldname`, I31) - dafuer sorgt der Robustheitstest mit dem Profil "pflicht".
    It '<Datei> : keine nie gesetzte Variable' -ForEach $script:DateiFaelle {
        $auto = 'true', 'false', 'null', '_', 'args', 'input', 'this', 'PSCmdlet', 'PSBoundParameters', 'PSItem', 'MyInvocation', 'Matches',
                'Error', 'LASTEXITCODE', 'PSVersionTable', 'PSScriptRoot', 'PSCommandPath', 'ErrorActionPreference', 'WarningPreference',
                'VerbosePreference', 'WhatIfPreference', 'ConfirmPreference', 'ProgressPreference', 'PSCulture', 'Host', 'IsWindows', 'IsLinux', 'IsMacOS',
                'StackTrace', 'ExecutionContext', 'PID', 'HOME', 'PWD', 'ShellId', 'foreach', 'switch', 'PSDefaultParameterValues', 'OutputEncoding'
        $varParams = 'SessionVariable', 'OutVariable', 'ErrorVariable', 'WarningVariable', 'InformationVariable', 'PipelineVariable', 'Variable'
        $funktionen = $Asts[$Datei].FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)
        $befund = foreach ($f in $funktionen) {
            $gesetzt = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
            foreach ($a in $auto) { $null = $gesetzt.Add($a) }
            foreach ($p in @($f.Parameters) + @($f.Body.ParamBlock.Parameters)) { if ($p) { $null = $gesetzt.Add($p.Name.VariablePath.UserPath) } }
            $f.Body.FindAll({ param($n) $n -is [System.Management.Automation.Language.AssignmentStatementAst] }, $true) | ForEach-Object {
                $_.Left.FindAll({ param($v) $v -is [System.Management.Automation.Language.VariableExpressionAst] }, $true) | ForEach-Object { $null = $gesetzt.Add($_.VariablePath.UserPath) }
            }
            $f.Body.FindAll({ param($n) $n -is [System.Management.Automation.Language.ForEachStatementAst] }, $true) | ForEach-Object { $null = $gesetzt.Add($_.Variable.VariablePath.UserPath) }
            $f.Body.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] }, $true) | ForEach-Object {
                $el = @($_.CommandElements)
                for ($i = 0; $i -lt $el.Count - 1; $i++) {
                    if ($el[$i] -is [System.Management.Automation.Language.CommandParameterAst] -and $el[$i].ParameterName -in $varParams -and $el[$i + 1] -is [System.Management.Automation.Language.StringConstantExpressionAst]) {
                        $null = $gesetzt.Add($el[$i + 1].Value)
                    }
                }
            }
            $f.Body.FindAll({ param($n) $n -is [System.Management.Automation.Language.VariableExpressionAst] }, $true) | ForEach-Object {
                $vp = $_.VariablePath
                if ($vp.IsDriveQualified -or $vp.IsGlobal -or $vp.IsScript -or $vp.IsPrivate -or $vp.IsLocal -and $vp.UserPath -like '*:*') { return }
                if (-not $gesetzt.Contains($vp.UserPath)) { "$($f.Name): `$$($vp.UserPath) (Zeile $($_.Extent.StartLineNumber))" }
            }
        }
        @($befund | Select-Object -Unique) | Should -BeNullOrEmpty -Because 'eine nie gesetzte Variable wirft unter Strict Mode (L45)'
    }
}
