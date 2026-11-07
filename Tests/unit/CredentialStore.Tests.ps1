#
# Copyright 2026, PowerArubaSW contributors
# SPDX-License-Identifier: Apache-2.0
#
# Unit-Tests fuer den optionalen Credential Store (Inkrement I26):
# Private/CredentialStore.ps1 und Public/Credential.ps1, Einbindung in Connect-ArubaSW.
# Die Aufloesungsreihenfolge laeuft gegen Mocks; ein Round-Trip gegen den echten Windows
# Credential Manager nutzt ein eindeutiges Test-Ziel und raeumt es wieder auf (nur Windows).

# PSSA-Ausnahme: Dummy-Passwort fuer die Tests, nie ein echtes Geheimnis.
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingConvertToSecureStringWithPlainText", "")]
Param()

BeforeAll {
    $script:UnitDir    = Split-Path -Parent $PSCommandPath
    $script:TestsRoot  = Split-Path -Parent $UnitDir
    $script:RepoRoot   = Split-Path -Parent $TestsRoot
    $script:Manifest   = Join-Path (Join-Path $RepoRoot 'PowerArubaSW') 'PowerArubaSW.psd1'

    $loaded = Get-Module -Name 'PowerArubaSW' -ErrorAction SilentlyContinue
    if ($loaded) { Remove-Module $loaded -Force }
    Import-Module $Manifest -Force

    $script:Secure = ConvertTo-SecureString 'dummy-pw' -AsPlainText -Force
    $script:StoredCred = [pscredential]::new('stored-user', $script:Secure)
    $script:IsWin = [System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT
}

Describe 'Get-ArubaSWDefaultCredentialTarget' -Tag 'Unit' {

    It 'bildet PowerArubaSW_<server>' {
        InModuleScope PowerArubaSW { Get-ArubaSWDefaultCredentialTarget -Server ' 192.0.2.1 ' } |
            Should -BeExactly 'PowerArubaSW_192.0.2.1'
    }
}

Describe 'Resolve-ArubaSWCredential - Reihenfolge' -Tag 'Unit' {

    BeforeEach {
        Mock -ModuleName PowerArubaSW Test-ArubaSWCredentialStore { $true }
        Mock -ModuleName PowerArubaSW Get-ArubaSWStoredCredential { $StoredCred }
        Mock -ModuleName PowerArubaSW Get-Credential { [pscredential]::new('prompt-user', $Secure) }
    }

    It '-Username/-Password gewinnen und beruehren Store und Prompt nicht' {
        $r = InModuleScope PowerArubaSW -Parameters @{ S = $script:Secure } {
            param($S) Resolve-ArubaSWCredential -Server 'sw1' -Username 'u1' -Password $S
        }
        $r.UserName | Should -Be 'u1'
        Should -Invoke -ModuleName PowerArubaSW Get-ArubaSWStoredCredential -Times 0 -Exactly
        Should -Invoke -ModuleName PowerArubaSW Get-Credential -Times 0 -Exactly
    }

    It '-Credentials werden unveraendert durchgereicht' {
        $given = [pscredential]::new('given-user', $script:Secure)
        $r = InModuleScope PowerArubaSW -Parameters @{ C = $given } {
            param($C) Resolve-ArubaSWCredential -Server 'sw1' -Credentials $C
        }
        $r.UserName | Should -Be 'given-user'
        Should -Invoke -ModuleName PowerArubaSW Get-ArubaSWStoredCredential -Times 0 -Exactly
    }

    It '-CredentialTarget liest genau dieses Ziel' {
        $r = InModuleScope PowerArubaSW { Resolve-ArubaSWCredential -Server 'sw1' -CredentialTarget 'SwitchLab' }
        $r.UserName | Should -Be 'stored-user'
        Should -Invoke -ModuleName PowerArubaSW Get-ArubaSWStoredCredential -Times 1 -Exactly `
            -ParameterFilter { $Target -eq 'SwitchLab' }
        Should -Invoke -ModuleName PowerArubaSW Get-Credential -Times 0 -Exactly
    }

    It '-CredentialTarget ohne Eintrag wirft, ohne zu fragen' {
        Mock -ModuleName PowerArubaSW Get-ArubaSWStoredCredential { $null }
        { InModuleScope PowerArubaSW { Resolve-ArubaSWCredential -Server 'sw1' -CredentialTarget 'Fehlt' } } |
            Should -Throw -ExpectedMessage "*'Fehlt' not found*"
        Should -Invoke -ModuleName PowerArubaSW Get-Credential -Times 0 -Exactly
    }

    It '-CredentialTarget ohne Credential Manager wirft' {
        Mock -ModuleName PowerArubaSW Test-ArubaSWCredentialStore { $false }
        { InModuleScope PowerArubaSW { Resolve-ArubaSWCredential -Server 'sw1' -CredentialTarget 'X' } } |
            Should -Throw -ExpectedMessage '*needs the Windows Credential Manager*'
    }

    It 'ohne Angaben: Default-Ziel PowerArubaSW_<server> wird gefunden, kein Prompt' {
        $r = InModuleScope PowerArubaSW { Resolve-ArubaSWCredential -Server 'sw1' }
        $r.UserName | Should -Be 'stored-user'
        Should -Invoke -ModuleName PowerArubaSW Get-ArubaSWStoredCredential -Times 1 -Exactly `
            -ParameterFilter { $Target -eq 'PowerArubaSW_sw1' }
        Should -Invoke -ModuleName PowerArubaSW Get-Credential -Times 0 -Exactly
    }

    It 'ohne Angaben und ohne Eintrag: interaktiver Prompt' {
        Mock -ModuleName PowerArubaSW Get-ArubaSWStoredCredential { $null }
        $r = InModuleScope PowerArubaSW { Resolve-ArubaSWCredential -Server 'sw1' }
        $r.UserName | Should -Be 'prompt-user'
        Should -Invoke -ModuleName PowerArubaSW Get-Credential -Times 1 -Exactly
    }

    It 'ohne Angaben auf einer Plattform ohne Store: Prompt, kein Store-Zugriff' {
        Mock -ModuleName PowerArubaSW Test-ArubaSWCredentialStore { $false }
        $r = InModuleScope PowerArubaSW { Resolve-ArubaSWCredential -Server 'sw1' }
        $r.UserName | Should -Be 'prompt-user'
        Should -Invoke -ModuleName PowerArubaSW Get-ArubaSWStoredCredential -Times 0 -Exactly
    }
}

Describe 'Save-ArubaSWCredential / Remove-ArubaSWCredential' -Tag 'Unit' {

    BeforeEach {
        Mock -ModuleName PowerArubaSW Set-ArubaSWStoredCredential { }
        Mock -ModuleName PowerArubaSW Remove-ArubaSWStoredCredential { $true }
    }

    It 'Save -Server speichert unter PowerArubaSW_<server>' {
        Save-ArubaSWCredential -Server '192.0.2.1' -Credentials $StoredCred -Confirm:$false
        Should -Invoke -ModuleName PowerArubaSW Set-ArubaSWStoredCredential -Times 1 -Exactly `
            -ParameterFilter { $Target -eq 'PowerArubaSW_192.0.2.1' -and $Credential.UserName -eq 'stored-user' }
    }

    It 'Save -CredentialTarget speichert unter dem genannten Namen' {
        Save-ArubaSWCredential -CredentialTarget 'SwitchLab' -Credentials $StoredCred -Confirm:$false
        Should -Invoke -ModuleName PowerArubaSW Set-ArubaSWStoredCredential -Times 1 -Exactly `
            -ParameterFilter { $Target -eq 'SwitchLab' }
    }

    It 'Save fragt per Get-Credential, wenn keine -Credentials uebergeben werden' {
        Mock -ModuleName PowerArubaSW Get-Credential { [pscredential]::new('asked-user', $Secure) }
        Save-ArubaSWCredential -Server 'sw1' -Confirm:$false
        Should -Invoke -ModuleName PowerArubaSW Get-Credential -Times 1 -Exactly
        Should -Invoke -ModuleName PowerArubaSW Set-ArubaSWStoredCredential -Times 1 -Exactly `
            -ParameterFilter { $Credential.UserName -eq 'asked-user' }
    }

    It 'Save schreibt bei -WhatIf nichts' {
        Save-ArubaSWCredential -Server 'sw1' -Credentials $StoredCred -WhatIf
        Should -Invoke -ModuleName PowerArubaSW Set-ArubaSWStoredCredential -Times 0 -Exactly
    }

    It 'Remove loescht das Default-Ziel' {
        Remove-ArubaSWCredential -Server '192.0.2.1' -Confirm:$false
        Should -Invoke -ModuleName PowerArubaSW Remove-ArubaSWStoredCredential -Times 1 -Exactly `
            -ParameterFilter { $Target -eq 'PowerArubaSW_192.0.2.1' }
    }

    It 'Remove warnt, wenn das Ziel nicht existiert' {
        Mock -ModuleName PowerArubaSW Remove-ArubaSWStoredCredential { $false }
        $w = $null
        Remove-ArubaSWCredential -CredentialTarget 'Fehlt' -Confirm:$false -WarningVariable w -WarningAction SilentlyContinue
        @($w).Count | Should -Be 1
        "$($w[0])" | Should -BeLike "*'Fehlt' does not exist*"
    }

    It 'Remove loescht bei -WhatIf nichts' {
        Remove-ArubaSWCredential -Server 'sw1' -WhatIf
        Should -Invoke -ModuleName PowerArubaSW Remove-ArubaSWStoredCredential -Times 0 -Exactly
    }
}

Describe 'Credential Manager Round-Trip (nur Windows)' -Tag 'Unit' {

    It 'schreibt, liest, ueberschreibt und loescht ein eindeutiges Test-Ziel' -Skip:(-not ([System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT)) {
        $target = 'PowerArubaSW_UnitTest_' + [guid]::NewGuid().ToString('N')
        try {
            InModuleScope PowerArubaSW -Parameters @{ T = $target; C = $script:StoredCred } {
                param($T, $C)
                Set-ArubaSWStoredCredential -Target $T -Credential $C -Confirm:$false
            }
            $read = InModuleScope PowerArubaSW -Parameters @{ T = $target } { param($T) Get-ArubaSWStoredCredential -Target $T }
            $read.UserName | Should -Be 'stored-user'
            $read.GetNetworkCredential().Password | Should -BeExactly 'dummy-pw'

            $second = [pscredential]::new('second-user', (ConvertTo-SecureString 'other-pw' -AsPlainText -Force))
            InModuleScope PowerArubaSW -Parameters @{ T = $target; C = $second } {
                param($T, $C)
                Set-ArubaSWStoredCredential -Target $T -Credential $C -Confirm:$false
            }
            $again = InModuleScope PowerArubaSW -Parameters @{ T = $target } { param($T) Get-ArubaSWStoredCredential -Target $T }
            $again.UserName | Should -Be 'second-user'
        }
        finally {
            $removed = InModuleScope PowerArubaSW -Parameters @{ T = $target } { param($T) Remove-ArubaSWStoredCredential -Target $T -Confirm:$false }
        }
        $removed | Should -BeTrue
        InModuleScope PowerArubaSW -Parameters @{ T = $target } { param($T) Get-ArubaSWStoredCredential -Target $T } | Should -BeNullOrEmpty
        InModuleScope PowerArubaSW -Parameters @{ T = $target } { param($T) Remove-ArubaSWStoredCredential -Target $T -Confirm:$false } | Should -BeFalse
    }
}

Describe 'Credential Store - Grenzfaelle (I30, Mutationspruefung, nur Windows)' -Tag 'Unit' {

    BeforeAll {
        $script:WinOnly = [System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT
    }

    It 'Get-ArubaSWStoredCredential ruft ohne Credential Manager nichts Natives auf und liefert $null' {
        Mock -ModuleName PowerArubaSW Test-ArubaSWCredentialStore { $false }
        Mock -ModuleName PowerArubaSW Initialize-ArubaSWCredentialNative { }
        $r = InModuleScope PowerArubaSW { Get-ArubaSWStoredCredential -Target 'irgendein-ziel' }
        $r | Should -BeNullOrEmpty
        Should -Invoke -ModuleName PowerArubaSW Initialize-ArubaSWCredentialNative -Times 0 -Exactly
    }

    It 'ein nicht vorhandenes Ziel liefert $null ohne Fehlerpfad (kein "not readable" im Verbose-Strom)' -Skip:(-not ([System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT)) {
        $target = 'PowerArubaSW_UnitTest_fehlt_' + [guid]::NewGuid().ToString('N')
        $verbose = InModuleScope PowerArubaSW -Parameters @{ T = $target } { param($T) Get-ArubaSWStoredCredential -Target $T -Verbose 4>&1 }
        @($verbose | Where-Object { $_ -is [System.Management.Automation.VerboseRecord] }).Count | Should -Be 0
        @($verbose | Where-Object { $_ -is [pscredential] }).Count | Should -Be 0
    }

    It 'Passwortlaenge: 1280 Zeichen gehen, 1281 werden abgelehnt' -Skip:(-not ([System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT)) {
        $target = 'PowerArubaSW_UnitTest_' + [guid]::NewGuid().ToString('N')
        $lang = [pscredential]::new('long-user', (ConvertTo-SecureString ('x' * 1280) -AsPlainText -Force))
        $zulang = [pscredential]::new('long-user', (ConvertTo-SecureString ('x' * 1281) -AsPlainText -Force))
        try {
            InModuleScope PowerArubaSW -Parameters @{ T = $target; C = $lang } { param($T, $C) Set-ArubaSWStoredCredential -Target $T -Credential $C -Confirm:$false }
            $read = InModuleScope PowerArubaSW -Parameters @{ T = $target } { param($T) Get-ArubaSWStoredCredential -Target $T }
            $read.GetNetworkCredential().Password.Length | Should -Be 1280
            { InModuleScope PowerArubaSW -Parameters @{ T = $target; C = $zulang } { param($T, $C) Set-ArubaSWStoredCredential -Target $T -Credential $C -Confirm:$false } } |
                Should -Throw -ExpectedMessage '*Password too long*'
        }
        finally {
            $null = InModuleScope PowerArubaSW -Parameters @{ T = $target } { param($T) Remove-ArubaSWStoredCredential -Target $T -Confirm:$false }
        }
    }

    It 'der Eintrag ist LOCAL_MACHINE-persistent und das gelesene Passwort ist schreibgeschuetzt' -Skip:(-not ([System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT)) {
        $target = 'PowerArubaSW_UnitTest_' + [guid]::NewGuid().ToString('N')
        $cred = [pscredential]::new('persist-user', (ConvertTo-SecureString 'persist-pw' -AsPlainText -Force))
        try {
            InModuleScope PowerArubaSW -Parameters @{ T = $target; C = $cred } { param($T, $C) Set-ArubaSWStoredCredential -Target $T -Credential $C -Confirm:$false }
            $raw = InModuleScope PowerArubaSW -Parameters @{ T = $target } { param($T) [PowerArubaSW.CredentialNative]::Read($T) }
            [uint32]$raw[2] | Should -Be 2 -Because 'CRED_PERSIST_LOCAL_MACHINE'
            $raw[1].IsReadOnly() | Should -BeTrue
        }
        finally {
            $null = InModuleScope PowerArubaSW -Parameters @{ T = $target } { param($T) Remove-ArubaSWStoredCredential -Target $T -Confirm:$false }
        }
    }

    It 'Resolve meldet das benutzte Default-Ziel im Verbose-Strom' {
        Mock -ModuleName PowerArubaSW Test-ArubaSWCredentialStore { $true }
        Mock -ModuleName PowerArubaSW Get-ArubaSWStoredCredential { [pscredential]::new('v-user', (ConvertTo-SecureString 'v-pw' -AsPlainText -Force)) }
        $out = InModuleScope PowerArubaSW { Resolve-ArubaSWCredential -Server 'sw-verbose' -Verbose 4>&1 }
        (@($out | Where-Object { $_ -is [System.Management.Automation.VerboseRecord] }).Message -join ' ') | Should -Match "Using stored credential 'PowerArubaSW_sw-verbose'"
    }
}
