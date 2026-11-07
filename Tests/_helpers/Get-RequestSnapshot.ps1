#
# Copyright 2026, PowerArubaSW contributors
# SPDX-License-Identifier: Apache-2.0
#
# Request-Vertrag (Inkrement I34): Hilfsfunktion, die jedes exportierte Cmdlet je Parametersatz und Profil mit gemocktem Transport
# aufruft und festhaelt, WELCHE Anfragen (Methode, URI, Body) entstehen. Nutzer: Tests/unit/RequestVertrag.Tests.ps1 (Vergleich mit
# Tests/unit/_data/RequestVertrag.json) und Tools/New-RequestVertrag.ps1 (schreibt diese Datei neu).
#
# Profile:  pflicht  nur Pflichtparameter des Satzes
#           voll     alle Parameter des Satzes, Schalter/bool = $true, je Parameter ein eigener Wert (so faellt eine Verwechslung der Felder auf)
#           aus      alle Parameter, Schalter/bool = $false, Bereichs-/Mengenwerte am anderen Ende
#           whatif   wie voll, aber mit -WhatIf (nur Cmdlets mit ShouldProcess): es darf KEIN Request entstehen
#           menge-*  wie voll, aber ein ValidateSet-Parameter mit den mittleren Werten (bei mehr als zwei Werten)
# Je Fall wird festgehalten: Fehler-ID, Anfragen (Methode, URI, Body) und die Ausgabe des Cmdlets (bei der Antwort '{}' des Stubs).
# Isolation: eigener Runspace, Transport und Wartezeiten ersetzt - nichts geht an einen Switch.

# Exportierte Funktionen ohne Schnappschuss: eigene Tests bzw. kein REST-Aufruf ueber den Transport-Wrapper.
$script:RequestVertragAusnahmen = @(
    'Connect-ArubaSW'               # Login per Invoke-WebRequest, Tests/unit/Connection.Tests.ps1
    'Invoke-ArubaSWWebRequest'      # der Transport selbst, Tests/unit/Webrequest.Tests.ps1
    'Set-ArubaSWConnection'         # veraendert nur das Verbindungsobjekt, kein Request
    'Save-ArubaSWCredential'        # Credential Manager, Tests/unit/CredentialStore.Tests.ps1
    'Remove-ArubaSWCredential'      # Credential Manager, Tests/unit/CredentialStore.Tests.ps1
)

function Get-RequestSnapshot {
    [CmdletBinding()]
    [OutputType([object[]])]
    Param(
        [Parameter(Mandatory = $true)][string]$Manifest,
        [Parameter(Mandatory = $false)][string[]]$Name
    )

    $rs = [runspacefactory]::CreateRunspace()
    $rs.Open()
    try {
        $ps = [powershell]::Create()
        $ps.Runspace = $rs
        $null = $ps.AddScript({
            param($Modul, $Namen, $Ausnahmen)
            Set-StrictMode -Version 1.0
            Import-Module $Modul -Force
            $stub = [pscustomobject]@{
                server = '198.51.100.1'; port = 443; httpOnly = $false; invokeParams = @{}; session = $null
                cookie = 'x'; api_version = @{ cur = 8; min = 1; max = 8 }; switch_type = 'ST_STANDALONE'; product_number = 'X'
            }
            Set-Variable -Name DefaultArubaSWConnection -Value $stub -Scope Global
            & (Get-Module PowerArubaSW) {
                $script:RvCalls = [System.Collections.ArrayList]::new()
                function script:Invoke-ArubaSWWebRequest {
                    param($method, $uri, $body, $connection, $api_version)
                    $null = $connection   # nur zur Signatur des echten Transports
                    $eintrag = [ordered]@{ method = "$method"; uri = "$uri"; body = $body }
                    # Die REST-Version gehoert zum Vertrag, aber nur wenn das Cmdlet sie ausdruecklich setzt (I35, /mstp nur bis v5).
                    if ($PSBoundParameters.ContainsKey('api_version')) { $eintrag['api_version'] = $api_version }
                    $null = $script:RvCalls.Add($eintrag)
                    # Wie ein WebResponseObject: .Content ist der Text, und ToString() liefert ihn ebenfalls (35 Cmdlets pipen die Antwort direkt in ConvertFrom-Json).
                    $r = [pscustomobject]@{ Content = '{}' }
                    $r | Add-Member -MemberType ScriptMethod -Name ToString -Value { $this.Content } -Force
                    $r
                }
                function script:Invoke-WebRequest { throw 'Netz im Request-Vertrag gesperrt' }
                function script:Get-Credential    { throw 'Rueckfrage im Request-Vertrag gesperrt' }
                function script:Start-Sleep       { }
            }

            # Body in eine vergleichbare Form bringen: Schluessel sortiert, Objekte und Hashtables rekursiv.
            function ConvertTo-RvNormal {
                param($Wert)
                if ($null -eq $Wert) { return $null }
                if ($Wert -is [string] -or $Wert -is [ValueType]) { return $Wert }
                if ($Wert -is [System.Collections.IDictionary]) {
                    $o = [ordered]@{}
                    foreach ($k in ($Wert.Keys | Sort-Object)) { $o["$k"] = ConvertTo-RvNormal $Wert[$k] }
                    return $o
                }
                if ($Wert -is [System.Collections.IEnumerable]) { return , @($Wert | ForEach-Object { ConvertTo-RvNormal $_ }) }
                $o = [ordered]@{}
                foreach ($p in ($Wert.PSObject.Properties | Sort-Object Name)) { $o[$p.Name] = ConvertTo-RvNormal $p.Value }
                return $o
            }

            function Get-RvWert {
                param($Parameter, [string]$Profil, [int]$Index)
                $typ = $Parameter.ParameterType
                $set = @($Parameter.Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }) | Select-Object -First 1
                $range = @($Parameter.Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateRangeAttribute] }) | Select-Object -First 1
                $aus = $Profil -eq 'aus'
                if ($typ -eq [switch] -or $typ -eq [bool] -or $typ -eq [Nullable[bool]]) { return , (-not $aus) }
                if ($set) {
                    $v = @($set.ValidValues)
                    return , $(if ($aus -and $v.Count -gt 1) { $v[-1] } else { $v[0] })
                }
                if ($typ -in [int], [long], [double], [uint32], [int16], [byte]) {
                    if ($range) { return , [System.Convert]::ChangeType($(if ($aus) { $range.MaxRange } else { $range.MinRange }), $typ) }
                    return , [System.Convert]::ChangeType((10 + $Index + $(if ($aus) { 100 } else { 0 })), $typ)
                }
                if ($typ -eq [string]) { return , "v$Index-$($Parameter.Name)" }
                if ($typ -eq [ipaddress]) { return , [ipaddress]"198.51.100.$(10 + $Index)" }
                if ($typ -eq [securestring]) { return , (ConvertTo-SecureString "pw$Index" -AsPlainText -Force) }
                if ($typ -eq [pscredential]) { return , [pscredential]::new('u', (ConvertTo-SecureString 'pw' -AsPlainText -Force)) }
                if ($typ -eq [hashtable]) { return , @{ k = "v$Index" } }
                if ($typ -eq [ipaddress[]]) { return , @([ipaddress]"198.51.100.$(10 + $Index)", [ipaddress]"198.51.100.$(20 + $Index)") }
                if ($typ.IsArray) { return , @("a$Index", "b$Index") }
                # Objekt (z. B. ein aus Get-* kommendes VLAN/Port): die Felder, die die Cmdlets lesen
                return , [pscustomobject]@{ vlan_id = 85; id = 5; name = "obj-name"; port_id = 'p1'; port = 'p1'; trunk_id = 'Trk1'; group_id = 'g1'; radius_server_id = 5; address = '198.51.100.9'; server_group_name = 'grp1' }
            }

            $out = [System.Collections.ArrayList]::new()
            $cmds = Get-Command -Module PowerArubaSW -CommandType Function | Sort-Object Name
            $cmds = @($cmds | Where-Object { $_.Name -notin $Ausnahmen })
            if ($Namen) { $cmds = @($cmds | Where-Object Name -in $Namen) }
            $common = [System.Management.Automation.PSCmdlet]::CommonParameters + [System.Management.Automation.PSCmdlet]::OptionalCommonParameters
            # Cmdlets, deren Parametersaetze sich ueberlappen (alle Parameter liegen in jedem Satz): zusaetzlich gezielte Aufrufe.
            $extras = @{
                'Get-ArubaSWRadiusServer' = @(@{ address = [ipaddress]'198.51.100.7' }, @{ id = 'r5' })
                'Test-ArubaSWPing'        = @(@{ ipv4_address = [ipaddress]'198.51.100.8' }, @{ hostname = 'host.example.test' })
            }
            # Ein Fall: Standardverbindung wiederherstellen (Disconnect-ArubaSW entfernt sie), aufrufen, Anfragen und Ausgabe festhalten.
            function Invoke-RvFall {
                param($Cmd, [hashtable]$Argumente, [string]$Satz, [string]$Profil)
                Set-Variable -Name DefaultArubaSWConnection -Value $stub -Scope Global
                & (Get-Module PowerArubaSW) { $script:RvCalls.Clear() }
                $fehler = $null
                $ausgabe = @()
                try {
                    $roh = @(& $Cmd.Name @Argumente -ErrorAction Stop 2>&1 3>&1 4>&1 5>&1 6>&1)
                    $ausgabe = @($roh | Where-Object {
                        $_ -isnot [System.Management.Automation.ErrorRecord] -and $_ -isnot [System.Management.Automation.WarningRecord] -and
                        $_ -isnot [System.Management.Automation.VerboseRecord] -and $_ -isnot [System.Management.Automation.DebugRecord] -and
                        $_ -isnot [System.Management.Automation.InformationRecord] })
                }
                catch { $fehler = $_.FullyQualifiedErrorId }
                $calls = & (Get-Module PowerArubaSW) { , @($script:RvCalls.ToArray()) }
                [ordered]@{
                    name = $Cmd.Name; satz = $Satz; profil = $Profil
                    fehler = $fehler
                    calls = @($calls | ForEach-Object { $c = [ordered]@{ method = $_.method; uri = $_.uri; body = (ConvertTo-RvNormal $_.body) }; if ($_.Contains('api_version')) { $c['api_version'] = $_['api_version'] }; $c })
                    ausgabe = (ConvertTo-RvNormal $ausgabe)
                }
            }

            foreach ($cmd in $cmds) {
                foreach ($extra in @($extras[$cmd.Name])) {
                    if ($null -eq $extra) { continue }
                    $null = $out.Add((Invoke-RvFall -Cmd $cmd -Argumente $extra -Satz 'extra' -Profil ('extra-' + (($extra.Keys | Sort-Object) -join '+'))))
                }
                foreach ($set in $cmd.ParameterSets) {
                    $vollArgs = $null
                    $allParams = @($set.Parameters | Where-Object { $_.Name -notin $common -and $_.Name -ne 'connection' })
                    foreach ($profil in 'pflicht', 'voll', 'aus', 'whatif') {
                        if ($profil -eq 'whatif' -and -not $cmd.Parameters.ContainsKey('WhatIf')) { continue }
                        $params = if ($profil -eq 'pflicht') { @($allParams | Where-Object IsMandatory) } else { $allParams }
                        $args2 = @{}
                        $i = 0
                        foreach ($p in $params) { $i++; $args2[$p.Name] = Get-RvWert -Parameter $p -Profil $profil -Index $i }
                        if ($profil -eq 'whatif') { $args2['WhatIf'] = $true }
                        elseif ($cmd.Parameters.ContainsKey('Confirm')) { $args2['Confirm'] = $false }
                        if ($profil -eq 'voll') { $vollArgs = $args2.Clone() }
                        $null = $out.Add((Invoke-RvFall -Cmd $cmd -Argumente $args2 -Satz $set.Name -Profil $profil))
                    }
                    # ValidateSet mit mehr als zwei Werten: auch die mittleren Werte durchlaufen (voll nimmt den ersten, aus den letzten).
                    foreach ($p in $allParams) {
                        $vs = @($p.Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }) | Select-Object -First 1
                        if (-not $vs -or @($vs.ValidValues).Count -le 2) { continue }
                        foreach ($idx in 1..(@($vs.ValidValues).Count - 2)) {
                            $a2 = $vollArgs.Clone()
                            $a2[$p.Name] = @($vs.ValidValues)[$idx]
                            $null = $out.Add((Invoke-RvFall -Cmd $cmd -Argumente $a2 -Satz $set.Name -Profil ("menge-$($p.Name)-$(@($vs.ValidValues)[$idx])")))
                        }
                    }
                }
            }
            , $out.ToArray()
        }).AddArgument($Manifest).AddArgument($Name).AddArgument($script:RequestVertragAusnahmen)
        $ergebnis = $ps.Invoke()
        if (-not $ergebnis -or $ergebnis.Count -eq 0) { throw "Request-Vertrag: kein Ergebnis aus dem Runspace: $($ps.Streams.Error | Select-Object -First 3 | Out-String)" }
        $ps.Dispose()
        return , @($ergebnis[0])
    }
    finally {
        $rs.Dispose()
    }
}
