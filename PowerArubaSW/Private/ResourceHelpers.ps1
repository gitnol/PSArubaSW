#
# Copyright 2026, PowerArubaSW contributors
# SPDX-License-Identifier: Apache-2.0
#

function Get-ArubaSWPortResource {
    <#
    .SYNOPSIS
        GET auf eine Ressource, die es als Liste und je Port gibt (z. B. dot1x/authenticator).
    .DESCRIPTION
        Ohne PortId wird die Liste ausgepackt (Feld $ElementName der Antwort), mit PortId kommt das einzelne Objekt.
        Suffix haengt Unterpfade an (dot1x/authenticator + /status = Liste dot1x/authenticator/status bzw. je Port
        dot1x/authenticator/<id>/status).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$ElementName,
        [Parameter(Mandatory = $false)][string]$PortId,
        [Parameter(Mandatory = $false)][string]$Suffix = '',
        [Parameter(Mandatory = $true)][PSObject]$Connection
    )

    if ($PSBoundParameters.ContainsKey('PortId')) {
        $response = Invoke-ArubaSWWebRequest -method "GET" -uri "$Path/$PortId$Suffix" -connection $Connection
        return ($response.content | ConvertFrom-Json)
    }

    $response = Invoke-ArubaSWWebRequest -method "GET" -uri "$Path$Suffix" -connection $Connection
    $body = $response.content | ConvertFrom-Json
    if ($body.PSObject.Properties[$ElementName]) { $body.$ElementName }
}

function Get-ArubaSWMergedBody {
    <#
    .SYNOPSIS
        Aktuellen Zustand lesen und die geaenderten Felder einarbeiten (Grundlage fuer ein vollstaendiges PUT).
    .DESCRIPTION
        Der Switch nimmt bei vielen Ressourcen nur vollstaendige Objekte an. Der Helfer liest den aktuellen Zustand
        (GET), ueberschreibt die Felder aus Changes und entfernt das schreibgeschuetzte Feld `uri`. Felder in
        OmitUnlessChanged (z. B. ein Kennwort, das der Switch nur als Platzhalter liefert) gehen nur mit, wenn der
        Aufrufer sie in Changes setzt. Das PUT und die Rueckfrage (-WhatIf/-Confirm) macht das aufrufende Cmdlet.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $true)][string]$Uri,
        [Parameter(Mandatory = $true)][hashtable]$Changes,
        [Parameter(Mandatory = $false)][string[]]$OmitUnlessChanged = @(),
        [Parameter(Mandatory = $true)][PSObject]$Connection
    )

    $current = (Invoke-ArubaSWWebRequest -method "GET" -uri $Uri -connection $Connection).content | ConvertFrom-Json
    $body = [ordered]@{}
    foreach ($p in $current.PSObject.Properties) {
        if ($p.Name -ne 'uri' -and $p.Name -notin $OmitUnlessChanged) { $body[$p.Name] = $p.Value }
    }
    foreach ($k in $Changes.Keys) { $body[$k] = $Changes[$k] }
    [pscustomobject]$body
}
