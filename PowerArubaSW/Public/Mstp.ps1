#
# Copyright 2026, PowerArubaSW contributors
# SPDX-License-Identifier: Apache-2.0
#
# MSTP (Multiple Spanning Tree Protocol, IEEE 802.1s) -- Family-Cmdlets
# fuer den globalen MSTP-Zustand und die per-Port-Konfiguration.
# Strukturelle Referenz: Public/STP.ps1 (Layout) + Public/Sntp.ps1 (moderner
# response.content-Stil + ValueFromPipelineByPropertyName). Eingefuehrt
# in Inkrement I20 (2026-06-01).

function Get-ArubaSWMstp {

    <#
        .SYNOPSIS
        Get global MSTP settings.

        .DESCRIPTION
        Reads GET /mstp. Returns the global MSTP attributes: is_mstp_enabled,
        region_name, region_revision, max_hops. Per-Port-Konfiguration ueber
        Get-ArubaSWMstpPort.

        .EXAMPLE
        Get-ArubaSWMstp
    #>

    [CmdletBinding()]
    Param(
        [Parameter (Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$connection = (Get-ArubaSWDefaultConnection)
    )

    Begin {
    }

    Process {

        $uri = "mstp"

        $response = Invoke-ArubaSWWebRequest -method "GET" -uri $uri -connection $connection -api_version (Get-ArubaSWMstpApiVersion -Connection $connection)

        $response.content | ConvertFrom-Json
    }

    End {
    }
}

function Set-ArubaSWMstp {

    <#
        .SYNOPSIS
        Update global MSTP settings.

        .DESCRIPTION
        Sends PUT /mstp. Partial-update-Pattern: nur explizit gesetzte
        Felder gehen in den Body. Globale Bridge-Settings wie max_hops
        gelten fuer die gesamte MST-Region.

        .EXAMPLE
        Set-ArubaSWMstp -is_mstp_enabled

        Enable MSTP globally.

        .EXAMPLE
        Set-ArubaSWMstp -region_name 'CORE' -region_revision 1 -max_hops 20

        Set the MST region identity + max hops in one call.
    #>

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    Param(
        [Parameter(Mandatory = $false)]
        [switch]$is_mstp_enabled,
        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]$region_name,
        [Parameter(Mandatory = $false)]
        [ValidateRange(0, 65535)]
        [int]$region_revision,
        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 40)]
        [int]$max_hops,
        [Parameter (Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$connection = (Get-ArubaSWDefaultConnection)
    )

    Begin {
    }

    Process {

        $uri = "mstp"

        $mstp = New-Object -TypeName PSObject

        if ($PsBoundParameters.ContainsKey('is_mstp_enabled')) {
            $mstp | Add-Member -name "is_mstp_enabled" -membertype NoteProperty -Value ([bool]$is_mstp_enabled)
        }
        if ($PsBoundParameters.ContainsKey('region_name')) {
            $mstp | Add-Member -name "region_name" -membertype NoteProperty -Value $region_name
        }
        if ($PsBoundParameters.ContainsKey('region_revision')) {
            $mstp | Add-Member -name "region_revision" -membertype NoteProperty -Value $region_revision
        }
        if ($PsBoundParameters.ContainsKey('max_hops')) {
            $mstp | Add-Member -name "max_hops" -membertype NoteProperty -Value $max_hops
        }

        if ($PSCmdlet.ShouldProcess($connection.server, 'Configure MSTP global')) {
            $response = Invoke-ArubaSWWebRequest -method "PUT" -body $mstp -uri $uri -connection $connection -api_version (Get-ArubaSWMstpApiVersion -Connection $connection)

            $response.content | ConvertFrom-Json
        }
    }

    End {
    }
}

function Get-ArubaSWMstpPort {

    <#
        .SYNOPSIS
        Get MSTP per-port configuration.

        .DESCRIPTION
        Ohne `-port_id`: GET /mstp/port -- liefert die gesamte Liste, unwrapt
        aus `mstp_port_element`. Mit `-port_id`: GET /mstp/port/<id> -- gibt
        die einzelne Port-Konfiguration zurueck.

        .EXAMPLE
        Get-ArubaSWMstpPort

        Alle Ports.

        .EXAMPLE
        Get-ArubaSWMstpPort -port_id 5
    #>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]$port_id,
        [Parameter (Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$connection = (Get-ArubaSWDefaultConnection)
    )

    Begin {
    }

    Process {

        if ($PsBoundParameters.ContainsKey('port_id')) {
            $uri = "mstp/port/${port_id}"
        }
        else {
            $uri = "mstp/port"
        }

        $response = Invoke-ArubaSWWebRequest -method "GET" -uri $uri -connection $connection -api_version (Get-ArubaSWMstpApiVersion -Connection $connection)
        $body = $response.content | ConvertFrom-Json

        if ($PsBoundParameters.ContainsKey('port_id')) {
            $body
        }
        else {
            $body.mstp_port_element
        }
    }

    End {
    }
}

function Set-ArubaSWMstpPort {

    <#
        .SYNOPSIS
        Update MSTP per-port configuration.

        .DESCRIPTION
        Sends PUT /mstp/port/<port_id> with admin_status and root_guard.
        Verified on the 2540 (YC.16.11, REST v5): the endpoint knows only id, admin_status and root_guard.
        The switch rejects a PUT unless BOTH fields are present and both are real booleans
        ("Insufficient paramaters", "Invalid root-guard type"), although it returns them as the strings
        "true"/"false". A field you do not pass is therefore filled from the current value of the port
        (one extra GET), so -root_guard alone changes only the root guard.
        The former -priority, -path_cost, -admin_edge_port and -bpdu_protection_enabled were unknown to this
        endpoint and were removed; priority, edge port and BPDU protection are set per port with
        Set-ArubaSWSTPPort. admin_status is the per-port MSTP switch and has no effect while MSTP is
        switched off globally.
        Accepts pipeline input by property name (id): Get-ArubaSWMstpPort -port_id 5 | Set-ArubaSWMstpPort -root_guard

        .EXAMPLE
        Set-ArubaSWMstpPort -port_id 5 -root_guard

        Switch the root guard on for port 5 and keep admin_status as it is.

        .EXAMPLE
        Set-ArubaSWMstpPort -port_id 5 -admin_status:$false -root_guard:$false

        Take port 5 out of MSTP and switch the root guard off.
    #>

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    Param(
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [Alias('id')]
        [string]$port_id,
        [Parameter(Mandatory = $false)]
        [switch]$admin_status,
        [Parameter(Mandatory = $false)]
        [switch]$root_guard,
        [Parameter (Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$connection = (Get-ArubaSWDefaultConnection)
    )

    Begin {
    }

    Process {

        $uri = "mstp/port/${port_id}"

        # Der Switch verlangt beide Felder in jedem PUT: fehlende aus dem aktuellen Zustand des Ports auffuellen.
        $current = $null
        if (-not ($PsBoundParameters.ContainsKey('admin_status') -and $PsBoundParameters.ContainsKey('root_guard'))) {
            $current = Get-ArubaSWMstpPort -port_id $port_id -connection $connection
        }
        $adminValue = $false
        $guardValue = $false
        if ($null -ne $current) {
            if ($current.PSObject.Properties['admin_status']) { $adminValue = ("$($current.admin_status)" -eq 'true') }
            if ($current.PSObject.Properties['root_guard']) { $guardValue = ("$($current.root_guard)" -eq 'true') }
        }
        if ($PsBoundParameters.ContainsKey('admin_status')) { $adminValue = [bool]$admin_status }
        if ($PsBoundParameters.ContainsKey('root_guard')) { $guardValue = [bool]$root_guard }

        $mp = New-Object -TypeName PSObject
        $mp | Add-Member -name "id" -membertype NoteProperty -Value $port_id
        $mp | Add-Member -name "admin_status" -membertype NoteProperty -Value $adminValue
        $mp | Add-Member -name "root_guard" -membertype NoteProperty -Value $guardValue

        if ($PSCmdlet.ShouldProcess($port_id, 'Configure MSTP port')) {
            $response = Invoke-ArubaSWWebRequest -method "PUT" -body $mp -uri $uri -connection $connection -api_version (Get-ArubaSWMstpApiVersion -Connection $connection)

            $response.content | ConvertFrom-Json
        }
    }

    End {
    }
}
