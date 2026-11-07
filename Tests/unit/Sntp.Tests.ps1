#
# Copyright 2026, PowerArubaSW contributors
# SPDX-License-Identifier: Apache-2.0
#
# Unit-Tests fuer Public/Sntp.ps1 (Inkrement I16).
# Exerziert drei Patterns auf der SNTP-Familie:
#   1. Read-Modify global config (Get-/Set-ArubaSWSntp)
#   2. Collection CRUD mit clientseitigem Filter (Get-ArubaSWSntpServer)
#   3. Composite path parameter "{priority}-{address}" (Remove-ArubaSWSntpServer,
#      mit Pipeline-Input via ValueFromPipelineByPropertyName)

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

Describe 'Get-ArubaSWSntp' -Tag 'Unit' {

    BeforeEach {
        Mock -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest {
            Get-Fixture -Resource system-sntp -Name get-default
        }
    }

    It 'ruft GET system/sntp ueber den Transport-Wrapper' {
        $null = Get-ArubaSWSntp -connection $StubConnection
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 1 -Exactly `
            -ParameterFilter { $method -eq 'GET' -and $uri -eq 'system/sntp' }
    }

    It 'parst sntp_client_operation_mode und sntp_config_poll_interval (echte Feldnamen)' {
        $r = Get-ArubaSWSntp -connection $StubConnection
        $r.sntp_client_operation_mode | Should -Be 'SNTP_UNICAST_MODE'
        $r.sntp_config_poll_interval  | Should -Be 720
    }
}

Describe 'Set-ArubaSWSntp' -Tag 'Unit' {

    BeforeEach {
        $script:CapturedBody = $null
        Mock -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest {
            $script:CapturedBody = $body
            Get-Fixture -Resource system-sntp -Name put-broadcast
        }
    }

    It 'sendet sntp_client_operation_mode als einziges Feld im Body' {
        $null = Set-ArubaSWSntp -sntp_client_operation_mode SNTP_BROADCAST_MODE -confirm:$false -connection $StubConnection
        $CapturedBody.sntp_client_operation_mode | Should -Be 'SNTP_BROADCAST_MODE'
        @($CapturedBody.PSObject.Properties.Name) | Should -Be @('sntp_client_operation_mode')
    }

    It 'verlangt den Modus (Mandatory), der Switch lehnt ein PUT ohne ihn ab' {
        { Set-ArubaSWSntp -confirm:$false -connection $StubConnection -ErrorAction Stop } |
            Should -Throw -ErrorId 'MissingMandatoryParameter,Set-ArubaSWSntp'
    }

    It 'lehnt Modus ausserhalb des ValidateSet ab (auch die alten SM_*-Werte)' {
        { Set-ArubaSWSntp -sntp_client_operation_mode 'SM_UNICAST' -confirm:$false -connection $StubConnection -ErrorAction Stop } |
            Should -Throw -ErrorId 'ParameterArgumentValidationError,Set-ArubaSWSntp'
    }

    It 'macht KEINEN Aufruf bei -WhatIf' {
        Set-ArubaSWSntp -sntp_client_operation_mode SNTP_UNICAST_MODE -WhatIf -connection $StubConnection
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 0 -Exactly
    }
}

Describe 'Get-ArubaSWSntpServer (Collection-Filter-Pattern)' -Tag 'Unit' {

    BeforeEach {
        Mock -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest {
            Get-Fixture -Resource system-sntp_server -Name get-default
        }
    }

    It 'liefert beide konfigurierten Server ohne Filter' {
        $r = @(Get-ArubaSWSntpServer -connection $StubConnection)
        $r.Count | Should -Be 2
        $r[0].sntp_server_priority | Should -Be 1
        $r[1].sntp_server_priority | Should -Be 2
        $r[0].sntp_server_address.octets | Should -Be '192.0.2.10'
    }

    It 'filtert clientseitig nach -sntp_server_priority' {
        $r = Get-ArubaSWSntpServer -sntp_server_priority 1 -connection $StubConnection
        $r.sntp_server_priority | Should -Be 1
        $r.sntp_server_address.octets | Should -Be '192.0.2.10'
    }

    It 'filtert clientseitig nach -sntp_server_address' {
        $r = Get-ArubaSWSntpServer -sntp_server_address '192.0.2.11' -connection $StubConnection
        $r.sntp_server_priority | Should -Be 2
    }

    It 'kombinierte Filter (priority + address) treffen oder leeres Ergebnis' {
        $r = Get-ArubaSWSntpServer -sntp_server_priority 1 -sntp_server_address '192.0.2.10' -connection $StubConnection
        $r.sntp_server_priority | Should -Be 1
        $r2 = Get-ArubaSWSntpServer -sntp_server_priority 1 -sntp_server_address '192.0.2.99' -connection $StubConnection
        $r2 | Should -BeNullOrEmpty
    }

    It 'lehnt priority ausserhalb 1..4 ab' {
        { Get-ArubaSWSntpServer -sntp_server_priority 5 -connection $StubConnection -ErrorAction Stop } |
            Should -Throw -ErrorId 'ParameterArgumentValidationError,Get-ArubaSWSntpServer'
    }
}

Describe 'Add-ArubaSWSntpServer' -Tag 'Unit' {

    BeforeEach {
        $script:CapturedBody = $null
        Mock -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest {
            $script:CapturedBody = $body
            Get-Fixture -Resource system-sntp_server -Name post-add
        }
    }

    It 'ruft POST system/sntp_server mit den gegebenen Feldern auf' {
        $null = Add-ArubaSWSntpServer -sntp_server_priority 3 -sntp_server_address '198.51.100.12' `
            -sntp_server_version 4 -confirm:$false -connection $StubConnection
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 1 -Exactly `
            -ParameterFilter { $method -eq 'POST' -and $uri -eq 'system/sntp_server' }
        $CapturedBody.sntp_server_priority | Should -Be 3
        $CapturedBody.sntp_server_address.octets  | Should -Be '198.51.100.12'
        $CapturedBody.sntp_server_address.version | Should -Be 'IAV_IP_V4'
        $CapturedBody.sntp_server_version  | Should -Be 4
    }

    It 'sendet IPv6-Adressen mit version IAV_IP_V6' {
        $null = Add-ArubaSWSntpServer -sntp_server_priority 3 -sntp_server_address '2001:db8::1' -confirm:$false -connection $StubConnection
        $CapturedBody.sntp_server_address.version | Should -Be 'IAV_IP_V6'
        $CapturedBody.sntp_server_address.octets  | Should -Be '2001:db8::1'
    }

    It 'lehnt Hostnamen ab (der Switch erwartet eine IP)' {
        { Add-ArubaSWSntpServer -sntp_server_priority 3 -sntp_server_address 'ntp.example.com' -confirm:$false -connection $StubConnection -ErrorAction Stop } |
            Should -Throw -ErrorId 'ParameterArgumentTransformationError,Add-ArubaSWSntpServer'
    }

    It 'laesst sntp_server_version weg, wenn nicht gesetzt' {
        $null = Add-ArubaSWSntpServer -sntp_server_priority 3 -sntp_server_address '198.51.100.12' `
            -confirm:$false -connection $StubConnection
        $CapturedBody.PSObject.Properties.Name | Should -Not -Contain 'sntp_server_version'
    }

    It 'verlangt priority + address (beide Mandatory)' {
        { Add-ArubaSWSntpServer -sntp_server_priority 3 -confirm:$false -connection $StubConnection -ErrorAction Stop } |
            Should -Throw -ErrorId 'MissingMandatoryParameter,Add-ArubaSWSntpServer'
        { Add-ArubaSWSntpServer -sntp_server_address '198.51.100.12' -confirm:$false -connection $StubConnection -ErrorAction Stop } |
            Should -Throw -ErrorId 'MissingMandatoryParameter,Add-ArubaSWSntpServer'
    }
}

Describe 'Remove-ArubaSWSntpServer (Composite Path + Pipeline)' -Tag 'Unit' {

    BeforeEach {
        $script:CapturedUri = $null
        Mock -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest {
            $script:CapturedUri = $uri
        }
    }

    It 'baut composite URI "system/sntp_server/{priority}-{address}" korrekt' {
        Remove-ArubaSWSntpServer -sntp_server_priority 1 -sntp_server_address '198.51.100.10' `
            -confirm:$false -connection $StubConnection
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 1 -Exactly `
            -ParameterFilter { $method -eq 'DELETE' }
        $CapturedUri | Should -Be 'system/sntp_server/1-198.51.100.10'
    }

    It 'akzeptiert ein Server-Objekt aus der Pipeline (ValueFromPipelineByPropertyName)' {
        $srv = [PSCustomObject]@{
            sntp_server_priority = 2
            sntp_server_address  = '198.51.100.11'
        }
        $srv | Remove-ArubaSWSntpServer -confirm:$false -connection $StubConnection
        $CapturedUri | Should -Be 'system/sntp_server/2-198.51.100.11'
    }

    It 'akzeptiert das Adressobjekt, wie Get-ArubaSWSntpServer es liefert' {
        $srv = [PSCustomObject]@{
            sntp_server_priority = 1
            sntp_server_address  = [PSCustomObject]@{ version = 'IAV_IP_V4'; octets = '192.0.2.10' }
        }
        $srv | Remove-ArubaSWSntpServer -confirm:$false -connection $StubConnection
        $CapturedUri | Should -Be 'system/sntp_server/1-192.0.2.10'
    }

    It 'macht KEINEN Aufruf bei -WhatIf' {
        Remove-ArubaSWSntpServer -sntp_server_priority 1 -sntp_server_address '198.51.100.10' `
            -WhatIf -connection $StubConnection
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 0 -Exactly
    }
}
