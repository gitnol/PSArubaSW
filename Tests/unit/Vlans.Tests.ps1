#
# Copyright 2026, PowerArubaSW contributors
# SPDX-License-Identifier: Apache-2.0
#
# Unit-Tests für Public/Vlans.ps1 — mockt den Transport-Wrapper
# Invoke-ArubaSWWebRequest und verifiziert die Cmdlet-Logik ohne echte Hardware.
# Stellvertretend für das Get/Add/Set/Remove-Muster aller Switch-Ressourcen.

BeforeAll {
    $script:UnitDir    = Split-Path -Parent $PSCommandPath        # ...\Tests\unit
    $script:TestsRoot  = Split-Path -Parent $UnitDir              # ...\Tests
    $script:RepoRoot   = Split-Path -Parent $TestsRoot            # ...\PowerArubaSW-master
    $script:ModuleRoot = Join-Path $RepoRoot 'PowerArubaSW'
    $script:Manifest   = Join-Path $ModuleRoot 'PowerArubaSW.psd1'

    $loaded = Get-Module -Name 'PowerArubaSW' -ErrorAction SilentlyContinue
    if ($loaded) { Remove-Module $loaded -Force }
    Import-Module $Manifest -Force

    # Recorded-Fixtures-Loader (Inkrement I10) — ersetzt die frueheren Inline-JSON-Mocks.
    # Macht den Test-Input gegen das echte API-Response-Format pruefbar und
    # vermeidet, dass der Mock ein konstruiertes Format testet, das vom Switch nie kommt.
    . "$UnitDir\_helpers\Get-Fixture.ps1"

    # Stub-Connection, der ValidateNotNullOrEmpty erfüllt; Inhalt egal, weil der Transport gemockt ist.
    $script:StubConnection = [PSCustomObject]@{
        server      = '198.51.100.1'
        port        = 443
        httpOnly    = $false
        api_version = @{ cur = 8 }
    }
}

Describe 'Get-ArubaSWVlans' -Tag 'Unit' {

    BeforeEach {
        # Mock im Modul-Scope — Fixture statt Inline-JSON (Inkrement I10).
        Mock -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest {
            Get-Fixture -Resource vlans -Name get-default
        }
    }

    It 'ruft GET vlans über den Transport-Wrapper auf' {
        $null = Get-ArubaSWVlans -connection $StubConnection
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 1 -Exactly `
            -ParameterFilter { $method -eq 'GET' -and $uri -eq 'vlans' }
    }

    It 'parst die VLAN-Liste aus dem JSON-Response (3 VLANs aus Fixture)' {
        $r = Get-ArubaSWVlans -connection $StubConnection
        $r.Count | Should -Be 3
        $r[0].vlan_id | Should -Be 1
        $r[0].name | Should -Be 'DEFAULT_VLAN'
        $r[1].vlan_id | Should -Be 85
        $r[2].vlan_id | Should -Be 100
        $r[2].name | Should -Be 'Voice'
    }

    It 'filtert nach -id korrekt' {
        $r = Get-ArubaSWVlans -id 85 -connection $StubConnection
        $r.vlan_id | Should -Be 85
        $r.name | Should -Be 'PowerArubaSW'
    }

    It 'filtert nach -name (Regex-Match)' {
        $r = Get-ArubaSWVlans -name 'PowerArubaSW' -connection $StubConnection
        $r.vlan_id | Should -Be 85
    }

    It 'findet per -name auch einen Teil des Namens (Match, kein Vergleich auf Gleichheit)' {
        $r = Get-ArubaSWVlans -name 'ower' -connection $StubConnection
        @($r).Count | Should -Be 1
        $r.vlan_id | Should -Be 85
    }
}

Describe 'Add-ArubaSWVlans' -Tag 'Unit' {

    BeforeEach {
        $script:CapturedBody = $null
        Mock -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest {
            $script:CapturedBody = $body
            Get-Fixture -Resource vlans -Name post-add
        }
    }

    It 'ruft POST vlans mit gesetztem vlan_id im Body auf' {
        $null = Add-ArubaSWVlans -id 85 -name 'PowerArubaSW' -connection $StubConnection
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 1 -Exactly `
            -ParameterFilter { $method -eq 'POST' -and $uri -eq 'vlans' }
        $CapturedBody.vlan_id | Should -Be 85
        $CapturedBody.name    | Should -Be 'PowerArubaSW'
    }

    It 'setzt Default-Namen "VLAN<id>" wenn -name nicht angegeben' {
        $null = Add-ArubaSWVlans -id 42 -connection $StubConnection
        # -BeExactly: -Be ist bei Zeichenketten case-insensitive und liesse "vlan42" durch (Mutant V01, L44)
        $CapturedBody.name | Should -BeExactly 'VLAN42'
    }

    It 'übersetzt -is_voice_enabled in $true im Body' {
        $null = Add-ArubaSWVlans -id 85 -is_voice_enabled -connection $StubConnection
        $CapturedBody.is_voice_enabled | Should -BeTrue
    }

    It 'übersetzt -is_jumbo_enabled:$false in $false im Body' {
        $null = Add-ArubaSWVlans -id 85 -is_jumbo_enabled:$false -connection $StubConnection
        $CapturedBody.is_jumbo_enabled | Should -BeFalse
    }

    It 'übersetzt jeden Schalter in beide Werte und lässt nicht gesetzte weg' {
        $null = Add-ArubaSWVlans -id 85 -is_jumbo_enabled -is_dsnoop_enabled -is_voice_enabled:$false -connection $StubConnection
        $CapturedBody.is_jumbo_enabled  | Should -BeTrue
        $CapturedBody.is_dsnoop_enabled | Should -BeTrue
        $CapturedBody.is_voice_enabled  | Should -BeFalse
        $null = Add-ArubaSWVlans -id 85 -connection $StubConnection
        $CapturedBody.PSObject.Properties.Name | Should -Not -Contain 'is_jumbo_enabled'
    }
}

Describe 'Set-ArubaSWVlans' -Tag 'Unit' {

    BeforeEach {
        $script:CapturedBody = $null
        $script:CapturedUri = $null
        Mock -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest {
            $script:CapturedBody = $body
            $script:CapturedUri  = $uri
            Get-Fixture -Resource vlans -Name put-set
        }
        # Für den nicht-Pipeline-Fall ruft Set- intern Get-ArubaSWVlans auf, um den
        # alten Namen zu ermitteln. Mock dafür separat — gleiche Modul-Scope-Mechanik.
        Mock -ModuleName PowerArubaSW Get-ArubaSWVlans {
            [PSCustomObject]@{ vlan_id = 85; name = 'OldName' }
        }
    }

    It 'ruft PUT vlans/<id> mit konfiguriertem Body auf' {
        $null = Set-ArubaSWVlans -id 85 -name 'changed' -confirm:$false -connection $StubConnection
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 1 -Exactly `
            -ParameterFilter { $method -eq 'PUT' }
        $CapturedUri | Should -Be 'vlans/85'
        $CapturedBody.vlan_id | Should -Be 85
        $CapturedBody.name    | Should -Be 'changed'
    }

    It 'akzeptiert ein Vlan-Objekt aus der Pipeline (ParameterSet vlan)' {
        $vlan = [PSCustomObject]@{ vlan_id = 85; name = 'piped' }
        $null = $vlan | Set-ArubaSWVlans -name 'new' -confirm:$false -connection $StubConnection
        $CapturedUri | Should -Be 'vlans/85'
        $CapturedBody.name | Should -Be 'new'
    }

    It 'übernimmt den Namen des Pipeline-Objekts, ohne ihn beim Switch nachzuschlagen' {
        $vlan = [PSCustomObject]@{ vlan_id = 85; name = 'piped' }
        $null = $vlan | Set-ArubaSWVlans -is_voice_enabled -confirm:$false -connection $StubConnection
        $CapturedBody.name | Should -BeExactly 'piped'
        Should -Invoke -ModuleName PowerArubaSW Get-ArubaSWVlans -Times 0 -Exactly
    }

    It 'schlägt den alten Namen nach, wenn weder -name noch ein Pipeline-Objekt vorliegt' {
        $null = Set-ArubaSWVlans -id 85 -is_voice_enabled -confirm:$false -connection $StubConnection
        $CapturedBody.name | Should -BeExactly 'OldName'
        Should -Invoke -ModuleName PowerArubaSW Get-ArubaSWVlans -Times 1 -Exactly
    }

    It 'übersetzt jeden Schalter in beide Werte' {
        $null = Set-ArubaSWVlans -id 85 -name 'x' -is_voice_enabled -is_jumbo_enabled -is_dsnoop_enabled:$false -confirm:$false -connection $StubConnection
        $CapturedBody.is_voice_enabled  | Should -BeTrue
        $CapturedBody.is_jumbo_enabled  | Should -BeTrue
        $CapturedBody.is_dsnoop_enabled | Should -BeFalse
        $null = Set-ArubaSWVlans -id 85 -name 'x' -is_voice_enabled:$false -is_jumbo_enabled:$false -is_dsnoop_enabled -confirm:$false -connection $StubConnection
        $CapturedBody.is_voice_enabled  | Should -BeFalse
        $CapturedBody.is_jumbo_enabled  | Should -BeFalse
        $CapturedBody.is_dsnoop_enabled | Should -BeTrue
    }

    It 'macht KEINEN Aufruf bei -WhatIf' {
        Set-ArubaSWVlans -id 85 -name 'changed' -WhatIf -connection $StubConnection
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 0 -Exactly `
            -ParameterFilter { $method -eq 'PUT' }
    }
}

Describe 'Remove-ArubaSWVlans' -Tag 'Unit' {

    BeforeEach {
        Mock -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest { }
    }

    It 'ruft DELETE vlans/<id> auf' {
        Remove-ArubaSWVlans -id 85 -confirm:$false -connection $StubConnection
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 1 -Exactly `
            -ParameterFilter { $method -eq 'DELETE' -and $uri -eq 'vlans/85' }
    }

    It 'akzeptiert ein Vlan-Objekt aus der Pipeline' {
        $vlan = [PSCustomObject]@{ vlan_id = 85 }
        $vlan | Remove-ArubaSWVlans -confirm:$false -connection $StubConnection
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 1 -Exactly `
            -ParameterFilter { $method -eq 'DELETE' -and $uri -eq 'vlans/85' }
    }

    It 'macht KEINEN Aufruf bei -WhatIf' {
        Remove-ArubaSWVlans -id 85 -WhatIf -connection $StubConnection
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 0 -Exactly
    }
}

Describe 'Vlans Parameter-Validierung' -Tag 'Unit' {

    It 'Add-ArubaSWVlans verlangt -id (Mandatory)' {
        { Add-ArubaSWVlans -connection $StubConnection -ErrorAction Stop } |
            Should -Throw -ErrorId 'MissingMandatoryParameter,Add-ArubaSWVlans'
    }

    It 'Remove-ArubaSWVlans lehnt $null als -connection ab (ValidateNotNullOrEmpty)' {
        { Remove-ArubaSWVlans -id 85 -connection $null -confirm:$false -ErrorAction Stop } |
            Should -Throw -ErrorId 'ParameterArgumentValidationError,Remove-ArubaSWVlans'
    }
}
