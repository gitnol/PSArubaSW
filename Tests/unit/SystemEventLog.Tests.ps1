#
# Copyright 2026, PowerArubaSW contributors
# SPDX-License-Identifier: Apache-2.0
#
# Unit-Tests fuer Public/SystemEventLog.ps1 und Public/TraceRoute.ps1 (Inkrement I36).

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

Describe 'Get-ArubaSWSystemEventLog' -Tag 'Unit' {

    BeforeEach {
        Mock -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest {
            Get-Fixture -Resource system-event-log -Name get-count3
        }
    }

    It 'ruft GET system-event-log ohne Parameter auf und liefert die Eintraege' {
        $r = @(Get-ArubaSWSystemEventLog -connection $StubConnection)
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 1 -Exactly -ParameterFilter { $method -eq 'GET' -and $uri -eq 'system-event-log' }
        $r.Count | Should -Be 3
        $r[0].event_type | Should -Be 'EVENT_SYSLOG'
        $r[0].event_data.severity | Should -Be 'INFO'
    }

    It '-Count geht als count=<n> an den Switch (der einzige Abfrageparameter, den er kennt)' {
        $null = Get-ArubaSWSystemEventLog -Count 3 -connection $StubConnection
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 1 -Exactly -ParameterFilter { $uri -eq 'system-event-log?count=3' }
    }

    It 'gibt eine leere Liste zurueck, wenn die Antwort keine Eintraege enthaelt' {
        Mock -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest {
            [pscustomobject]@{ content = '{"collection_result":{"total_elements_count":0,"filtered_elements_count":0}}' }
        }
        @(Get-ArubaSWSystemEventLog -connection $StubConnection).Count | Should -Be 0
    }

    Context 'Filter laufen im Cmdlet' {

        BeforeEach {
            Mock -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest {
                $e = @(
                    @{ id = 'a'; sev = 'INFO'; mod = 'HTTP'; t = 1793129000 }
                    @{ id = 'b'; sev = 'WARNING'; mod = 'MGR'; t = 1793129500 }
                    @{ id = 'c'; sev = 'ERROR'; mod = 'HTTP'; t = 1793130000 }
                ) | ForEach-Object { @{ event_type = 'EVENT_SYSLOG'; event_data = @{ event_id = $_.id; severity = $_.sev; system_module = $_.mod; date_time = @{ seconds_since_unix_epoch = $_.t } } } }
                [pscustomobject]@{ content = (@{ collection_result = @{ total_elements_count = 3 }; device_event_element = @($e) } | ConvertTo-Json -Depth 8) }
            }
        }

        It '-Severity filtert nach Schweregrad' {
            $r = @(Get-ArubaSWSystemEventLog -Severity WARNING, ERROR -connection $StubConnection)
            $r.Count | Should -Be 2
            $r.event_data.event_id | Should -Be @('b', 'c')
        }

        It '-Module filtert nach Modul' {
            $r = @(Get-ArubaSWSystemEventLog -Module HTTP -connection $StubConnection)
            $r.event_data.event_id | Should -Be @('a', 'c')
        }

        It '-Since filtert nach Zeitpunkt (UNIX-Sekunden)' {
            $since = [DateTimeOffset]::FromUnixTimeSeconds(1793129400).UtcDateTime
            $r = @(Get-ArubaSWSystemEventLog -Since $since -connection $StubConnection)
            $r.event_data.event_id | Should -Be @('b', 'c')
        }

        It 'kombiniert die Filter (UND)' {
            $r = @(Get-ArubaSWSystemEventLog -Severity ERROR -Module HTTP -connection $StubConnection)
            $r.Count | Should -Be 1
            $r[0].event_data.event_id | Should -Be 'c'
        }
    }

    It '-Count ist auf 1 bis 100000 begrenzt' {
        { Get-ArubaSWSystemEventLog -Count 0 -connection $StubConnection -ErrorAction Stop } |
            Should -Throw -ErrorId 'ParameterArgumentValidationError,Get-ArubaSWSystemEventLog'
    }
}

Describe 'Test-ArubaSWTraceRoute' -Tag 'Unit' {

    BeforeEach {
        $script:CapturedBody = $null
        $script:CapturedUri  = $null
        Mock -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest {
            $script:CapturedBody = $body
            $script:CapturedUri  = $uri
            Get-Fixture -Resource trace-route -Name post-gateway
        }
    }

    It 'sendet POST trace-route mit destination.ip_address (echtes Format, nicht destination_ip)' {
        $null = Test-ArubaSWTraceRoute -ipv4_address 198.51.100.1 -connection $StubConnection
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 1 -Exactly -ParameterFilter { $method -eq 'POST' -and $uri -eq 'trace-route' }
        $CapturedBody.destination.ip_address.version | Should -Be 'IAV_IP_V4'
        $CapturedBody.destination.ip_address.octets | Should -Be '198.51.100.1'
        $CapturedBody.PSObject.Properties['max_ttl'] | Should -BeNullOrEmpty
    }

    It '-max_ttl wird mitgesendet' {
        $null = Test-ArubaSWTraceRoute -ipv4_address 198.51.100.1 -max_ttl 5 -connection $StubConnection
        $CapturedBody.max_ttl | Should -Be 5
    }

    It 'liefert je Hop ein Objekt mit TTL, Gateway und Antwortzeiten' {
        $r = @(Test-ArubaSWTraceRoute -ipv4_address 198.51.100.1 -connection $StubConnection)
        $r.Count | Should -Be 1
        $r[0].ttl | Should -Be 1
        $r[0].gateway | Should -Be '198.51.100.1'
        @($r[0].time_ms).Count | Should -Be 3
    }

    It 'verlangt -ipv4_address (Pflichtparameter)' {
        $p = (Get-Command Test-ArubaSWTraceRoute).Parameters['ipv4_address']
        $p.Attributes.Where({ $_ -is [System.Management.Automation.ParameterAttribute] }).Mandatory | Should -BeTrue
    }

    It '-max_ttl ist auf 1 bis 255 begrenzt' {
        { Test-ArubaSWTraceRoute -ipv4_address 198.51.100.1 -max_ttl 300 -connection $StubConnection -ErrorAction Stop } |
            Should -Throw -ErrorId 'ParameterArgumentValidationError,Test-ArubaSWTraceRoute'
    }
}
