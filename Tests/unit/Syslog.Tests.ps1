#
# Copyright 2026, PowerArubaSW contributors
# SPDX-License-Identifier: Apache-2.0
#
# Unit-Tests fuer Public/Syslog.ps1 (Inkrement I27).
# Die Felder von Syslog/SyslogFilter/SyslogEventCriteria sind weder in der OpenAPI-Spec
# noch im 16.04-Referenz-PDF belegt. Darum gibt es hier KEINE Fixtures (eine Fixture waere
# erfundene "Wirklichkeit"); die Tests mocken den Transport mit Inline-Antworten und pruefen
# nur, was die Cmdlets selbst festlegen: Methode, URI, URL-Kodierung, Body-Durchreichung,
# ShouldProcess.

BeforeAll {
    $script:UnitDir    = Split-Path -Parent $PSCommandPath
    $script:TestsRoot  = Split-Path -Parent $UnitDir
    $script:RepoRoot   = Split-Path -Parent $TestsRoot
    $script:ModuleRoot = Join-Path $RepoRoot 'PowerArubaSW'
    $script:Manifest   = Join-Path $ModuleRoot 'PowerArubaSW.psd1'

    $loaded = Get-Module -Name 'PowerArubaSW' -ErrorAction SilentlyContinue
    if ($loaded) { Remove-Module $loaded -Force }
    Import-Module $Manifest -Force

    $script:StubConnection = [PSCustomObject]@{
        server      = '198.51.100.1'
        port        = 443
        httpOnly    = $false
        api_version = @{ cur = 8 }
    }
}

Describe 'Syslog - lesende Cmdlets' -Tag 'Unit' {

    BeforeEach {
        $script:CapturedUri = $null
        Mock -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest {
            $script:CapturedUri = $uri
            @{ content = '{"beliebiges_feld":"wert"}' }
        }
    }

    It 'Get-ArubaSWSyslog: GET syslog, Antwort unveraendert' {
        $r = Get-ArubaSWSyslog -connection $StubConnection
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 1 -Exactly `
            -ParameterFilter { $method -eq 'GET' }
        $CapturedUri | Should -Be 'syslog'
        $r.beliebiges_feld | Should -Be 'wert'
    }

    It 'Get-ArubaSWSyslogFilter ohne Namen: GET syslog/filters' {
        $null = Get-ArubaSWSyslogFilter -connection $StubConnection
        $CapturedUri | Should -Be 'syslog/filters'
    }

    It 'Get-ArubaSWSyslogFilter -FilterName: GET syslog/filters/<name>, Name URL-kodiert' {
        $null = Get-ArubaSWSyslogFilter -FilterName 'my filter/1' -connection $StubConnection
        $CapturedUri | Should -Be 'syslog/filters/my%20filter%2F1'
    }

    It 'Get-ArubaSWSyslogEventCriteria: GET .../event-criterias, mit -CriteriaId angehaengt' {
        $null = Get-ArubaSWSyslogEventCriteria -FilterName 'F1' -connection $StubConnection
        $CapturedUri | Should -Be 'syslog/filters/F1/event-criterias'
        $null = Get-ArubaSWSyslogEventCriteria -FilterName 'F1' -CriteriaId '7' -connection $StubConnection
        $CapturedUri | Should -Be 'syslog/filters/F1/event-criterias/7'
    }
}

Describe 'Syslog - schreibende Cmdlets reichen -Body unveraendert durch' -Tag 'Unit' {

    BeforeEach {
        $script:CapturedUri = $null
        $script:CapturedBody = $null
        $script:CapturedMethod = $null
        Mock -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest {
            $script:CapturedUri = $uri
            $script:CapturedBody = $body
            $script:CapturedMethod = $method
            @{ content = '{"ok":true}' }
        }
    }

    It '<Name>: <Methode> <Pfad>, Body unveraendert' -ForEach @(
        @{ Name = 'Set-ArubaSWSyslog';                  Methode = 'PUT';  Pfad = 'syslog';                                 Splat = @{} }
        @{ Name = 'Add-ArubaSWSyslogFilter';            Methode = 'POST'; Pfad = 'syslog/filters';                         Splat = @{} }
        @{ Name = 'Set-ArubaSWSyslogFilter';            Methode = 'PUT';  Pfad = 'syslog/filters/F1';                      Splat = @{ FilterName = 'F1' } }
        @{ Name = 'Add-ArubaSWSyslogEventCriteria';     Methode = 'POST'; Pfad = 'syslog/filters/F1/event-criterias';      Splat = @{ FilterName = 'F1' } }
        @{ Name = 'Set-ArubaSWSyslogEventCriteria';     Methode = 'PUT';  Pfad = 'syslog/filters/F1/event-criterias/3';    Splat = @{ FilterName = 'F1'; CriteriaId = '3' } }
    ) {
        $payload = [PSCustomObject]@{ feld_a = 'x'; feld_b = 2 }
        $r = & $Name @Splat -Body $payload -Confirm:$false -connection $StubConnection
        $CapturedMethod | Should -Be $Methode
        $CapturedUri    | Should -Be $Pfad
        [object]::ReferenceEquals($CapturedBody, $payload) | Should -BeTrue -Because 'der Body wird nicht umgebaut'
        $r.ok | Should -BeTrue
    }

    It '<Name>: kein Request bei -WhatIf' -ForEach @(
        @{ Name = 'Set-ArubaSWSyslog';              Splat = @{} }
        @{ Name = 'Add-ArubaSWSyslogFilter';        Splat = @{} }
        @{ Name = 'Set-ArubaSWSyslogFilter';        Splat = @{ FilterName = 'F1' } }
        @{ Name = 'Add-ArubaSWSyslogEventCriteria'; Splat = @{ FilterName = 'F1' } }
        @{ Name = 'Set-ArubaSWSyslogEventCriteria'; Splat = @{ FilterName = 'F1'; CriteriaId = '3' } }
    ) {
        & $Name @Splat -Body @{ a = 1 } -WhatIf -connection $StubConnection
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 0 -Exactly
    }

    It 'lehnt ein fehlendes -Body ab' {
        { Set-ArubaSWSyslog -Body $null -Confirm:$false -connection $StubConnection } | Should -Throw -ErrorId 'ParameterArgumentValidationError,Set-ArubaSWSyslog'
    }

    It 'akzeptiert eine Hashtable als -Body' {
        $null = Set-ArubaSWSyslog -Body @{ a = 1 } -Confirm:$false -connection $StubConnection
        $CapturedBody.a | Should -Be 1
    }

    It 'leere Antwort des Switches (z. B. 201 ohne Inhalt) fuehrt nicht zum Fehler' {
        Mock -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest { @{ content = '' } }
        { Add-ArubaSWSyslogFilter -Body @{ a = 1 } -Confirm:$false -connection $StubConnection } | Should -Not -Throw
    }
}

Describe 'Syslog - Remove-Cmdlets' -Tag 'Unit' {

    BeforeEach {
        $script:CapturedUri = $null
        Mock -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest {
            $script:CapturedUri = $uri
        }
    }

    It 'Remove-ArubaSWSyslogFilter: DELETE syslog/filters/<name>' {
        Remove-ArubaSWSyslogFilter -FilterName 'F1' -Confirm:$false -connection $StubConnection
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 1 -Exactly `
            -ParameterFilter { $method -eq 'DELETE' }
        $CapturedUri | Should -Be 'syslog/filters/F1'
    }

    It 'Remove-ArubaSWSyslogFilter nimmt FilterName aus der Pipeline (Property)' {
        [PSCustomObject]@{ FilterName = 'F2' } | Remove-ArubaSWSyslogFilter -Confirm:$false -connection $StubConnection
        $CapturedUri | Should -Be 'syslog/filters/F2'
    }

    It 'Remove-ArubaSWSyslogFilter nimmt die Antwort des Switches (filter_name) aus der Pipeline' {
        [PSCustomObject]@{ uri = '/syslog/filters/F3'; filter_name = 'F3'; is_enabled = $true; default_action = 'PERMIT' } |
            Remove-ArubaSWSyslogFilter -Confirm:$false -connection $StubConnection
        $CapturedUri | Should -Be 'syslog/filters/F3'
    }

    It 'Remove-ArubaSWSyslogEventCriteria nimmt filter_name und criteria_id aus der Pipeline' {
        [PSCustomObject]@{ filter_name = 'F3'; criteria_id = 7; type = 'REG_EXPR' } |
            Remove-ArubaSWSyslogEventCriteria -Confirm:$false -connection $StubConnection
        $CapturedUri | Should -Be 'syslog/filters/F3/event-criterias/7'
    }

    It 'Remove-ArubaSWSyslogEventCriteria: DELETE .../event-criterias/<id>' {
        Remove-ArubaSWSyslogEventCriteria -FilterName 'F1' -CriteriaId '9' -Confirm:$false -connection $StubConnection
        $CapturedUri | Should -Be 'syslog/filters/F1/event-criterias/9'
    }

    It 'Remove-Cmdlets: kein Request bei -WhatIf' {
        Remove-ArubaSWSyslogFilter -FilterName 'F1' -WhatIf -connection $StubConnection
        Remove-ArubaSWSyslogEventCriteria -FilterName 'F1' -CriteriaId '9' -WhatIf -connection $StubConnection
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 0 -Exactly
    }

    It 'Remove-Cmdlets haben ConfirmImpact High' {
        foreach ($n in 'Remove-ArubaSWSyslogFilter', 'Remove-ArubaSWSyslogEventCriteria') {
            $attr = (Get-Command $n).ScriptBlock.Attributes | Where-Object { $_ -is [System.Management.Automation.CmdletBindingAttribute] }
            $attr.ConfirmImpact | Should -Be 'High' -Because $n
        }
    }
}
