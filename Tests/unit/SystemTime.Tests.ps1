#
# Copyright 2026, PowerArubaSW contributors
# SPDX-License-Identifier: Apache-2.0
#
# Unit-Tests fuer Public/SystemTime.ps1 (Inkrement I17).
# Repariert in der I18-Reflexion (2026-05-31): dot-source des Fixture-Loaders
# wiederhergestellt, Trailing-Whitespace entfernt.

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

Describe 'Get-ArubaSWSystemTime' -Tag 'Unit' {

    BeforeEach {
        Mock -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest {
            Get-Fixture -Resource system-time -Name get-default
        }
    }

    It 'ruft GET /system/time auf' {
        $result = Get-ArubaSWSystemTime -connection $StubConnection
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 1 -Exactly `
            -ParameterFilter { $method -eq 'GET' -and $uri -eq 'system/time' }
        $result.local_utc_offset_in_seconds | Should -Be 3600
        $result.auto_adjust_dst             | Should -BeFalse
        $result.time_server_protocol        | Should -Be 'TSP_NTP'
        $result.time_servers[0].ip_address.octets | Should -Be '192.0.2.10'
    }
}

Describe 'Set-ArubaSWSystemTime' -Tag 'Unit' {

    BeforeEach {
        $script:CapturedBody = $null
        Mock -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest {
            $script:CapturedBody = $body
            Get-Fixture -Resource system-time -Name put-set
        }
    }

    It 'ruft PUT /system/time auf mit modifiziertem Body' {
        $result = Set-ArubaSWSystemTime -local_utc_offset_in_seconds 7200 -Confirm:$false -connection $StubConnection
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 1 -Exactly `
            -ParameterFilter { $method -eq 'PUT' -and $uri -eq 'system/time' }
        $CapturedBody.local_utc_offset_in_seconds | Should -Be 7200
        $result.local_utc_offset_in_seconds       | Should -Be 7200
    }

    It 'sendet nur die explizit uebergebenen Felder im Body (partial update)' {
        $null = Set-ArubaSWSystemTime -auto_adjust_dst:$false -Confirm:$false -connection $StubConnection
        @($CapturedBody.PSObject.Properties.Name) | Should -Be @('auto_adjust_dst')
        $CapturedBody.auto_adjust_dst | Should -BeFalse
    }

    It 'lehnt Versatz ausserhalb der Zeitzonen ab und kennt -time_zone/-system_time nicht mehr' {
        { Set-ArubaSWSystemTime -local_utc_offset_in_seconds 99999 -Confirm:$false -connection $StubConnection -ErrorAction Stop } |
            Should -Throw -ErrorId 'ParameterArgumentValidationError,Set-ArubaSWSystemTime'
        { Set-ArubaSWSystemTime -time_zone '60' -Confirm:$false -connection $StubConnection -ErrorAction Stop } |
            Should -Throw -ErrorId 'NamedParameterNotFound,Set-ArubaSWSystemTime'
    }

    It 'macht KEINEN Aufruf bei -WhatIf' {
        Set-ArubaSWSystemTime -local_utc_offset_in_seconds 3600 -WhatIf -connection $StubConnection
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 0 -Exactly
    }
}

Describe 'Set-ArubaSWSystemTimeManually' -Tag 'Unit' {

    BeforeEach {
        $script:CapturedBody = $null
        Mock -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest {
            $script:CapturedBody = $body
            @{ content = '' }
        }
    }

    It 'ruft POST /system/time/setmanually mit date+time im Body auf' {
        Set-ArubaSWSystemTimeManually -date "01/01/2026" -time "12:00:00" -Confirm:$false -connection $StubConnection
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 1 -Exactly `
            -ParameterFilter { $method -eq 'POST' -and $uri -eq 'system/time/setmanually' }
        $CapturedBody.date | Should -Be "01/01/2026"
        $CapturedBody.time | Should -Be "12:00:00"
    }

    It 'verlangt date + time (beide Mandatory)' {
        { Set-ArubaSWSystemTimeManually -date "01/01/2026" -Confirm:$false -connection $StubConnection -ErrorAction Stop } |
            Should -Throw -ErrorId 'MissingMandatoryParameter,Set-ArubaSWSystemTimeManually'
        { Set-ArubaSWSystemTimeManually -time "12:00:00" -Confirm:$false -connection $StubConnection -ErrorAction Stop } |
            Should -Throw -ErrorId 'MissingMandatoryParameter,Set-ArubaSWSystemTimeManually'
    }

    It 'macht KEINEN Aufruf bei -WhatIf' {
        Set-ArubaSWSystemTimeManually -date "01/01/2026" -time "12:00:00" -WhatIf -connection $StubConnection
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 0 -Exactly
    }
}
