#
# Copyright 2026, PowerArubaSW contributors
# SPDX-License-Identifier: Apache-2.0
#
# Zugangsdaten fuer die Integrationstests (Inkrement I28). Reihenfolge:
#   1. Credential Store   (Windows Credential Manager, Ziel PowerArubaSW_<server>,
#                          angelegt mit Save-ArubaSWCredential -Server <server>)
#   2. Umgebungsvariable  ARUBASW_TEST_PASSWORD (z. B. CI, Linux/macOS)
#   3. $password in Tests/credential.ps1 (Klartext, nur noch Rueckfall)
# Der Benutzername kommt aus dem Store-Eintrag, sonst aus $login der credential.ps1.
# Die Funktion ist rein (kein Store-/Umgebungszugriff), damit sie ohne Switch testbar ist.

[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingConvertToSecureStringWithPlainText", "")]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingPlainTextForPassword", "")]
Param()

function Resolve-ArubaSWTestCredential {

    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    Param(
        [Parameter(Mandatory = $true)]
        [string]$Server,
        [Parameter(Mandatory = $false)]
        [string]$FileLogin,
        [Parameter(Mandatory = $false)]
        [string]$FilePassword,
        [Parameter(Mandatory = $false)]
        [string]$EnvPassword,
        [Parameter(Mandatory = $false)]
        [System.Management.Automation.PSCredential]$StoreCredential
    )

    if ($null -ne $StoreCredential) {
        return [PSCustomObject]@{ Login = $StoreCredential.UserName; Password = $StoreCredential.Password; Source = 'CredentialStore' }
    }
    if ($FileLogin -and $EnvPassword) {
        return [PSCustomObject]@{ Login = $FileLogin; Password = (ConvertTo-SecureString $EnvPassword -AsPlainText -Force); Source = 'Environment' }
    }
    if ($FileLogin -and $FilePassword) {
        return [PSCustomObject]@{ Login = $FileLogin; Password = (ConvertTo-SecureString $FilePassword -AsPlainText -Force); Source = 'credential.ps1' }
    }
    throw @"
Keine Test-Zugangsdaten fuer '$Server' gefunden. Moeglichkeiten (in dieser Reihenfolge):
  1. Credential Store (Windows):  Save-ArubaSWCredential -Server $Server
  2. Umgebungsvariable:           `$env:ARUBASW_TEST_PASSWORD (Benutzername aus `$login in Tests/credential.ps1)
  3. Klartext-Rueckfall:          `$password in Tests/credential.ps1
"@
}
