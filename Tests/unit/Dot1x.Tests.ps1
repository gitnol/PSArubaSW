#
# Copyright 2026, PowerArubaSW contributors
# SPDX-License-Identifier: Apache-2.0
#
# Unit-Tests fuer Public/Dot1x.ps1 (Inkrement I36). Die Fixtures sind echte Antworten einer 2540
# (YC.16.11.0010); die Set-Cmdlets lesen den Zustand zuerst und senden das vollstaendige Objekt.

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

Describe 'Dot1x global' -Tag 'Unit' {

    BeforeEach {
        $script:CapturedBody = $null
        $script:CapturedUri  = $null
        Mock -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest {
            if ($method -eq 'PUT') {
                $script:CapturedBody = $body
                $script:CapturedUri  = $uri
                Get-Fixture -Resource dot1x -Name put-set
            }
            else {
                Get-Fixture -Resource dot1x -Name get-default
            }
        }
    }

    It 'Get-ArubaSWDot1x ruft GET dot1x auf und liefert die echten Felder' {
        $r = Get-ArubaSWDot1x -connection $StubConnection
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 1 -Exactly -ParameterFilter { $method -eq 'GET' -and $uri -eq 'dot1x' }
        $r.is_dot1x_enabled | Should -BeFalse
        $r.use_lldp_data | Should -BeFalse
    }

    It 'Set-ArubaSWDot1x liest zuerst und sendet das vollstaendige Objekt ohne uri' {
        $null = Set-ArubaSWDot1x -cached_reauth_delay 30 -Confirm:$false -connection $StubConnection
        $CapturedUri | Should -Be 'dot1x'
        $CapturedBody.cached_reauth_delay | Should -Be 30
        $CapturedBody.is_dot1x_enabled | Should -BeFalse
        $CapturedBody.allow_gvrp_vlans | Should -BeFalse
        $CapturedBody.use_lldp_data | Should -BeFalse
        $CapturedBody.PSObject.Properties['uri'] | Should -BeNullOrEmpty
    }

    It 'Set-ArubaSWDot1x sendet Schalter als echte Booleans, auch -Schalter:$false' {
        $null = Set-ArubaSWDot1x -is_dot1x_enabled -use_lldp_data:$false -Confirm:$false -connection $StubConnection
        $CapturedBody.is_dot1x_enabled | Should -BeOfType [bool]
        $CapturedBody.is_dot1x_enabled | Should -BeTrue
        $CapturedBody.use_lldp_data | Should -BeFalse
    }

    It 'Set-ArubaSWDot1x macht keinen PUT bei -WhatIf' {
        Set-ArubaSWDot1x -cached_reauth_delay 5 -WhatIf -connection $StubConnection
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 0 -Exactly -ParameterFilter { $method -eq 'PUT' }
    }
}

Describe 'Dot1x Authentication Method' -Tag 'Unit' {

    BeforeEach {
        $script:CapturedBody = $null
        Mock -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest {
            if ($method -eq 'PUT') { $script:CapturedBody = $body; Get-Fixture -Resource dot1x-authentication_method -Name put-set }
            else { Get-Fixture -Resource dot1x-authentication_method -Name get-default }
        }
    }

    It 'Get ruft GET dot1x/authentication_method auf' {
        $r = Get-ArubaSWDot1xAuthenticationMethod -connection $StubConnection
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 1 -Exactly -ParameterFilter { $method -eq 'GET' -and $uri -eq 'dot1x/authentication_method' }
        $r.primary_authentication_method | Should -Be 'DPAM_LOCAL'
    }

    It 'Set aendert nur die uebergebenen Felder' {
        $null = Set-ArubaSWDot1xAuthenticationMethod -primary_authentication_method DPAM_EAP_RADIUS -Confirm:$false -connection $StubConnection
        $CapturedBody.primary_authentication_method | Should -Be 'DPAM_EAP_RADIUS'
        $CapturedBody.secondary_authentication_method | Should -Be 'DSAM_NONE'
    }

    It 'Set lehnt DPAM_RADIUS ab (der Switch kennt den Wert nicht)' {
        { Set-ArubaSWDot1xAuthenticationMethod -primary_authentication_method DPAM_RADIUS -Confirm:$false -connection $StubConnection -ErrorAction Stop } |
            Should -Throw -ErrorId 'ParameterArgumentValidationError,Set-ArubaSWDot1xAuthenticationMethod'
    }
}

Describe 'Dot1x Authenticator' -Tag 'Unit' {

    BeforeEach {
        $script:CapturedBody = $null
        $script:CapturedUri  = $null
        Mock -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest {
            if ($method -eq 'PUT') { $script:CapturedBody = $body; $script:CapturedUri = $uri; Get-Fixture -Resource dot1x-authenticator -Name put-port21 }
            elseif ($uri -eq 'dot1x/authenticator') { Get-Fixture -Resource dot1x-authenticator -Name get-list }
            else { Get-Fixture -Resource dot1x-authenticator -Name get-port21 }
        }
    }

    It 'Get ohne Port liefert die ausgepackte Liste' {
        $r = @(Get-ArubaSWDot1xAuthenticator -connection $StubConnection)
        $r.Count | Should -Be 2
        $r[0].port_id | Should -Be '1'
    }

    It 'Get mit Port ruft dot1x/authenticator/<id> auf' {
        $r = Get-ArubaSWDot1xAuthenticator -port_id 21 -connection $StubConnection
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 1 -Exactly -ParameterFilter { $method -eq 'GET' -and $uri -eq 'dot1x/authenticator/21' }
        $r.control | Should -Be 'DAPC_AUTO'
        $r.quiet_period | Should -Be 60
    }

    It 'Set sendet das vollstaendige Objekt und aendert nur die uebergebenen Felder' {
        $null = Set-ArubaSWDot1xAuthenticator -port_id 21 -is_authenticator_enabled -client_limit 4 -Confirm:$false -connection $StubConnection
        $CapturedUri | Should -Be 'dot1x/authenticator/21'
        $CapturedBody.is_authenticator_enabled | Should -BeTrue
        $CapturedBody.client_limit | Should -Be 4
        $CapturedBody.quiet_period | Should -Be 60
        $CapturedBody.max_requests | Should -Be 2
        $CapturedBody.control | Should -Be 'DAPC_AUTO'
        $CapturedBody.PSObject.Properties['uri'] | Should -BeNullOrEmpty
    }

    It 'Set nimmt port_id aus der Pipeline' {
        Get-ArubaSWDot1xAuthenticator -port_id 21 -connection $StubConnection |
            Set-ArubaSWDot1xAuthenticator -quiet_period 90 -Confirm:$false -connection $StubConnection | Out-Null
        $CapturedUri | Should -Be 'dot1x/authenticator/21'
        $CapturedBody.quiet_period | Should -Be 90
    }

    It 'Set lehnt DAPC_FORCE_AUTHORIZED ab (am Switch: "Unsupported control type")' {
        { Set-ArubaSWDot1xAuthenticator -port_id 21 -control DAPC_FORCE_AUTHORIZED -Confirm:$false -connection $StubConnection -ErrorAction Stop } |
            Should -Throw -ErrorId 'ParameterArgumentValidationError,Set-ArubaSWDot1xAuthenticator'
    }

    It 'Set prueft den VLAN-Bereich' {
        { Set-ArubaSWDot1xAuthenticator -port_id 21 -unauthorized_vlan_id 5000 -Confirm:$false -connection $StubConnection -ErrorAction Stop } |
            Should -Throw -ErrorId 'ParameterArgumentValidationError,Set-ArubaSWDot1xAuthenticator'
    }

    It 'Set macht keinen PUT bei -WhatIf' {
        Set-ArubaSWDot1xAuthenticator -port_id 21 -client_limit 2 -WhatIf -connection $StubConnection
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 0 -Exactly -ParameterFilter { $method -eq 'PUT' }
    }
}

Describe 'Dot1x Status, Stats, ClientStats, SessionCounters, SupplicantStats' -Tag 'Unit' {

    # Discovery-Zeit: -ForEach braucht die Daten schon beim Einlesen, nicht erst im BeforeAll.
    $script:StatCases = @(
        @{ Cmd = 'Get-ArubaSWDot1xAuthenticatorStatus'; Resource = 'dot1x-authenticator-status'; ListUri = 'dot1x/authenticator/status'; PortUri = 'dot1x/authenticator/21/status' }
        @{ Cmd = 'Get-ArubaSWDot1xAuthenticatorStats'; Resource = 'dot1x-authenticator-stats'; ListUri = 'dot1x/authenticator/stats'; PortUri = 'dot1x/authenticator/21/stats' }
        @{ Cmd = 'Get-ArubaSWDot1xAuthenticatorClientStats'; Resource = 'dot1x-authenticator-client_stats'; ListUri = 'dot1x/authenticator/client_stats'; PortUri = 'dot1x/authenticator/21/client_stats' }
        @{ Cmd = 'Get-ArubaSWDot1xAuthenticatorSessionCounters'; Resource = 'dot1x-authenticator-session_counters'; ListUri = 'dot1x/authenticator/session_counters'; PortUri = 'dot1x/authenticator/21/session_counters' }
        @{ Cmd = 'Get-ArubaSWDot1xSupplicantStats'; Resource = 'dot1x-supplicant-stats'; ListUri = 'dot1x/supplicant/stats'; PortUri = 'dot1x/supplicant/21/stats' }
    )

    It '<Cmd>: ohne Port die ausgepackte Liste von <ListUri>' -ForEach $script:StatCases {
        $fx = Get-Fixture -Resource $Resource -Name get-list
        Mock -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -MockWith { $fx }.GetNewClosure()
        $r = @(& $Cmd -connection $StubConnection)
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 1 -Exactly -ParameterFilter { $method -eq 'GET' -and $uri -eq $ListUri }
        $r.Count | Should -Be 2
        $r[0].port_id | Should -Be '1'
    }

    It '<Cmd>: mit Port das einzelne Objekt von <PortUri>' -ForEach $script:StatCases {
        $fx = Get-Fixture -Resource $Resource -Name get-port21
        Mock -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -MockWith { $fx }.GetNewClosure()
        $r = & $Cmd -port_id 21 -connection $StubConnection
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 1 -Exactly -ParameterFilter { $method -eq 'GET' -and $uri -eq $PortUri }
        $r.port_id | Should -Be '21'
    }
}

Describe 'Dot1x Aktionen' -Tag 'Unit' {

    BeforeEach {
        Mock -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest { }
    }

    It '<Cmd> sendet POST <Uri>' -ForEach @(
        @{ Cmd = 'Clear-ArubaSWDot1xAuthenticatorStats'; Uri = 'dot1x/authenticator/21/clearstats' }
        @{ Cmd = 'Initialize-ArubaSWDot1xAuthenticator'; Uri = 'dot1x/authenticator/21/initialize' }
        @{ Cmd = 'Invoke-ArubaSWDot1xReauthenticate'; Uri = 'dot1x/authenticator/21/reauthenticate' }
        @{ Cmd = 'Clear-ArubaSWDot1xSupplicantStats'; Uri = 'dot1x/supplicant/21/clearstats' }
        @{ Cmd = 'Initialize-ArubaSWDot1xSupplicant'; Uri = 'dot1x/supplicant/21/initialize' }
    ) {
        & $Cmd -port_id 21 -Confirm:$false -connection $StubConnection
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 1 -Exactly -ParameterFilter { $method -eq 'POST' -and $uri -eq $Uri }
    }

    It '<Cmd> macht bei -WhatIf keinen Aufruf' -ForEach @(
        @{ Cmd = 'Clear-ArubaSWDot1xAuthenticatorStats' }
        @{ Cmd = 'Initialize-ArubaSWDot1xAuthenticator' }
        @{ Cmd = 'Invoke-ArubaSWDot1xReauthenticate' }
        @{ Cmd = 'Clear-ArubaSWDot1xSupplicantStats' }
        @{ Cmd = 'Initialize-ArubaSWDot1xSupplicant' }
    ) {
        & $Cmd -port_id 21 -WhatIf -connection $StubConnection
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 0 -Exactly
    }
}

Describe 'Dot1x Port Security' -Tag 'Unit' {

    BeforeEach {
        $script:CapturedBody = $null
        $script:CapturedUri  = $null
        Mock -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest {
            if ($method -eq 'PUT') { $script:CapturedBody = $body; $script:CapturedUri = $uri; Get-Fixture -Resource dot1x-port_security -Name put-port21 }
            elseif ($uri -eq 'dot1x/port_security') { Get-Fixture -Resource dot1x-port_security -Name get-list }
            else { Get-Fixture -Resource dot1x-port_security -Name get-port21 }
        }
    }

    It 'Get ohne Port liefert die ausgepackte Liste' {
        @(Get-ArubaSWDot1xPortSecurity -connection $StubConnection).Count | Should -Be 2
    }

    It 'Get mit Port ruft dot1x/port_security/<id> auf' {
        $r = Get-ArubaSWDot1xPortSecurity -port_id 21 -connection $StubConnection
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 1 -Exactly -ParameterFilter { $uri -eq 'dot1x/port_security/21' }
        $r.controlled_direction | Should -Be 'DCD_BOTH'
    }

    It 'Set aendert nur die uebergebenen Felder und sendet Booleans' {
        $null = Set-ArubaSWDot1xPortSecurity -port_id 21 -allow_mbv:$false -Confirm:$false -connection $StubConnection
        $CapturedUri | Should -Be 'dot1x/port_security/21'
        $CapturedBody.allow_mbv | Should -BeFalse
        $CapturedBody.controlled_direction | Should -Be 'DCD_BOTH'
        $CapturedBody.allowed_mixed_users | Should -BeFalse
    }

    It 'Set lehnt DCD_OUT ab' {
        { Set-ArubaSWDot1xPortSecurity -port_id 21 -controlled_direction DCD_OUT -Confirm:$false -connection $StubConnection -ErrorAction Stop } |
            Should -Throw -ErrorId 'ParameterArgumentValidationError,Set-ArubaSWDot1xPortSecurity'
    }
}

Describe 'Dot1x Supplicant' -Tag 'Unit' {

    BeforeEach {
        $script:CapturedBody = $null
        $script:CapturedUri  = $null
        Mock -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest {
            if ($method -eq 'PUT') { $script:CapturedBody = $body; $script:CapturedUri = $uri; Get-Fixture -Resource dot1x-supplicant -Name put-port21 }
            elseif ($uri -eq 'dot1x/supplicant') { Get-Fixture -Resource dot1x-supplicant -Name get-list }
            else { Get-Fixture -Resource dot1x-supplicant -Name get-port21 }
        }
    }

    It 'Get ohne Port liefert die ausgepackte Liste' {
        @(Get-ArubaSWDot1xSupplicant -connection $StubConnection).Count | Should -Be 2
    }

    It 'Get mit Port ruft dot1x/supplicant/<id> auf' {
        $r = Get-ArubaSWDot1xSupplicant -port_id 21 -connection $StubConnection
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 1 -Exactly -ParameterFilter { $uri -eq 'dot1x/supplicant/21' }
        $r.is_supplicant_enabled | Should -BeFalse
    }

    It 'Set sendet ohne -password kein Kennwortfeld (der Switch liefert nur einen Platzhalter)' {
        $null = Set-ArubaSWDot1xSupplicant -port_id 21 -username host01 -auth_timeout 20 -Confirm:$false -connection $StubConnection
        $CapturedUri | Should -Be 'dot1x/supplicant/21'
        $CapturedBody.username | Should -Be 'host01'
        $CapturedBody.auth_timeout | Should -Be 20
        $CapturedBody.PSObject.Properties['password'] | Should -BeNullOrEmpty
        $CapturedBody.PSObject.Properties['uri'] | Should -BeNullOrEmpty
    }

    It 'Set sendet -password als Klartext-Feld (SecureString wird aufgeloest)' {
        $pw = ConvertTo-SecureString 'dummy-wert-fuer-test' -AsPlainText -Force
        $null = Set-ArubaSWDot1xSupplicant -port_id 21 -password $pw -Confirm:$false -connection $StubConnection
        $CapturedBody.password | Should -Be 'dummy-wert-fuer-test'
    }

    It 'Set verlangt -password als SecureString' {
        $p = (Get-Command Set-ArubaSWDot1xSupplicant).Parameters['password']
        $p.ParameterType | Should -Be ([securestring])
    }

    It 'Set macht keinen PUT bei -WhatIf' {
        Set-ArubaSWDot1xSupplicant -port_id 21 -username a -WhatIf -connection $StubConnection
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 0 -Exactly -ParameterFilter { $method -eq 'PUT' }
    }
}
