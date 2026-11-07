#
# Copyright 2026, PowerArubaSW contributors
# SPDX-License-Identifier: Apache-2.0
#
# Unit-Tests fuer Public/FileTransfer.ps1 (Inkrement I41). Die Fixture ist eine echte Antwort einer 2540 (YC.16.11.0010).

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

Describe 'Start-ArubaSWFileTransfer' -Tag 'Unit' {

    BeforeEach {
        $script:Body = $null
        $script:PostUri = $null
        Mock -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest {
            $script:Body = $body
            $script:PostUri = $uri
            Get-Fixture -Resource file-transfer -Name post-upload
        }
    }

    It 'sendet POST file-transfer mit url, file_type und action' {
        $r = Start-ArubaSWFileTransfer -action FTA_UPLOAD -file_type FTT_CONFIG -url http://198.51.100.5:8080/cfg.txt -Confirm:$false -connection $StubConnection
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 1 -Exactly -ParameterFilter { $method -eq 'POST' }
        $PostUri | Should -Be 'file-transfer'
        $Body.url | Should -Be 'http://198.51.100.5:8080/cfg.txt'
        $Body.file_type | Should -Be 'FTT_CONFIG'
        $Body.action | Should -Be 'FTA_UPLOAD'
        $r.message | Should -Be 'File transfer initiated'
    }

    It 'nimmt <Type> als file_type an' -ForEach @(
        @{ Type = 'FTT_CONFIG' }
        @{ Type = 'FTT_FIRMWARE' }
        @{ Type = 'FTT_SHOW_TECH' }
    ) {
        $null = Start-ArubaSWFileTransfer -action FTA_UPLOAD -file_type $Type -url http://198.51.100.5/x -Confirm:$false -connection $StubConnection
        $Body.file_type | Should -Be $Type
    }

    It 'lehnt unbekannte action und file_type ab' {
        { Start-ArubaSWFileTransfer -action FTA_BOGUS -file_type FTT_CONFIG -url http://198.51.100.5/x -Confirm:$false -connection $StubConnection -ErrorAction Stop } |
            Should -Throw -ErrorId 'ParameterArgumentValidationError,Start-ArubaSWFileTransfer'
        { Start-ArubaSWFileTransfer -action FTA_UPLOAD -file_type FTT_RUNNING_CONFIG -url http://198.51.100.5/x -Confirm:$false -connection $StubConnection -ErrorAction Stop } |
            Should -Throw -ErrorId 'ParameterArgumentValidationError,Start-ArubaSWFileTransfer'
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 0 -Exactly
    }

    It 'macht bei -WhatIf keinen Aufruf' {
        Start-ArubaSWFileTransfer -action FTA_DOWNLOAD -file_type FTT_FIRMWARE -url http://198.51.100.5/x.swi -WhatIf -connection $StubConnection
        Should -Invoke -ModuleName PowerArubaSW Invoke-ArubaSWWebRequest -Times 0 -Exactly
    }
}
