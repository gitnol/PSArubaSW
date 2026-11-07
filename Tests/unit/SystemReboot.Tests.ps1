#
# Copyright 2026, PowerArubaSW contributors
# SPDX-License-Identifier: Apache-2.0
#
# Unit-Tests fuer Public/SystemReboot.ps1 (Inkrement I15, Body boot_image I46).
# Restart-ArubaSWSystem: destruktives POST + ParameterSet (Switch/Standby/Member),
# ShouldProcess + ConfirmImpact='High'.

BeforeAll {
    $script:UnitDir    = Split-Path -Parent $PSCommandPath
    $script:TestsRoot  = Split-Path -Parent $UnitDir
    $script:RepoRoot   = Split-Path -Parent $TestsRoot
    $script:ModuleRoot = Join-Path $RepoRoot 'PowerArubaSW'
    $script:Manifest   = Join-Path $ModuleRoot 'PowerArubaSW.psd1'

    $loaded = Get-Module -Name 'PowerArubaSW' -ErrorAction SilentlyContinue
    if ($loaded) { Remove-Module $loaded -Force }
    Import-Module $Manifest -Force

    . "$UnitDir\_helpers\Get-Fixture.ps1"

    $script:StubConnection = [PSCustomObject]@{
        server      = '198.51.100.1'
        port        = 443
        httpOnly    = $false
        api_version = @{ cur = 8 }
    }
}

Describe 'Restart-ArubaSWSystem -boot_image (Standardgeraet)' -Tag 'Unit' {

    BeforeEach {
        $script:Body = $null
        Mock -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest {
            $script:Body = $body
            @{ content = '' }
        }
    }

    It 'sendet POST system/reboot mit boot_image' {
        Restart-ArubaSWSystem -boot_image BI_SECONDARY_IMAGE -Confirm:$false -connection $StubConnection
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 1 -Exactly `
            -ParameterFilter { $method -eq 'POST' -and $uri -eq 'system/reboot' }
        $Body.boot_image | Should -Be 'BI_SECONDARY_IMAGE'
    }

    It 'nimmt beide Images an' -ForEach @(
        @{ Image = 'BI_PRIMARY_IMAGE' }
        @{ Image = 'BI_SECONDARY_IMAGE' }
    ) {
        Restart-ArubaSWSystem -boot_image $Image -Confirm:$false -connection $StubConnection
        $Body.boot_image | Should -Be $Image
    }

    It 'lehnt ein unbekanntes Image ab' {
        { Restart-ArubaSWSystem -boot_image BI_BOGUS -Confirm:$false -connection $StubConnection -ErrorAction Stop } |
            Should -Throw -ErrorId 'ParameterArgumentValidationError,Restart-ArubaSWSystem'
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 0 -Exactly
    }

    It 'macht KEINEN Aufruf bei -WhatIf' {
        Restart-ArubaSWSystem -boot_image BI_SECONDARY_IMAGE -WhatIf -connection $StubConnection
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 0 -Exactly
    }

    It 'akzeptiert leeren Response-Body (Reboot quittiert oft mit content="")' {
        { Restart-ArubaSWSystem -boot_image BI_SECONDARY_IMAGE -Confirm:$false -connection $StubConnection } |
            Should -Not -Throw
    }
}

Describe 'Restart-ArubaSWSystem -Standby' -Tag 'Unit' {

    BeforeEach {
        Mock -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest { @{ content = '' } }
    }

    It 'ruft POST system/reboot/standby auf' {
        Restart-ArubaSWSystem -Standby -Confirm:$false -connection $StubConnection
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 1 -Exactly `
            -ParameterFilter { $method -eq 'POST' -and $uri -eq 'system/reboot/standby' }
    }
}

Describe 'Restart-ArubaSWSystem -member_id <id>' -Tag 'Unit' {

    BeforeEach {
        Mock -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest { @{ content = '' } }
    }

    It 'ruft POST system/reboot/member/<id> mit der gegebenen ID auf' {
        Restart-ArubaSWSystem -member_id 2 -Confirm:$false -connection $StubConnection
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 1 -Exactly `
            -ParameterFilter { $method -eq 'POST' -and $uri -eq 'system/reboot/member/2' }
    }

    It 'lehnt member_id ausserhalb 1..16 ab (ValidateRange)' {
        { Restart-ArubaSWSystem -member_id 0 -Confirm:$false -connection $StubConnection -ErrorAction Stop } |
            Should -Throw -ErrorId 'ParameterArgumentValidationError,Restart-ArubaSWSystem'
        { Restart-ArubaSWSystem -member_id 17 -Confirm:$false -connection $StubConnection -ErrorAction Stop } |
            Should -Throw -ErrorId 'ParameterArgumentValidationError,Restart-ArubaSWSystem'
    }
}

Describe 'Restart-ArubaSWSystem Parameter-Sets sind exklusiv' -Tag 'Unit' {

    It 'kombinierte -Standby + -member_id wird zurueckgewiesen' {
        # Zwei verschiedene ParameterSets, gleichzeitig genutzt -> Bindings-Fehler.
        { Restart-ArubaSWSystem -Standby -member_id 2 -Confirm:$false -connection $StubConnection -ErrorAction Stop } |
            Should -Throw -ErrorId 'AmbiguousParameterSet,Restart-ArubaSWSystem'
    }
}
