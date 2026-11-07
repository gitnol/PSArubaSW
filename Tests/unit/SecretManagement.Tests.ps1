#
# Copyright 2026, PowerArubaSW contributors
# SPDX-License-Identifier: Apache-2.0
#
# Unit-Tests fuer die optionale SecretManagement-Anbindung (Inkrement I34): Get-ArubaSWSecretCredential, -SecretName/-Vault in
# Resolve-ArubaSWCredential und Connect-ArubaSW. Das Modul Microsoft.PowerShell.SecretManagement ist keine Abhaengigkeit und wird
# nicht installiert: Get-Secret ist hier eine Test-Funktion im Modul-Scope, gemockt wie der Transport.

# PSSA-Ausnahme: Dummy-Passwort fuer die Tests, nie ein echtes Geheimnis.
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingConvertToSecureStringWithPlainText", "")]
Param()

BeforeAll {
    $script:UnitDir  = Split-Path -Parent $PSCommandPath
    $script:RepoRoot = Split-Path -Parent (Split-Path -Parent $UnitDir)
    $loaded = Get-Module -Name 'PowerArubaSW' -ErrorAction SilentlyContinue
    if ($loaded) { Remove-Module $loaded -Force }
    Import-Module (Join-Path $RepoRoot 'PowerArubaSW\PowerArubaSW.psd1') -Force

    $script:Secure = ConvertTo-SecureString 'vault-pw' -AsPlainText -Force
    $script:VaultCred = [pscredential]::new('vault-user', $script:Secure)
    # Get-Secret gibt es nur mit SecretManagement; fuer den Test eine Funktion im Modul-Scope, damit Mock sie findet.
    & (Get-Module PowerArubaSW) { function script:Get-Secret { param($Name, $Vault, $ErrorAction) $null = $Name, $Vault, $ErrorAction } }
}

Describe 'Get-ArubaSWSecretCredential' -Tag 'Unit' {

    BeforeEach {
        Mock -ModuleName PowerArubaSW Get-Secret { $script:VaultCred }
    }

    It 'liefert ein PSCredential-Secret unveraendert und fragt genau diesen Namen ab' {
        $r = InModuleScope PowerArubaSW { Get-ArubaSWSecretCredential -SecretName 'SwitchLab' }
        $r.UserName | Should -BeExactly 'vault-user'
        Should -Invoke -ModuleName PowerArubaSW Get-Secret -Times 1 -Exactly -ParameterFilter { $Name -eq 'SwitchLab' -and -not $PSBoundParameters.ContainsKey('Vault') }
    }

    It '-Vault wird nur mitgegeben, wenn er genannt ist' {
        $null = InModuleScope PowerArubaSW { Get-ArubaSWSecretCredential -SecretName 'SwitchLab' -Vault 'LabVault' }
        Should -Invoke -ModuleName PowerArubaSW Get-Secret -Times 1 -Exactly -ParameterFilter { $Vault -eq 'LabVault' }
    }

    It 'SecureString-Secret mit -Username wird zum PSCredential' {
        Mock -ModuleName PowerArubaSW Get-Secret { $script:Secure }
        $r = InModuleScope PowerArubaSW { Get-ArubaSWSecretCredential -SecretName 'PwOnly' -Username 'manager' }
        $r.UserName | Should -BeExactly 'manager'
        $r.GetNetworkCredential().Password | Should -BeExactly 'vault-pw'
    }

    It 'SecureString-Secret ohne -Username wirft mit Hinweis' {
        Mock -ModuleName PowerArubaSW Get-Secret { $script:Secure }
        { InModuleScope PowerArubaSW { Get-ArubaSWSecretCredential -SecretName 'PwOnly' } } |
            Should -Throw -ExpectedMessage "*SecureString: pass -Username*"
    }

    It 'ein Secret anderen Typs (Zeichenkette) wird abgelehnt und der Typ genannt' {
        Mock -ModuleName PowerArubaSW Get-Secret { 'Klartext' }
        { InModuleScope PowerArubaSW { Get-ArubaSWSecretCredential -SecretName 'Text' } } |
            Should -Throw -ExpectedMessage '*type String; expected PSCredential or SecureString*'
    }

    It 'ein leeres Ergebnis wirft "not found"' {
        Mock -ModuleName PowerArubaSW Get-Secret { $null }
        { InModuleScope PowerArubaSW { Get-ArubaSWSecretCredential -SecretName 'Leer' } } |
            Should -Throw -ExpectedMessage "*'Leer' not found*"
    }

    It 'ohne das Modul SecretManagement (Get-Secret fehlt) wirft mit Installationshinweis' {
        Mock -ModuleName PowerArubaSW Get-Command { $null } -ParameterFilter { $Name -eq 'Get-Secret' }
        { InModuleScope PowerArubaSW { Get-ArubaSWSecretCredential -SecretName 'X' } } |
            Should -Throw -ExpectedMessage '*Microsoft.PowerShell.SecretManagement*'
        Should -Invoke -ModuleName PowerArubaSW Get-Secret -Times 0 -Exactly
    }
}

Describe 'Resolve-ArubaSWCredential mit -SecretName - Reihenfolge' -Tag 'Unit' {

    BeforeEach {
        Mock -ModuleName PowerArubaSW Get-Secret { $script:VaultCred }
        Mock -ModuleName PowerArubaSW Test-ArubaSWCredentialStore { $true }
        Mock -ModuleName PowerArubaSW Get-ArubaSWStoredCredential { [pscredential]::new('store-user', $script:Secure) }
        Mock -ModuleName PowerArubaSW Get-Credential { throw 'Rueckfrage im Test gesperrt' }
    }

    It '-SecretName gewinnt gegen das Default-Ziel des Credential Managers' {
        $r = InModuleScope PowerArubaSW { Resolve-ArubaSWCredential -Server 'sw1' -SecretName 'SwitchLab' }
        $r.UserName | Should -BeExactly 'vault-user'
        Should -Invoke -ModuleName PowerArubaSW Get-ArubaSWStoredCredential -Times 0 -Exactly
        Should -Invoke -ModuleName PowerArubaSW Get-Credential -Times 0 -Exactly
    }

    It '-Credentials, -Password und -CredentialTarget gehen vor -SecretName' {
        $given = [pscredential]::new('given-user', $script:Secure)
        $r1 = InModuleScope PowerArubaSW -Parameters @{ C = $given } { param($C) Resolve-ArubaSWCredential -Server 'sw1' -Credentials $C -SecretName 'S' }
        $r1.UserName | Should -BeExactly 'given-user'
        $r2 = InModuleScope PowerArubaSW -Parameters @{ P = $script:Secure } { param($P) Resolve-ArubaSWCredential -Server 'sw1' -Username 'pw-user' -Password $P -SecretName 'S' }
        $r2.UserName | Should -BeExactly 'pw-user'
        $r3 = InModuleScope PowerArubaSW { Resolve-ArubaSWCredential -Server 'sw1' -CredentialTarget 'T' -SecretName 'S' }
        $r3.UserName | Should -BeExactly 'store-user'
        Should -Invoke -ModuleName PowerArubaSW Get-Secret -Times 0 -Exactly
    }

    It '-Vault und -Username erreichen Get-ArubaSWSecretCredential' {
        Mock -ModuleName PowerArubaSW Get-Secret { $script:Secure }
        $r = InModuleScope PowerArubaSW { Resolve-ArubaSWCredential -Server 'sw1' -SecretName 'PwOnly' -Vault 'LabVault' -Username 'manager' }
        $r.UserName | Should -BeExactly 'manager'
        Should -Invoke -ModuleName PowerArubaSW Get-Secret -Times 1 -Exactly -ParameterFilter { $Vault -eq 'LabVault' -and $Name -eq 'PwOnly' }
    }
}

Describe 'Connect-ArubaSW -SecretName' -Tag 'Unit' {

    BeforeEach {
        $script:LoginBody = $null
        Mock -ModuleName PowerArubaSW Get-Secret { $script:VaultCred }
        Mock -ModuleName PowerArubaSW Invoke-WebRequest {
            param($Body, $SessionVariable)
            $script:LoginBody = $Body
            $ws = [Microsoft.PowerShell.Commands.WebRequestSession]::new()
            & (Get-Module PowerArubaSW) { param($n, $v) Set-Variable -Name $n -Value $v -Scope Script } $SessionVariable $ws
            [pscustomobject]@{ content = '{"cookie":"sessionId=abc123"}' }
        }
        Mock -ModuleName PowerArubaSW Get-ArubaSWRestversion { [pscustomobject]@{ version = @('v3.0', 'v8.0') } }
        Mock -ModuleName PowerArubaSW Get-ArubaSWSystemStatusSwitch { [pscustomobject]@{ switch_type = 'ST_STANDALONE'; product_number = 'J1'; product_name = 'X' } }
        Mock -ModuleName PowerArubaSW Get-ArubaSWSystem { [pscustomobject]@{ name = 'sw1' } }
        Mock -ModuleName PowerArubaSW Test-ArubaSWCredentialStore { $true }
        Mock -ModuleName PowerArubaSW Get-ArubaSWStoredCredential { $null }
        Mock -ModuleName PowerArubaSW Get-Credential { throw 'Rueckfrage im Test gesperrt' }
    }

    AfterEach {
        & (Get-Module PowerArubaSW) { Remove-Variable -Name arubasw -Scope Script -ErrorAction SilentlyContinue }
    }

    It 'meldet sich mit den Zugangsdaten aus dem Vault an, ohne zu fragen' {
        $null = Connect-ArubaSW -Server '198.51.100.1' -SecretName 'SwitchLab' -Vault 'LabVault' -DefaultConnection:$false
        $body = $script:LoginBody | ConvertFrom-Json
        $body.userName | Should -BeExactly 'vault-user'
        $body.password | Should -BeExactly 'vault-pw'
        Should -Invoke -ModuleName PowerArubaSW Get-Secret -Times 1 -Exactly -ParameterFilter { $Name -eq 'SwitchLab' -and $Vault -eq 'LabVault' }
        Should -Invoke -ModuleName PowerArubaSW Get-Credential -Times 0 -Exactly
    }
}
