#
# Copyright 2026, PowerArubaSW contributors
# SPDX-License-Identifier: Apache-2.0
#
# Kleine Schritte aus Connect-ArubaSW (Inkrement I32, Refactoring ohne Verhaltensaenderung). Alle Helfer sind rein oder haben genau
# eine Wirkung (Initialize-ArubaSWDesktopSSL); die HTTP-Anfrage selbst bleibt in Connect-ArubaSW (Public/Connection.ps1).

function Get-ArubaSWLoginInvokeParameter {

    <#
        .SYNOPSIS
        Parameter fuer Invoke-WebRequest beim Login (internal)

        .DESCRIPTION
        Desktop (Windows PowerShell 5.1): ohne -SkipCertificateCheck (dort nicht unterstuetzt), mit -UseBasicParsing.
        Core: mit -SkipCertificateCheck, ohne -UseBasicParsing (in PowerShell 6+ ohnehin aktiv).
        Die Edition wird uebergeben, damit beide Zweige ohne Windows PowerShell testbar sind.
    #>

    [CmdletBinding()]
    [OutputType([hashtable])]
    Param(
        [Parameter(Mandatory = $false)]
        [switch]$SkipCertificateCheck,
        [Parameter(Mandatory = $true)]
        [string]$Edition
    )

    Process {
        $invokeParams = @{DisableKeepAlive = $true; UseBasicParsing = $true; SkipCertificateCheck = $SkipCertificateCheck }

        if ("Desktop" -eq $Edition) {
            #Remove -SkipCertificateCheck from Invoke Parameter (not supported <= PS 5)
            $invokeParams.remove("SkipCertificateCheck")
        }
        else {
            #Core Edition
            #Remove -UseBasicParsing (Enable by default with PowerShell 6/Core)
            $invokeParams.remove("UseBasicParsing")
        }
        $invokeParams
    }
}

function Get-ArubaSWLoginTarget {

    <#
        .SYNOPSIS
        Login-URL und Port fuer Connect-ArubaSW (internal)

        .DESCRIPTION
        Standardport 80 (-httpOnly) bzw. 443; Standard-API-Version fuer den Login ist v3 (einige neue Geraete kennen v1/v2 nicht),
        mit -ApiVersion die genannte. Rueckgabe: Objekt mit Uri und Port.
    #>

    [CmdletBinding()]
    [OutputType([pscustomobject])]
    Param(
        [Parameter(Mandatory = $true)]
        [string]$Server,
        [Parameter(Mandatory = $false)]
        [int]$Port,
        [Parameter(Mandatory = $false)]
        [switch]$HttpOnly,
        [Parameter(Mandatory = $false)]
        [int]$ApiVersion
    )

    Process {
        if ($HttpOnly) {
            if (!$Port) {
                $Port = 80
            }
            $uri = "http://${Server}:${Port}/"
        }
        else {
            if (!$Port) {
                $Port = 443
            }
            $uri = "https://${Server}:${Port}/"
        }

        if ($PsBoundParameters.ContainsKey('ApiVersion')) {
            $uri += "rest/v${ApiVersion}/login-sessions"
        }
        else {
            #By default use v3 API (some 'new' device don't support v1/v2 API...)
            $uri += "rest/v3/login-sessions"
        }

        [pscustomobject]@{ Uri = $uri; Port = $Port }
    }
}

function Initialize-ArubaSWDesktopSSL {

    <#
        .SYNOPSIS
        TLS fuer Windows PowerShell (Desktop) einschalten (internal)

        .DESCRIPTION
        Nur Edition Desktop (<= PowerShell 5): TLS 1.1/1.2 aktivieren (Set-ArubaSWCipherSSL) und mit -SkipCertificateCheck die
        Zertifikatskette ignorieren (Set-ArubaSWuntrustedSSL, prozessweit bis Disconnect-ArubaSW). Auf Core passiert nichts.
    #>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true)]
        [string]$Edition,
        [Parameter(Mandatory = $false)]
        [switch]$SkipCertificateCheck
    )

    Process {
        if ("Desktop" -eq $Edition) {
            #Enable TLS 1.1 and 1.2
            Set-ArubaSWCipherSSL
            if ($SkipCertificateCheck) {
                #Disable SSL chain trust...
                Set-ArubaSWuntrustedSSL
            }
        }
    }
}

function Get-ArubaSWApiVersionRange {

    <#
        .SYNOPSIS
        Kleinste und groesste vom Switch gemeldete REST-Version (internal)

        .DESCRIPTION
        Aus der Antwort von Get-ArubaSWRestversion (version = v1.0, v2.0 ...): "v" und die Endungen .0/.1 entfernen, Min/Max bilden.
    #>

    [CmdletBinding()]
    [OutputType([pscustomobject])]
    Param(
        [Parameter(Mandatory = $true)]
        [PSObject]$RestVersion
    )

    Process {
        # Hauptversion aus "v3.0", "v8.1" ... (I34: vorher entfernte ein Regex mit unmaskiertem Punkt ".0" aus "v10.0" und lieferte ""; erste Zahl nach "v")
        $vers = @($RestVersion.version | ForEach-Object { if ("$_" -match '^v?(\d+)') { [int]$Matches[1] } })

        [pscustomobject]@{
            Min = ($vers | Measure-Object -Minimum).Minimum
            Max = ($vers | Measure-Object -Maximum).Maximum
        }
    }
}

function Get-ArubaSWProductInfo {

    <#
        .SYNOPSIS
        Produktnummer und Produktname aus dem Switch-Status (internal)

        .DESCRIPTION
        Einzelner Switch: product_number und product_name des Status. Stack (ST_STACKED): Produktnummer der ersten Einheit,
        Produktnamen aller Einheiten mit Namen, durch ", " verbunden.
    #>

    [CmdletBinding()]
    [OutputType([pscustomobject])]
    Param(
        [Parameter(Mandatory = $true)]
        [PSObject]$SwitchStatus
    )

    Process {
        if ('ST_STACKED' -eq $SwitchStatus.switch_type) {
            if ( $SwitchStatus.blades.count -eq "1") {
                $product_number = $SwitchStatus.blades.product_number
            }
            else {
                $product_number = $SwitchStatus.blades.product_number[0]
            }

            $product_name = $NULL;
            foreach ($blades in $SwitchStatus.blades) {
                if ($blades.product_name) {
                    if ($product_name) {
                        $product_name += ", "
                    }
                    $product_name += $blades.product_name
                }
            }
        }
        else {
            $product_number = $SwitchStatus.product_number
            $product_name = $SwitchStatus.product_name
        }

        [pscustomobject]@{ ProductNumber = $product_number; ProductName = $product_name }
    }
}

function Get-ArubaSWMstpApiVersion {
    <#
    .SYNOPSIS
        REST-Version fuer die MSTP-Cmdlets: hoechstens 5.
    .DESCRIPTION
        Die Ressource /mstp gibt es nur in den REST-Versionen 1 bis 5. Ab v6 liefert der Switch 404 (am Testswitch
        JL357A, YC.16.11.0010, gemessen in I35). Eine niedrigere Standardversion der Verbindung bleibt erhalten.
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param([Parameter(Mandatory = $true)][PSObject]$Connection)
    [Math]::Min(5, [int]$Connection.api_version.cur)
}

function Get-ArubaSWDhcpRelayVlanApiVersion {
    <#
    .SYNOPSIS
        REST-Version fuer die DHCP-Relay-VLAN-Cmdlets: hoechstens 3.
    .DESCRIPTION
        Die Ressource /vlans/{id}/dhcp-relay gibt es nur in den REST-Versionen 1 bis 3. Ab v4 liefert der Switch 404 (am
        Testswitch JL357A, YC.16.11.0010, gemessen in I35). Eine niedrigere Standardversion der Verbindung bleibt erhalten.
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param([Parameter(Mandatory = $true)][PSObject]$Connection)
    [Math]::Min(3, [int]$Connection.api_version.cur)
}
