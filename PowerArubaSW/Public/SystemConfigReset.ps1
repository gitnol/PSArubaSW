#
# Copyright 2026, PowerArubaSW contributors
# SPDX-License-Identifier: Apache-2.0
#
# Reset-ArubaSWConfiguration -- Factory-Reset des Switches per
# POST /system/configuration-reset. Strukturell ein bewusster Klon des
# Restart-ArubaSWSystem-Patterns aus I15 (destruktives POST + ShouldProcess
# + ConfirmImpact='High' + leere-Response-Toleranz), ohne ParameterSet
# (Reset hat nur einen Pfad statt drei). Eingefuehrt in Inkrement I21.

function Reset-ArubaSWConfiguration {

    <#
        .SYNOPSIS
        Reset the switch configuration to factory defaults.

        .DESCRIPTION
        Sends POST /system/configuration-reset. Setzt die laufende
        Konfiguration auf den Werkszustand zurueck und startet anschliessend
        den Switch neu -- ALLE Konfigurationsaenderungen gehen verloren
        (VLANs, Ports, RADIUS-Server, IPs, ...). Die aktive REST-Session
        wird als Nebeneffekt ungueltig.

        ShouldProcess + ConfirmImpact='High' erzwingen einen Default-Prompt;
        in Scripts mit `-Confirm:$false` umgehen. Es gibt **kein**
        `-Force`-Switch -- ConfirmImpact='High' macht den Default-Prompt
        ohnehin scharf, eine zusaetzliche Force-Flag waere doppelt.

        .EXAMPLE
        Reset-ArubaSWConfiguration

        Setzt die Konfiguration zurueck -- prompt sich an, weil
        ConfirmImpact='High'.

        .EXAMPLE
        Reset-ArubaSWConfiguration -Confirm:$false

        Reset ohne interaktiven Prompt (fuer Bootstrap-Skripte).

        .NOTES
        Reset-Endpoint nimmt keinen Request-Body. Der Switch quittiert
        typischerweise mit leerem oder minimalem Body und startet sofort
        neu; Aufrufer muessen anschliessend `Connect-ArubaSW` erneut
        ausfuehren.
    #>

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    Param(
        [Parameter (Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$connection = (Get-ArubaSWDefaultConnection)
    )

    Begin {
    }

    Process {

        $uri = "system/configuration-reset"

        $shouldProcessTarget = "$($connection.server) (FACTORY DEFAULTS)"
        if ($PSCmdlet.ShouldProcess($shouldProcessTarget, 'Reset switch configuration to factory defaults')) {
            $response = Invoke-ArubaSWWebRequest -method "POST" -uri $uri -connection $connection

            if ($response.content) {
                $response.content | ConvertFrom-Json
            }
        }
    }

    End {
    }
}
