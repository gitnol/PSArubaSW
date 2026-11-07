#
# Copyright 2026, PowerArubaSW contributors
# SPDX-License-Identifier: Apache-2.0
#
# Mutanten fuer Tools/Invoke-MutationCheck.ps1 (Inkrement I30). Kern-Schicht: Private/Webrequest.ps1,
# Public/Connection.ps1, Private/CredentialStore.ps1; Stichprobe Resource-Schicht: Public/Vlans.ps1 (I31); Private/ConnectionHelpers.ps1 (I32). Find muss in der Datei genau einmal vorkommen.
# Ergebnisse und Begruendungen fuer ueberlebende Mutanten: siehe Kommentare je Mutant.
@{
    Mutants = @(
        # ---------------------------------------------------------------- Private/Webrequest.ps1
        @{ Id = 'W01'; File = 'PowerArubaSW/Private/Webrequest.ps1'; Tests = @('Tests/unit/Webrequest.Tests.ps1')
           Find = 'if ($null -eq $connection ) {'; Replace = 'if ($null -ne $connection ) {'; Note = 'Standardverbindung: Bedingung gedreht' }
        @{ Id = 'W02'; File = 'PowerArubaSW/Private/Webrequest.ps1'; Tests = @('Tests/unit/Webrequest.Tests.ps1')
           Find = 'Throw "Not Connected. Connect to the Switch with Connect-ArubaSW"'; Replace = 'Write-Verbose "Not Connected"'; Note = 'ohne Verbindung wird nicht mehr geworfen' }
        @{ Id = 'W03'; File = 'PowerArubaSW/Private/Webrequest.ps1'; Tests = @('Tests/unit/Webrequest.Tests.ps1')
           Find = '$fullurl = "http://${Server}:${port}/"'; Replace = '$fullurl = "https://${Server}:${port}/"'; Note = 'httpOnly baut https-URL' }
        @{ Id = 'W04'; File = 'PowerArubaSW/Private/Webrequest.ps1'; Tests = @('Tests/unit/Webrequest.Tests.ps1')
           Find = '$fullurl = "https://${Server}:${port}/"'; Replace = '$fullurl = "http://${Server}:${port}/"'; Note = 'HTTPS-Verbindung baut http-URL' }
        @{ Id = 'W05'; File = 'PowerArubaSW/Private/Webrequest.ps1'; Tests = @('Tests/unit/Webrequest.Tests.ps1')
           Find = 'if ($api_version -ne "0") {'; Replace = 'if ($api_version -eq "0") {'; Note = 'api_version 0: Bedingung gedreht' }
        @{ Id = 'W06'; File = 'PowerArubaSW/Private/Webrequest.ps1'; Tests = @('Tests/unit/Webrequest.Tests.ps1')
           Find = '$fullurl += "rest/v" + $api_version + "/"'; Replace = '$fullurl += "rest/v" + "1" + "/"'; Note = 'explizite api_version wird ignoriert' }
        @{ Id = 'W07'; File = 'PowerArubaSW/Private/Webrequest.ps1'; Tests = @('Tests/unit/Webrequest.Tests.ps1')
           Find = '$fullurl += "rest/v" + $connection.api_version.cur + "/"'; Replace = '$fullurl += "rest/"'; Note = 'api_version der Verbindung fehlt in der URL' }
        @{ Id = 'W08'; File = 'PowerArubaSW/Private/Webrequest.ps1'; Tests = @('Tests/unit/Webrequest.Tests.ps1')
           Find = '$fullurl += $uri'; Replace = '$fullurl += ""'; Note = 'uri wird nicht angehaengt' }
        @{ Id = 'W09'; File = 'PowerArubaSW/Private/Webrequest.ps1'; Tests = @('Tests/unit/Webrequest.Tests.ps1')
           Find = 'if ($body) {'; Replace = 'if (-not $body) {'; Note = 'Body-Zweig gedreht' }
        @{ Id = 'W10'; File = 'PowerArubaSW/Private/Webrequest.ps1'; Tests = @('Tests/unit/Webrequest.Tests.ps1')
           Find = '-body ($body | ConvertTo-Json)'; Replace = '-body $body'; Note = 'Body wird nicht in JSON gewandelt' }
        @{ Id = 'W11'; File = 'PowerArubaSW/Private/Webrequest.ps1'; Tests = @('Tests/unit/Webrequest.Tests.ps1')
           Find = '[String]$method = "get",'; Replace = '[String]$method = "post",'; Note = 'Standardmethode GET -> POST' }
        @{ Id = 'W12'; File = 'PowerArubaSW/Private/Webrequest.ps1'; Tests = @('Tests/unit/Webrequest.Tests.ps1')
           Find = 'throw "Unable to use switch API"'; Replace = 'Write-Verbose "x"'; Note = 'Fehler der API werden verschluckt' }
        @{ Id = 'W13'; File = 'PowerArubaSW/Private/Webrequest.ps1'; Tests = @('Tests/unit/Webrequest.Tests.ps1')
           Find = 'Show-ArubaSWException -Exception $_'; Replace = '$null = $_'; Note = 'Fehlerdetails werden nicht gemeldet' }
        @{ Id = 'W14'; File = 'PowerArubaSW/Private/Webrequest.ps1'; Tests = @('Tests/unit/Webrequest.Tests.ps1')
           Find = '$invokeParams = $connection.InvokeParams'; Replace = '$invokeParams = @{}'; Note = 'invokeParams der Verbindung werden ignoriert' }
        @{ Id = 'W15'; File = 'PowerArubaSW/Private/Webrequest.ps1'; Tests = @('Tests/unit/Webrequest.Tests.ps1')
           Find = '$sessionvariable = $connection.session'; Replace = '$sessionvariable = $null'; Note = 'Session (Cookie) wird nicht mitgesendet' }

        # ---------------------------------------------------------------- Public/Connection.ps1
        @{ Id = 'C01'; File = 'PowerArubaSW/Public/Connection.ps1'; Tests = @('Tests/unit/Connection.Tests.ps1')
           Find = 'if ($httpOnly -and -not $Force) {'; Replace = 'if ($httpOnly -and $Force) {'; Note = '-httpOnly ohne -Force: Bedingung gedreht' }
        @{ Id = 'C02'; File = 'PowerArubaSW/Public/Connection.ps1'; Tests = @('Tests/unit/Connection.Tests.ps1')
           Find = 'throw "Refused -httpOnly without -Force: cleartext credential transmission over HTTP requires explicit -Force."'; Replace = 'Write-Verbose "x"'; Note = '-httpOnly ohne -Force wirft nicht mehr' }
        @{ Id = 'C03'; File = 'PowerArubaSW/Public/Connection.ps1'; Tests = @('Tests/unit/Connection.Tests.ps1')
           Find = '[ValidateRange(1, 65535)]'; Replace = '[ValidateRange(1, 65536)]'; Note = 'Portbereich: obere Grenze +1' }
        @{ Id = 'C04'; File = 'PowerArubaSW/Public/Connection.ps1'; Tests = @('Tests/unit/Connection.Tests.ps1')
           Find = "[int]`$port,`n        [Parameter(Mandatory = `$false)]`n        [ValidateRange(1, 10)]"; Replace = "[int]`$port,`n        [Parameter(Mandatory = `$false)]`n        [ValidateRange(1, 11)]"; Note = 'Connect: api_version, obere Grenze +1' }
        @{ Id = 'C05'; File = 'PowerArubaSW/Private/ConnectionHelpers.ps1'; Tests = @('Tests/unit/Connection.Tests.ps1', 'Tests/unit/ConnectionHelpers.Tests.ps1')
           Find = '$Port = 80'; Replace = '$Port = 8080'; Note = 'Standardport HTTP' }
        @{ Id = 'C06'; File = 'PowerArubaSW/Private/ConnectionHelpers.ps1'; Tests = @('Tests/unit/Connection.Tests.ps1', 'Tests/unit/ConnectionHelpers.Tests.ps1')
           Find = '$Port = 443'; Replace = '$Port = 4443'; Note = 'Standardport HTTPS' }
        @{ Id = 'C07'; File = 'PowerArubaSW/Private/ConnectionHelpers.ps1'; Tests = @('Tests/unit/Connection.Tests.ps1', 'Tests/unit/ConnectionHelpers.Tests.ps1')
           Find = '$uri += "rest/v3/login-sessions"'; Replace = '$uri += "rest/v2/login-sessions"'; Note = 'Standard-API-Version fuer den Login' }
        @{ Id = 'C08'; File = 'PowerArubaSW/Public/Connection.ps1'; Tests = @('Tests/unit/Connection.Tests.ps1')
           Find = 'if ( $DefaultConnection ) {'; Replace = 'if ( -not $DefaultConnection ) {'; Note = 'Globale Standardverbindung gedreht' }
        @{ Id = 'C09'; File = 'PowerArubaSW/Public/Connection.ps1'; Tests = @('Tests/unit/Connection.Tests.ps1')
           Find = 'throw "Unable to connect"'; Replace = 'Write-Verbose "x"'; Note = 'Login-Fehler wird verschluckt' }
        @{ Id = 'C10'; File = 'PowerArubaSW/Public/Connection.ps1'; Tests = @('Tests/unit/Connection.Tests.ps1')
           Find = '$uri = "login-sessions"'; Replace = '$uri = "login-session"'; Note = 'Disconnect: falsche URI' }
        @{ Id = 'C11'; File = 'PowerArubaSW/Public/Connection.ps1'; Tests = @('Tests/unit/Connection.Tests.ps1')
           Find = '$null = Invoke-ArubaSWWebRequest -method "DELETE" -uri $uri -connection $connection'; Replace = '$null = Invoke-ArubaSWWebRequest -method "GET" -uri $uri -connection $connection'; Note = 'Disconnect: falsche Methode' }
        @{ Id = 'C12'; File = 'PowerArubaSW/Public/Connection.ps1'; Tests = @('Tests/unit/Connection.Tests.ps1')
           Find = 'if ($PSCmdlet.ShouldProcess($connection.server, ''Remove Connection'')) {'; Replace = 'if ($true) {'; Note = 'Disconnect ohne ShouldProcess (WhatIf wirkungslos)' }
        @{ Id = 'C13'; File = 'PowerArubaSW/Public/Connection.ps1'; Tests = @('Tests/unit/Connection.Tests.ps1', 'Tests/unit/CredentialStore.Tests.ps1')
           Find = '-CredentialTarget $CredentialTarget'; Replace = ''; Note = '-CredentialTarget wird nicht an den Resolver gereicht' }
        @{ Id = 'C14'; File = 'PowerArubaSW/Public/Connection.ps1'; Tests = @('Tests/unit/Connection.Tests.ps1', 'Tests/unit/CredentialStore.Tests.ps1')
           Find = '-Server $Server -Username $Username -Password $Password'; Replace = '-Server $Server -Username $Username'; Note = '-Password wird nicht an den Resolver gereicht' }

        # ---------------------------------------------------------------- Private/CredentialStore.ps1
        @{ Id = 'S01'; File = 'PowerArubaSW/Private/CredentialStore.ps1'; Tests = @('Tests/unit/CredentialStore.Tests.ps1')
           Find = "'PowerArubaSW_' + `$Server.Trim()"; Replace = "'PowerArubaSW-' + `$Server.Trim()"; Note = 'Praefix des Default-Ziels' }
        @{ Id = 'S02'; File = 'PowerArubaSW/Private/CredentialStore.ps1'; Tests = @('Tests/unit/CredentialStore.Tests.ps1')
           Find = "'PowerArubaSW_' + `$Server.Trim()"; Replace = "'PowerArubaSW_' + `$Server"; Note = 'Trim des Servernamens entfaellt' }
        @{ Id = 'S03'; File = 'PowerArubaSW/Private/CredentialStore.ps1'; Tests = @('Tests/unit/CredentialStore.Tests.ps1')
           Find = '[System.Environment]::OSVersion.Platform -eq [System.PlatformID]::Win32NT'; Replace = '[System.Environment]::OSVersion.Platform -ne [System.PlatformID]::Win32NT'; Note = 'Plattformpruefung gedreht' }
        @{ Id = 'S04'; File = 'PowerArubaSW/Private/CredentialStore.ps1'; Tests = @('Tests/unit/CredentialStore.Tests.ps1')
           Find = 'if (-not (Test-ArubaSWCredentialStore)) { return $null }'; Replace = ''; Note = 'Get: Plattformpruefung entfaellt (Rueckfall auf catch)' }
        @{ Id = 'S05'; File = 'PowerArubaSW/Private/CredentialStore.ps1'; Tests = @('Tests/unit/CredentialStore.Tests.ps1')
           Find = 'if (-not $result) { return $null }'; Replace = ''; Note = 'Get: nicht vorhandenes Ziel -> Fehler statt $null (catch faengt ab)' }
        @{ Id = 'S06'; File = 'PowerArubaSW/Private/CredentialStore.ps1'; Tests = @('Tests/unit/CredentialStore.Tests.ps1')
           Find = '$password.Length * 2'; Replace = '$password.Length'; Note = 'Set: Blob-Laenge in Bytes' }
        @{ Id = 'S07'; File = 'PowerArubaSW/Private/CredentialStore.ps1'; Tests = @('Tests/unit/CredentialStore.Tests.ps1')
           Find = '[System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)'; Replace = '$null = $bstr'; Note = 'Set: BSTR wird nicht genullt/freigegeben' }
        @{ Id = 'S08'; File = 'PowerArubaSW/Private/CredentialStore.ps1'; Tests = @('Tests/unit/CredentialStore.Tests.ps1')
           Find = 'if (blobBytes > CRED_MAX_CREDENTIAL_BLOB)'; Replace = 'if (blobBytes >= CRED_MAX_CREDENTIAL_BLOB)'; Note = 'Passwortlaenge: Grenzwert (1280 Zeichen)' }
        @{ Id = 'S09'; File = 'PowerArubaSW/Private/CredentialStore.ps1'; Tests = @('Tests/unit/CredentialStore.Tests.ps1')
           Find = 'Persist            = CRED_PERSIST_LOCAL_MACHINE'; Replace = 'Persist            = 1'; Note = 'Persistenz: Session statt LOCAL_MACHINE' }
        @{ Id = 'S10'; File = 'PowerArubaSW/Private/CredentialStore.ps1'; Tests = @('Tests/unit/CredentialStore.Tests.ps1')
           Find = 'if (err == ERROR_NOT_FOUND) return false;'; Replace = ''; Note = 'Delete: fehlendes Ziel wirft statt false' }
        @{ Id = 'S11'; File = 'PowerArubaSW/Private/CredentialStore.ps1'; Tests = @('Tests/unit/CredentialStore.Tests.ps1')
           Find = 'secure.MakeReadOnly();'; Replace = ''; Note = 'Read: SecureString nicht schreibgeschuetzt' }
        @{ Id = 'S12'; File = 'PowerArubaSW/Private/CredentialStore.ps1'; Tests = @('Tests/unit/CredentialStore.Tests.ps1')
           Find = 'if ($Password) {'; Replace = 'if (-not $Password) {'; Note = 'Resolver: -Password-Zweig gedreht' }
        @{ Id = 'S13'; File = 'PowerArubaSW/Private/CredentialStore.ps1'; Tests = @('Tests/unit/CredentialStore.Tests.ps1')
           Find = 'if ($null -ne $Credentials) {'; Replace = 'if ($null -eq $Credentials) {'; Note = 'Resolver: -Credentials-Zweig gedreht' }
        @{ Id = 'S14'; File = 'PowerArubaSW/Private/CredentialStore.ps1'; Tests = @('Tests/unit/CredentialStore.Tests.ps1')
           Find = 'if ($CredentialTarget) {'; Replace = 'if (-not $CredentialTarget) {'; Note = 'Resolver: -CredentialTarget-Zweig gedreht' }
        @{ Id = 'S15'; File = 'PowerArubaSW/Private/CredentialStore.ps1'; Tests = @('Tests/unit/CredentialStore.Tests.ps1')
           Find = 'if ($null -eq $stored) {'; Replace = 'if ($null -ne $stored) {'; Note = 'Resolver: fehlendes -CredentialTarget wirft nicht' }
        @{ Id = 'S16'; File = 'PowerArubaSW/Private/CredentialStore.ps1'; Tests = @('Tests/unit/CredentialStore.Tests.ps1')
           Find = 'if ($null -ne $stored) {'; Replace = 'if ($null -eq $stored) {'; Note = 'Resolver: Default-Ziel gedreht' }
        @{ Id = 'S17'; File = 'PowerArubaSW/Private/CredentialStore.ps1'; Tests = @('Tests/unit/CredentialStore.Tests.ps1')
           Find = 'throw "-CredentialTarget needs the Windows Credential Manager (not available on this platform)."'; Replace = 'Write-Verbose "x"'; Note = 'Resolver: -CredentialTarget ohne Store wirft nicht' }
        @{ Id = 'S18'; File = 'PowerArubaSW/Private/CredentialStore.ps1'; Tests = @('Tests/unit/CredentialStore.Tests.ps1')
           Find = 'Write-Verbose "Using stored credential ''$defaultTarget''"'; Replace = ''; Note = 'Resolver: Verbose-Meldung (nur Ausgabe)' }
        # ---------------------------------------------------------------- Public/Vlans.ps1 (I31, Stichprobe Resource-Schicht)
        @{ Id = 'V01'; File = 'PowerArubaSW/Public/Vlans.ps1'; Tests = @('Tests/unit/Vlans.Tests.ps1')
           Find = '$vlan | Add-Member -name "name" -membertype NoteProperty -Value "VLAN$($id)"'; Replace = '$vlan | Add-Member -name "name" -membertype NoteProperty -Value "vlan$($id)"'; Note = 'Add: Standardname VLAN<id> verfaelscht' }
        @{ Id = 'V02'; File = 'PowerArubaSW/Public/Vlans.ps1'; Tests = @('Tests/unit/Vlans.Tests.ps1')
           Find = 'Invoke-ArubaSWWebRequest -method "POST" -body $vlan -uri $uri'; Replace = 'Invoke-ArubaSWWebRequest -method "PUT" -body $vlan -uri $uri'; Note = 'Add: falsche HTTP-Methode' }
        @{ Id = 'V03'; File = 'PowerArubaSW/Public/Vlans.ps1'; Tests = @('Tests/unit/Vlans.Tests.ps1')
           Find = '$vlans | Where-Object { $_.vlan_id -eq $id }'; Replace = '$vlans | Where-Object { $_.vlan_id -ne $id }'; Note = 'Get: id-Filter gedreht' }
        @{ Id = 'V04'; File = 'PowerArubaSW/Public/Vlans.ps1'; Tests = @('Tests/unit/Vlans.Tests.ps1')
           Find = '$vlans | Where-Object { $_.name -match $name }'; Replace = '$vlans | Where-Object { $_.name -eq $name }'; Note = 'Get: Namensfilter match -> eq' }
        @{ Id = 'V05'; File = 'PowerArubaSW/Public/Vlans.ps1'; Tests = @('Tests/unit/Vlans.Tests.ps1')
           Find = 'Invoke-ArubaSWWebRequest -method "PUT" -body $_vlan -uri $uri'; Replace = 'Invoke-ArubaSWWebRequest -method "POST" -body $_vlan -uri $uri'; Note = 'Set: falsche HTTP-Methode' }
        @{ Id = 'V06'; File = 'PowerArubaSW/Public/Vlans.ps1'; Tests = @('Tests/unit/Vlans.Tests.ps1')
           Find = '$vlan | Add-Member -name "is_voice_enabled" -membertype NoteProperty -Value $True'; Replace = '$vlan | Add-Member -name "is_voice_enabled" -membertype NoteProperty -Value $false'; Note = 'Add: -is_voice_enabled schreibt false' }
        @{ Id = 'V07'; File = 'PowerArubaSW/Public/Vlans.ps1'; Tests = @('Tests/unit/Vlans.Tests.ps1')
           Find = '$_vlan | Add-Member -name "is_jumbo_enabled" -membertype NoteProperty -Value $True'; Replace = '$_vlan | Add-Member -name "is_jumbo_enabled" -membertype NoteProperty -Value $false'; Note = 'Set: -is_jumbo_enabled schreibt false' }
        @{ Id = 'V08'; File = 'PowerArubaSW/Public/Vlans.ps1'; Tests = @('Tests/unit/Vlans.Tests.ps1')
           Find = '$oldname = $vlan.name'; Replace = '$oldname = $null'; Note = 'Set: Name aus Pipeline-Objekt wird verworfen' }
        @{ Id = 'V09'; File = 'PowerArubaSW/Public/Vlans.ps1'; Tests = @('Tests/unit/Vlans.Tests.ps1')
           Find = 'Invoke-ArubaSWWebRequest -method "DELETE" -uri $uri'; Replace = 'Invoke-ArubaSWWebRequest -method "GET" -uri $uri'; Note = 'Remove: falsche HTTP-Methode' }
        @{ Id = 'V10'; File = 'PowerArubaSW/Public/Vlans.ps1'; Tests = @('Tests/unit/Vlans.Tests.ps1')
           Find = 'if ($PSCmdlet.ShouldProcess($id, "Remove VLAN")) {'; Replace = 'if ($true) {'; Note = 'Remove: ShouldProcess/-WhatIf ausgehebelt' }
        # ---------------------------------------------------------------- Private/ConnectionHelpers.ps1 (I32)
        @{ Id = 'H01'; File = 'PowerArubaSW/Private/ConnectionHelpers.ps1'; Tests = @('Tests/unit/Connection.Tests.ps1', 'Tests/unit/ConnectionHelpers.Tests.ps1')
           Find = "if (`"Desktop`" -eq `$Edition) {`n            #Remove -SkipCertificateCheck"; Replace = "if (`"Core`" -eq `$Edition) {`n            #Remove -SkipCertificateCheck"; Note = 'Login-Parameter: Edition-Weiche gedreht' }
        @{ Id = 'H02'; File = 'PowerArubaSW/Private/ConnectionHelpers.ps1'; Tests = @('Tests/unit/Connection.Tests.ps1', 'Tests/unit/ConnectionHelpers.Tests.ps1')
           Find = '$invokeParams.remove("UseBasicParsing")'; Replace = ''; Note = 'Core: UseBasicParsing bleibt stehen' }
        @{ Id = 'H03'; File = 'PowerArubaSW/Private/ConnectionHelpers.ps1'; Tests = @('Tests/unit/Connection.Tests.ps1', 'Tests/unit/ConnectionHelpers.Tests.ps1')
           Find = '$invokeParams.remove("SkipCertificateCheck")'; Replace = ''; Note = 'Desktop: SkipCertificateCheck bleibt stehen' }
        @{ Id = 'H04'; File = 'PowerArubaSW/Private/ConnectionHelpers.ps1'; Tests = @('Tests/unit/Connection.Tests.ps1', 'Tests/unit/ConnectionHelpers.Tests.ps1')
           Find = "            Set-ArubaSWCipherSSL`n"; Replace = ""; Note = 'Desktop: TLS wird nicht eingeschaltet' }
        @{ Id = 'H05'; File = 'PowerArubaSW/Private/ConnectionHelpers.ps1'; Tests = @('Tests/unit/Connection.Tests.ps1', 'Tests/unit/ConnectionHelpers.Tests.ps1')
           Find = 'if ($SkipCertificateCheck) {'; Replace = 'if (-not $SkipCertificateCheck) {'; Note = 'Desktop: Zertifikatskette-Weiche gedreht' }
        @{ Id = 'H06'; File = 'PowerArubaSW/Private/ConnectionHelpers.ps1'; Tests = @('Tests/unit/Connection.Tests.ps1', 'Tests/unit/ConnectionHelpers.Tests.ps1')
           Find = '$uri = "http://${Server}:${Port}/"'; Replace = '$uri = "https://${Server}:${Port}/"'; Note = 'httpOnly baut https-URL' }
        @{ Id = 'H07'; File = 'PowerArubaSW/Private/ConnectionHelpers.ps1'; Tests = @('Tests/unit/Connection.Tests.ps1', 'Tests/unit/ConnectionHelpers.Tests.ps1')
           Find = '$uri += "rest/v${ApiVersion}/login-sessions"'; Replace = '$uri += "rest/v3/login-sessions"'; Note = 'genannte API-Version wird ignoriert' }
        @{ Id = 'H08'; File = 'PowerArubaSW/Private/ConnectionHelpers.ps1'; Tests = @('Tests/unit/Connection.Tests.ps1', 'Tests/unit/ConnectionHelpers.Tests.ps1')
           Find = '^v?(\d+)'; Replace = '^v?(\d)'; Note = 'Versionsspanne: nur eine Ziffer der Hauptversion' }
        @{ Id = 'H09'; File = 'PowerArubaSW/Private/ConnectionHelpers.ps1'; Tests = @('Tests/unit/Connection.Tests.ps1', 'Tests/unit/ConnectionHelpers.Tests.ps1')
           Find = 'Min = ($vers | Measure-Object -Minimum).Minimum'; Replace = 'Min = ($vers | Measure-Object -Maximum).Maximum'; Note = 'Versionsspanne: Min = Max' }
        @{ Id = 'H10'; File = 'PowerArubaSW/Private/ConnectionHelpers.ps1'; Tests = @('Tests/unit/Connection.Tests.ps1', 'Tests/unit/ConnectionHelpers.Tests.ps1')
           Find = '$SwitchStatus.blades.product_number[0]'; Replace = '$SwitchStatus.blades.product_number[-1]'; Note = 'Stack: letzte statt erste Produktnummer' }
        @{ Id = 'H11'; File = 'PowerArubaSW/Private/ConnectionHelpers.ps1'; Tests = @('Tests/unit/Connection.Tests.ps1', 'Tests/unit/ConnectionHelpers.Tests.ps1')
           Find = 'if ( $SwitchStatus.blades.count -eq "1") {'; Replace = 'if ( $SwitchStatus.blades.count -ne "1") {'; Note = 'Stack: Einheiten-Weiche gedreht' }
        @{ Id = 'H12'; File = 'PowerArubaSW/Private/ConnectionHelpers.ps1'; Tests = @('Tests/unit/Connection.Tests.ps1', 'Tests/unit/ConnectionHelpers.Tests.ps1')
           Find = '$product_name += ", "'; Replace = '$product_name += " "'; Note = 'Stack: Namen ohne Komma verbunden' }
        # ---------------------------------------------------------------- SecretManagement (I34)
        @{ Id = 'S19'; File = 'PowerArubaSW/Private/CredentialStore.ps1'; Tests = @('Tests/unit/SecretManagement.Tests.ps1', 'Tests/unit/CredentialStore.Tests.ps1')
           Find = 'if (-not (Get-Command -Name Get-Secret -ErrorAction SilentlyContinue)) {'; Replace = 'if ((Get-Command -Name Get-Secret -ErrorAction SilentlyContinue)) {'; Note = 'SecretManagement: Pruefung auf Get-Secret gedreht' }
        @{ Id = 'S20'; File = 'PowerArubaSW/Private/CredentialStore.ps1'; Tests = @('Tests/unit/SecretManagement.Tests.ps1', 'Tests/unit/CredentialStore.Tests.ps1')
           Find = 'if ($Vault) {'; Replace = 'if (-not $Vault) {'; Note = 'SecretManagement: -Vault-Weiche gedreht' }
        @{ Id = 'S21'; File = 'PowerArubaSW/Private/CredentialStore.ps1'; Tests = @('Tests/unit/SecretManagement.Tests.ps1', 'Tests/unit/CredentialStore.Tests.ps1')
           Find = '$getParams.Vault = $Vault'; Replace = ''; Note = 'SecretManagement: -Vault wird nicht an Get-Secret gereicht' }
        @{ Id = 'S22'; File = 'PowerArubaSW/Private/CredentialStore.ps1'; Tests = @('Tests/unit/SecretManagement.Tests.ps1', 'Tests/unit/CredentialStore.Tests.ps1')
           Find = 'if ($null -eq $secret) {'; Replace = 'if ($null -ne $secret) {'; Note = 'SecretManagement: leeres Secret wirft nicht' }
        @{ Id = 'S23'; File = 'PowerArubaSW/Private/CredentialStore.ps1'; Tests = @('Tests/unit/SecretManagement.Tests.ps1', 'Tests/unit/CredentialStore.Tests.ps1')
           Find = 'if ($secret -is [System.Management.Automation.PSCredential]) {'; Replace = 'if ($secret -isnot [System.Management.Automation.PSCredential]) {'; Note = 'SecretManagement: PSCredential-Weiche gedreht' }
        @{ Id = 'S24'; File = 'PowerArubaSW/Private/CredentialStore.ps1'; Tests = @('Tests/unit/SecretManagement.Tests.ps1', 'Tests/unit/CredentialStore.Tests.ps1')
           Find = 'if (-not $Username) {'; Replace = 'if ($Username) {'; Note = 'SecretManagement: SecureString braucht -Username, Weiche gedreht' }
        @{ Id = 'S25'; File = 'PowerArubaSW/Private/CredentialStore.ps1'; Tests = @('Tests/unit/SecretManagement.Tests.ps1', 'Tests/unit/CredentialStore.Tests.ps1')
           Find = '[System.Management.Automation.PSCredential]::new($Username, $secret)'; Replace = '[System.Management.Automation.PSCredential]::new(''x'', $secret)'; Note = 'SecretManagement: Benutzername wird verworfen' }
        @{ Id = 'S26'; File = 'PowerArubaSW/Private/CredentialStore.ps1'; Tests = @('Tests/unit/SecretManagement.Tests.ps1', 'Tests/unit/CredentialStore.Tests.ps1')
           Find = 'if ($SecretName) {'; Replace = 'if (-not $SecretName) {'; Note = 'Resolver: -SecretName-Zweig gedreht' }
        @{ Id = 'S27'; File = 'PowerArubaSW/Private/CredentialStore.ps1'; Tests = @('Tests/unit/SecretManagement.Tests.ps1', 'Tests/unit/CredentialStore.Tests.ps1')
           Find = '-SecretName $SecretName -Vault $Vault -Username $Username'; Replace = '-SecretName $SecretName -Username $Username'; Note = 'Resolver: -Vault wird nicht weitergereicht' }
        @{ Id = 'S28'; File = 'PowerArubaSW/Public/Connection.ps1'; Tests = @('Tests/unit/SecretManagement.Tests.ps1', 'Tests/unit/Connection.Tests.ps1')
           Find = '-SecretName $SecretName -Vault $Vault'; Replace = '-SecretName $SecretName'; Note = 'Connect: -Vault wird nicht an den Resolver gereicht' }
        @{ Id = 'S29'; File = 'PowerArubaSW/Public/Connection.ps1'; Tests = @('Tests/unit/SecretManagement.Tests.ps1', 'Tests/unit/Connection.Tests.ps1')
           Find = '-SecretName $SecretName -Vault $Vault'; Replace = '-Vault $Vault'; Note = 'Connect: -SecretName wird nicht an den Resolver gereicht' }
    )
}
