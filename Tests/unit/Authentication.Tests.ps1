#
# Copyright 2026, PowerArubaSW contributors
# SPDX-License-Identifier: Apache-2.0
#
# Unit-Tests fuer Authentication.ps1, MacAuthentication.ps1, Webauth.ps1, ManagementUser.ps1 und Transceiver.ps1 (Inkrement I39).
# Die Fixtures sind echte Antworten einer 2540 (YC.16.11.0010).

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

# Globale Ressourcen: Get ruft <uri> auf, Set liest zuerst und sendet das vollstaendige Objekt ohne uri.
Describe 'Globale Ressourcen (Get und Set)' -Tag 'Unit' -ForEach @(
    @{ Get = 'Get-ArubaSWAuthentication'; Set = 'Set-ArubaSWAuthentication'; Res = 'authentication'; Uri = 'authentication'; Field = 'is_privilege_mode_enabled'; Params = @{ is_privilege_mode_enabled = $true }; Expect = $true }
    @{ Get = 'Get-ArubaSWAuthorization'; Set = 'Set-ArubaSWAuthorization'; Res = 'authorization'; Uri = 'authorization'; Field = 'authorization_method'; Params = @{ authorization_method = 'AZM_RADIUS' }; Expect = 'AZM_RADIUS' }
    @{ Get = 'Get-ArubaSWMacAuthentication'; Set = 'Set-ArubaSWMacAuthentication'; Res = 'mac-authentication'; Uri = 'mac-authentication'; Field = 'unauthorized_vlan_id'; Params = @{ unauthorized_vlan_id = 0 }; Expect = 0 }
    @{ Get = 'Get-ArubaSWWebauth'; Set = 'Set-ArubaSWWebauth'; Res = 'webauth'; Uri = 'webauth'; Field = 'dhcp_lease'; Params = @{ dhcp_lease = 20 }; Expect = 20 }
    @{ Get = 'Get-ArubaSWAllowUnsupportedTransceiver'; Set = 'Set-ArubaSWAllowUnsupportedTransceiver'; Res = 'allow-unsupported-transceiver'; Uri = 'allow_unsupported_transceiver'; Field = 'is_allow_unsupported_transceiver_enabled'; Params = @{ is_allow_unsupported_transceiver_enabled = $true }; Expect = $true }
) {

    BeforeEach {
        $script:Fx = $Res
        $script:Body = $null
        $script:PutUri = $null
        Mock -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest {
            if ($method -eq 'PUT') { $script:Body = $body; $script:PutUri = $uri }
            Get-Fixture -Resource $script:Fx -Name get-item
        }
    }

    It '<Get> ruft GET <Uri> auf' {
        $r = & $Get -connection $StubConnection
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 1 -Exactly -ParameterFilter { $method -eq 'GET' -and $uri -eq $Uri }
        $r.PSObject.Properties[$Field] | Should -Not -BeNullOrEmpty
    }

    It '<Set> liest zuerst, sendet das vollstaendige Objekt ohne uri und aendert nur das Angegebene' {
        $null = & $Set @Params -Confirm:$false -connection $StubConnection
        $PutUri | Should -Be $Uri
        $Body.PSObject.Properties['uri'] | Should -BeNullOrEmpty
        $Body.$Field | Should -Be $Expect
        $cur = (Get-Fixture -Resource $Res -Name get-item).content | ConvertFrom-Json
        foreach ($p in $cur.PSObject.Properties) {
            if ($p.Name -ne 'uri' -and $p.Name -ne $Field) { $Body.PSObject.Properties[$p.Name] | Should -Not -BeNullOrEmpty }
        }
    }

    It '<Set> macht bei -WhatIf keinen PUT' {
        & $Set @Params -WhatIf -connection $StubConnection
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 0 -Exactly -ParameterFilter { $method -eq 'PUT' }
    }
}

Describe 'Set-ArubaSWAuthentication und Webauth: Typen' -Tag 'Unit' {

    BeforeEach {
        $script:Body = $null
        Mock -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest {
            if ($method -eq 'PUT') { $script:Body = $body }
            if ($uri -eq 'webauth') { Get-Fixture -Resource webauth -Name get-item } else { Get-Fixture -Resource authentication -Name get-item }
        }
    }

    It 'Schalter gehen als Boolean, -switch:$false schaltet aus' {
        $null = Set-ArubaSWAuthentication -is_privilege_mode_enabled:$false -Confirm:$false -connection $StubConnection
        $Body.is_privilege_mode_enabled | Should -BeFalse
        $Body.is_privilege_mode_enabled | Should -BeOfType [bool]
    }

    It 'Set-ArubaSWWebauth sendet Adressen als Objekte mit version und octets' {
        $null = Set-ArubaSWWebauth -dhcp_ip 192.168.1.0 -dhcp_ip_netmask 255.255.255.0 -Confirm:$false -connection $StubConnection
        $Body.dhcp_ip.version | Should -Be 'IAV_IP_V4'
        $Body.dhcp_ip.octets | Should -Be '192.168.1.0'
        $Body.dhcp_ip_netmask.octets | Should -Be '255.255.255.0'
    }

    It 'Set-ArubaSWWebauth laesst nicht genannte Felder unveraendert' {
        $null = Set-ArubaSWWebauth -access_denied_message hallo -Confirm:$false -connection $StubConnection
        $Body.access_denied_message | Should -Be 'hallo'
        $Body.dhcp_lease | Should -Be 10
        $Body.dhcp_ip.octets | Should -Be '192.168.0.0'
    }
}

# Verschachtelte Ressourcen
Describe 'Console, SSH und Accounting' -Tag 'Unit' {

    BeforeEach {
        $script:Fx = $null
        $script:Body = $null
        Mock -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest {
            if ($method -eq 'PUT') { $script:Body = $body }
            switch ($uri) {
                'authentication/console' { Get-Fixture -Resource authentication-console -Name get-item }
                'authentication/ssh' { Get-Fixture -Resource authentication-ssh -Name get-item }
                default { Get-Fixture -Resource accounting -Name get-item }
            }
        }
    }

    It 'Get-ArubaSWAuthenticationConsole liefert login und enable' {
        $r = Get-ArubaSWAuthenticationConsole -connection $StubConnection
        $r.auth_console_login.primary_method | Should -Be 'PAM_LOCAL'
        $r.auth_console_enable.secondary_method | Should -Be 'SAM_NONE'
    }

    It 'Set-ArubaSWAuthenticationConsole aendert nur die genannte Methode' {
        $null = Set-ArubaSWAuthenticationConsole -login_secondary_method SAM_LOCAL -Confirm:$false -connection $StubConnection
        $Body.auth_console_login.secondary_method | Should -Be 'SAM_LOCAL'
        $Body.auth_console_login.primary_method | Should -Be 'PAM_LOCAL'
        $Body.auth_console_enable.secondary_method | Should -Be 'SAM_NONE'
        $Body.PSObject.Properties['uri'] | Should -BeNullOrEmpty
    }

    It 'Set-ArubaSWAuthenticationSsh schaltet das Client-Zertifikat und laesst die Methoden' {
        $null = Set-ArubaSWAuthenticationSsh -is_client_certificate_enabled -Confirm:$false -connection $StubConnection
        $Body.is_client_certificate_enabled | Should -BeTrue
        $Body.auth_ssh_login.primary_method | Should -Be 'PAM_LOCAL'
        $Body.auth_ssh_enable.primary_method | Should -Be 'PAM_LOCAL'
    }

    It 'Set-ArubaSWAccounting setzt Gruppe, Intervall und Schalter' {
        $null = Set-ArubaSWAccounting -exec_accounting_method AME_RADIUS -exec_accounting_mode AMO_START_STOP -update_interval 5 -is_supress_null_user -Confirm:$false -connection $StubConnection
        $Body.accounting_exec.accounting_method | Should -Be 'AME_RADIUS'
        $Body.accounting_exec.accounting_mode | Should -Be 'AMO_START_STOP'
        $Body.accounting_system.accounting_method | Should -Be 'AME_NONE'
        $Body.update_interval | Should -Be 5
        $Body.is_supress_null_user | Should -BeTrue
        $Body.session_id | Should -Be 'ASI_UNIQUE'
    }

    It 'Set-ArubaSWAccounting hat Parameter fuer alle fuenf Gruppen' {
        $names = (Get-Command Set-ArubaSWAccounting).Parameters.Keys
        foreach ($g in 'exec', 'system', 'rest', 'network', 'commands') {
            $names | Should -Contain "${g}_accounting_method"
            $names | Should -Contain "${g}_accounting_mode"
            $names | Should -Contain "${g}_server_group"
        }
    }

    It 'macht bei -WhatIf keinen PUT' {
        Set-ArubaSWAccounting -update_interval 5 -WhatIf -connection $StubConnection
        Set-ArubaSWAuthenticationSsh -is_client_certificate_enabled -WhatIf -connection $StubConnection
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 0 -Exactly -ParameterFilter { $method -eq 'PUT' }
    }
}

# Ressourcen je Port
Describe 'Ressourcen je Port' -Tag 'Unit' -ForEach @(
    @{ Get = 'Get-ArubaSWMacAuthenticationPort'; Set = 'Set-ArubaSWMacAuthenticationPort'; Res = 'mac-authentication-port'; Path = 'mac-authentication/port'; Params = @{ quiet_period = 70; is_mac_authentication_enabled = $true }; Field = 'quiet_period'; Expect = 70 }
    @{ Get = 'Get-ArubaSWWebauthPort'; Set = 'Set-ArubaSWWebauthPort'; Res = 'webauth-port'; Path = 'webauth/port'; Params = @{ client_limit = 2; is_webauth_enabled = $true }; Field = 'client_limit'; Expect = 2 }
) {

    BeforeEach {
        $script:Fx = $Res
        $script:Body = $null
        $script:PutUri = $null
        Mock -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest {
            if ($method -eq 'PUT') { $script:Body = $body; $script:PutUri = $uri }
            if ($uri -match '/21$') { Get-Fixture -Resource $script:Fx -Name get-item } else { Get-Fixture -Resource $script:Fx -Name get-list }
        }
    }

    It '<Get> packt die Liste aus' {
        $r = @(& $Get -connection $StubConnection)
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 1 -Exactly -ParameterFilter { $method -eq 'GET' -and $uri -eq $Path }
        $r.Count | Should -Be 2
        $r[0].port_id | Should -Be '1'
    }

    It '<Get> liefert mit -port_id das einzelne Objekt' {
        $r = & $Get -port_id 21 -connection $StubConnection
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 1 -Exactly -ParameterFilter { $method -eq 'GET' -and $uri -eq "$Path/21" }
        $r.port_id | Should -Be '21'
    }

    It '<Set> sendet PUT auf <Path>/21 mit vollstaendigem Objekt' {
        $null = & $Set -port_id 21 @Params -Confirm:$false -connection $StubConnection
        $PutUri | Should -Be "$Path/21"
        $Body.$Field | Should -Be $Expect
        $Body.port_id | Should -Be '21'
        $Body.PSObject.Properties['uri'] | Should -BeNullOrEmpty
        $Body.logoff_period | Should -Be 300
    }

    It '<Set> nimmt port_id aus der Pipeline und macht bei -WhatIf keinen PUT' {
        [pscustomobject]@{ port_id = '21' } | & $Set @Params -WhatIf -connection $StubConnection
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 0 -Exactly -ParameterFilter { $method -eq 'PUT' }
    }
}

Describe 'Set-ArubaSWWebauthPort: Typen' -Tag 'Unit' {
    It 'Schalter als Boolean, URL als Text' {
        $script:Body = $null
        Mock -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest {
            if ($method -eq 'PUT') { $script:Body = $body }
            Get-Fixture -Resource webauth-port -Name get-item
        }
        $null = Set-ArubaSWWebauthPort -port_id 21 -ssl_login -client_moves:$false -redirect_url 'http://example.com/login' -Confirm:$false -connection $StubConnection
        $Body.ssl_login | Should -BeTrue
        $Body.client_moves | Should -BeFalse
        $Body.redirect_url | Should -Be 'http://example.com/login'
    }
}

Describe 'Verwaltungsbenutzer' -Tag 'Unit' {

    BeforeEach {
        $script:Body = $null
        $script:PutUri = $null
        Mock -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest {
            if ($method -in 'PUT', 'POST') { $script:Body = $body; $script:PutUri = $uri }
            if ($method -eq 'POST') { Get-Fixture -Resource management-user -Name post-item }
            elseif ($method -eq 'PUT') { Get-Fixture -Resource management-user -Name put-item }
            elseif ($uri -eq 'management-user') { Get-Fixture -Resource management-user -Name get-list }
            else { Get-Fixture -Resource management-user -Name get-item }
        }
        $script:Pw = ConvertTo-SecureString 'Test-Pw-12345' -AsPlainText -Force
    }

    It 'Get-ArubaSWManagementUser packt die Liste aus' {
        $r = @(Get-ArubaSWManagementUser -connection $StubConnection)
        $r.Count | Should -Be 2
        $r.type | Should -Contain 'UT_MANAGER'
        $r[0].password | Should -Be '******'
    }

    It 'Get-ArubaSWManagementUser -type holt GET management-user/UT_OPERATOR' {
        $r = Get-ArubaSWManagementUser -type UT_OPERATOR -connection $StubConnection
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 1 -Exactly -ParameterFilter { $method -eq 'GET' -and $uri -eq 'management-user/UT_OPERATOR' }
        $r.type | Should -Be 'UT_OPERATOR'
    }

    It 'Add-ArubaSWManagementUser sendet POST mit Klartext-Kennwort und password_type' {
        $r = Add-ArubaSWManagementUser -type UT_OPERATOR -name viewer -password $Pw -Confirm:$false -connection $StubConnection
        $PutUri | Should -Be 'management-user'
        $Body.type | Should -Be 'UT_OPERATOR'
        $Body.name | Should -Be 'viewer'
        $Body.password | Should -Be 'Test-Pw-12345'
        $Body.password_type | Should -Be 'PET_PLAIN_TEXT'
        $r.uri | Should -Be '/management-user/UT_OPERATOR'
    }

    It 'Set-ArubaSWManagementUser behaelt den Namen, wenn -name fehlt (PUT mit allen Feldern)' {
        $null = Set-ArubaSWManagementUser -type UT_OPERATOR -password $Pw -Confirm:$false -connection $StubConnection
        $PutUri | Should -Be 'management-user/UT_OPERATOR'
        $Body.name | Should -Be 'viewer'
        $Body.password_type | Should -Be 'PET_PLAIN_TEXT'
        $Body.password | Should -Be 'Test-Pw-12345'
    }

    It 'Set-ArubaSWManagementUser nimmt -name an' {
        $null = Set-ArubaSWManagementUser -type UT_OPERATOR -name neu -password $Pw -Confirm:$false -connection $StubConnection
        $Body.name | Should -Be 'neu'
    }

    It 'Remove-ArubaSWManagementUser sendet DELETE' {
        Remove-ArubaSWManagementUser -type UT_OPERATOR -Confirm:$false -connection $StubConnection
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 1 -Exactly -ParameterFilter { $method -eq 'DELETE' -and $uri -eq 'management-user/UT_OPERATOR' }
    }

    It 'prueft den Typ' {
        { Get-ArubaSWManagementUser -type UT_BOGUS -connection $StubConnection -ErrorAction Stop } | Should -Throw -ErrorId 'ParameterArgumentValidationError,Get-ArubaSWManagementUser'
    }

    It 'macht bei -WhatIf keinen Aufruf' {
        Add-ArubaSWManagementUser -type UT_OPERATOR -name x -password $Pw -WhatIf -connection $StubConnection
        Set-ArubaSWManagementUser -type UT_OPERATOR -name x -password $Pw -WhatIf -connection $StubConnection
        Remove-ArubaSWManagementUser -type UT_OPERATOR -WhatIf -connection $StubConnection
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 0 -Exactly -ParameterFilter { $method -in 'POST', 'PUT', 'DELETE' }
    }
}

Describe 'Transceiver, SmartRate und Portspiegelung' -Tag 'Unit' -ForEach @(
    @{ Get = 'Get-ArubaSWTransceiver'; Res = 'transceivers'; Uri = 'transceivers' }
    @{ Get = 'Get-ArubaSWSmartrate'; Res = 'smartrate'; Uri = 'smartrate/ports' }
    @{ Get = 'Get-ArubaSWPortMirror'; Res = 'port-mirror'; Uri = 'port-mirror' }
) {
    It '<Get> liefert bei leerer Liste nichts' {
        $script:Fx = $Res
        Mock -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest { Get-Fixture -Resource $script:Fx -Name get-empty }
        @(& $Get -connection $StubConnection).Count | Should -Be 0
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 1 -Exactly -ParameterFilter { $method -eq 'GET' -and $uri -eq $Uri }
    }
}

Describe 'Transceiver: Einzelabruf' -Tag 'Unit' {
    It 'Get-ArubaSWTransceiver -serial_number und Diagnostics rufen die Unterpfade auf' {
        Mock -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest { [pscustomobject]@{ content = '{"serial_number":"X1"}' } }
        $null = Get-ArubaSWTransceiver -serial_number X1 -connection $StubConnection
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 1 -Exactly -ParameterFilter { $uri -eq 'transceivers/X1' }
        $null = Get-ArubaSWTransceiverDiagnostics -serial_number X1 -connection $StubConnection
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 1 -Exactly -ParameterFilter { $uri -eq 'transceivers/X1/diagnostics' }
    }
}
