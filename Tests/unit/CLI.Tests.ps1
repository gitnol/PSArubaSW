#
# Copyright 2026, PowerArubaSW contributors
# SPDX-License-Identifier: Apache-2.0
#
# Unit-Tests für Public/CLI.ps1 — sichert Inkrement I9 (Newline-Validierung in
# Get-ArubaSWCli + Security-Notes in der Comment-based Help) als Regression.

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

Describe 'Get-ArubaSWCli — Newline-Validierung (I9)' -Tag 'Unit' {

    It 'lehnt -cmd mit eingebettetem `n ab (LF)' {
        { Get-ArubaSWCli -cmd "show version`nshow tech" -connection $StubConnection -ErrorAction Stop } |
            Should -Throw -ExpectedMessage '*multi-command injection*'
    }

    It 'lehnt -cmd mit eingebettetem `r`n ab (CRLF)' {
        { Get-ArubaSWCli -cmd "show version`r`nshow tech" -connection $StubConnection -ErrorAction Stop } |
            Should -Throw -ExpectedMessage '*multi-command injection*'
    }

    It 'akzeptiert ein normales Single-Line-Kommando' {
        # Mock damit der Test nicht ins Netz geht; nur die Validierung soll bestätigt werden.
        Mock -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest {
            '{"cmd":"show version","status":"CCS_SUCCESS","result_base64_encoded":"dGVzdA=="}'
        }
        { Get-ArubaSWCli -cmd 'show version' -connection $StubConnection } | Should -Not -Throw
    }
}

Describe 'Get-ArubaSWCli — Aufruf-Pfad gegen gemockten Transport' -Tag 'Unit' {

    BeforeEach {
        $script:CapturedBody = $null
        $script:CapturedUri  = $null
        $script:CapturedMethod = $null
        Mock -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest {
            $script:CapturedBody = $body
            $script:CapturedUri  = $uri
            $script:CapturedMethod = $method
            # "dGVzdC1vdXRwdXQ=" ist Base64 von "test-output"
            '{"cmd":"show version","status":"CCS_SUCCESS","result_base64_encoded":"dGVzdC1vdXRwdXQ="}'
        }
    }

    It 'POSTet zu /cli mit cmd im Body' {
        $null = Get-ArubaSWCli -cmd 'show version' -connection $StubConnection
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 1 -Exactly `
            -ParameterFilter { $method -eq 'POST' -and $uri -eq 'cli' }
        $CapturedBody.cmd | Should -Be 'show version'
    }

    It 'dekodiert Base64-Result und legt result-Feld am Rückgabeobjekt an' {
        $r = Get-ArubaSWCli -cmd 'show version' -connection $StubConnection
        $r.result | Should -Be 'test-output'
    }

    It '-display_result liefert nur den dekodierten String zurück' {
        $r = Get-ArubaSWCli -cmd 'show version' -display_result -connection $StubConnection
        $r | Should -Be 'test-output'
    }
}

Describe 'Send-ArubaSWCliBatch — Aufruf-Pfad gegen gemockten Transport' -Tag 'Unit' {

    BeforeEach {
        $script:CapturedBody = $null
        Mock -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest {
            $script:CapturedBody = $body
            '{"status":"CCS_SUCCESS"}'
        }
    }

    It 'POSTet zu /cli_batch mit Base64-kodiertem Body' {
        $null = Send-ArubaSWCliBatch -command 'interface 4','enable' -connection $StubConnection
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 1 -Exactly `
            -ParameterFilter { $method -eq 'POST' -and $uri -eq 'cli_batch' }
        # cli_batch_base64_encoded ist gesetzt; nach Decode steht "interface 4\nenable\n" drin
        $decoded = [System.Text.Encoding]::UTF8.GetString(
            [Convert]::FromBase64String($CapturedBody.cli_batch_base64_encoded))
        $decoded | Should -Match 'interface 4'
        $decoded | Should -Match 'enable'
    }
}

Describe 'Get-ArubaSWCli / Send-ArubaSWCliBatch — Security-Notes in Help (I9)' -Tag 'Unit' {

    It 'Get-ArubaSWCli Comment-based Help enthält den Sicherheitshinweis' {
        $help = Get-Help Get-ArubaSWCli -Full | Out-String
        $help | Should -Match 'SECURITY \(I9'
        $help | Should -Match 'multi-command injection|trusted input'
    }

    It 'Send-ArubaSWCliBatch Comment-based Help enthält den Sicherheitshinweis' {
        $help = Get-Help Send-ArubaSWCliBatch -Full | Out-String
        $help | Should -Match 'SECURITY \(I9'
        $help | Should -Match 'CLI-Passthrough\.md|trusted'
    }
}
