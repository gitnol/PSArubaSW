#
# Copyright 2026, PowerArubaSW contributors
# SPDX-License-Identifier: Apache-2.0
#

function Get-ArubaSWSntp {

    <#
        .SYNOPSIS
        Get global SNTP configuration.

        .DESCRIPTION
        Reads GET /system/sntp -- returns the global SNTP attributes
        (sntp_client_operation_mode, sntp_config_poll_interval). The list of configured SNTP servers
        is a separate endpoint -- see Get-ArubaSWSntpServer.

        .EXAMPLE
        Get-ArubaSWSntp

        Returns the current global SNTP configuration.
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

        $uri = "system/sntp"

        $response = Invoke-ArubaSWWebRequest -method "GET" -uri $uri -connection $connection

        $response.content | ConvertFrom-Json
    }

    End {
    }
}

function Set-ArubaSWSntp {

    <#
        .SYNOPSIS
        Configure global SNTP attributes.

        .DESCRIPTION
        Sends PUT /system/sntp with sntp_client_operation_mode
        (SNTP_UNICAST_MODE | SNTP_BROADCAST_MODE | SNTP_DHCP_MODE). The
        switch rejects a PUT without this field ("Missing mandatory
        parameter sntp_client_operation_mode"), so it is mandatory here.

        .EXAMPLE
        Set-ArubaSWSntp -sntp_client_operation_mode SNTP_UNICAST_MODE

        Use SNTP in unicast mode (servers from Add-ArubaSWSntpServer).

        .EXAMPLE
        Set-ArubaSWSntp -sntp_client_operation_mode SNTP_DHCP_MODE

        Take the SNTP server from DHCP.
    #>

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    Param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('SNTP_UNICAST_MODE', 'SNTP_BROADCAST_MODE', 'SNTP_DHCP_MODE')]
        [string]$sntp_client_operation_mode,
        [Parameter (Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$connection = (Get-ArubaSWDefaultConnection)
    )

    Begin {
    }

    Process {

        $uri = "system/sntp"

        $sntp = New-Object -TypeName PSObject
        $sntp | Add-Member -name "sntp_client_operation_mode" -membertype NoteProperty -Value $sntp_client_operation_mode

        if ($PSCmdlet.ShouldProcess($connection.server, 'Configure SNTP')) {
            $response = Invoke-ArubaSWWebRequest -method "PUT" -body $sntp -uri $uri -connection $connection

            $response.content | ConvertFrom-Json
        }
    }

    End {
    }
}

function Get-ArubaSWSntpServer {

    <#
        .SYNOPSIS
        Get configured SNTP servers.

        .DESCRIPTION
        Returns all configured SNTP servers, or filters client-side by
        -sntp_server_priority and/or -sntp_server_address (compared with
        the octets of the address object). Mirrors the
        pattern used by Get-ArubaSWVlansPorts (fetch-all-then-filter)
        rather than calling the per-key GET endpoint -- one network call
        for any query shape.

        .EXAMPLE
        Get-ArubaSWSntpServer

        List all configured SNTP servers.

        .EXAMPLE
        Get-ArubaSWSntpServer -sntp_server_priority 1

        Get the priority-1 SNTP server, if defined.

        .EXAMPLE
        Get-ArubaSWSntpServer -sntp_server_address 198.51.100.10

        Look up a server by its IP address.
    #>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 4)]
        [int]$sntp_server_priority,
        [Parameter(Mandatory = $false)]
        [string]$sntp_server_address,
        [Parameter (Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$connection = (Get-ArubaSWDefaultConnection)
    )

    Begin {
    }

    Process {

        $uri = "system/sntp_server"

        $response = Invoke-ArubaSWWebRequest -method "GET" -uri $uri -connection $connection
        $servers = ($response.content | ConvertFrom-Json).sntp_servers

        if ($PsBoundParameters.ContainsKey('sntp_server_priority')) {
            $servers = $servers | Where-Object { $_.sntp_server_priority -eq $sntp_server_priority }
        }

        if ($PsBoundParameters.ContainsKey('sntp_server_address')) {
            $servers = $servers | Where-Object { $_.sntp_server_address.octets -eq $sntp_server_address }
        }

        $servers
    }

    End {
    }
}

function Add-ArubaSWSntpServer {

    <#
        .SYNOPSIS
        Add a new SNTP server.

        .DESCRIPTION
        Sends POST /system/sntp_server. Priority is mandatory (the switch
        uses it as part of the composite primary key) and must be 1..4.
        The address must be an IP address (IPv4 or IPv6); the switch wants
        it as object {version, octets}, which this cmdlet builds.
        SNTP-Version defaults to 3 on the switch if not specified.

        .EXAMPLE
        Add-ArubaSWSntpServer -sntp_server_priority 1 -sntp_server_address 198.51.100.10

        Add a primary SNTP server.

        .EXAMPLE
        Add-ArubaSWSntpServer -sntp_server_priority 2 -sntp_server_address 198.51.100.11 -sntp_server_version 4

        Add a secondary SNTP server with explicit version.
    #>

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    Param(
        [Parameter(Mandatory = $true)]
        [ValidateRange(1, 4)]
        [int]$sntp_server_priority,
        [Parameter(Mandatory = $true)]
        [ipaddress]$sntp_server_address,
        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 7)]
        [int]$sntp_server_version,
        [Parameter (Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$connection = (Get-ArubaSWDefaultConnection)
    )

    Begin {
    }

    Process {

        $uri = "system/sntp_server"

        $server = New-Object -TypeName PSObject
        $server | Add-Member -name "sntp_server_priority" -membertype NoteProperty -Value $sntp_server_priority
        $ipVersion = if ($sntp_server_address.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetworkV6) { 'IAV_IP_V6' } else { 'IAV_IP_V4' }
        $address = [PSCustomObject]@{ version = $ipVersion; octets = $sntp_server_address.IPAddressToString }
        $server | Add-Member -name "sntp_server_address" -membertype NoteProperty -Value $address

        if ($PsBoundParameters.ContainsKey('sntp_server_version')) {
            $server | Add-Member -name "sntp_server_version" -membertype NoteProperty -Value $sntp_server_version
        }

        if ($PSCmdlet.ShouldProcess("$($address.octets) (priority $sntp_server_priority)", 'Add SNTP server')) {
            $response = Invoke-ArubaSWWebRequest -method "POST" -body $server -uri $uri -connection $connection

            $response.content | ConvertFrom-Json
        }
    }

    End {
    }
}

function Remove-ArubaSWSntpServer {

    <#
        .SYNOPSIS
        Remove an SNTP server by priority and address.

        .DESCRIPTION
        Sends DELETE /system/sntp_server/{priority}-{address}. The switch
        uses the composite "{priority}-{address}" tuple as primary key,
        so both parameters are mandatory.

        Accepts an SNTP-server object on the pipeline (one with
        sntp_server_priority and sntp_server_address properties; the address
        may be a plain string or the {version, octets} object returned by
        Get-ArubaSWSntpServer), so it
        composes with `Get-ArubaSWSntpServer | Remove-ArubaSWSntpServer`.

        .EXAMPLE
        Remove-ArubaSWSntpServer -sntp_server_priority 1 -sntp_server_address 198.51.100.10

        Remove priority-1 SNTP server.

        .EXAMPLE
        Get-ArubaSWSntpServer | Where-Object { $_.sntp_server_address -like '198.51.*' } | Remove-ArubaSWSntpServer -Confirm:$false

        Remove every SNTP server matching an address pattern.
    #>

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    Param(
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateRange(1, 4)]
        [int]$sntp_server_priority,
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$sntp_server_address,
        [Parameter (Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$connection = (Get-ArubaSWDefaultConnection)
    )

    Begin {
    }

    Process {

        if ($sntp_server_address -is [string]) { $address = $sntp_server_address } else { $address = $sntp_server_address.octets }

        $uri = "system/sntp_server/${sntp_server_priority}-${address}"

        if ($PSCmdlet.ShouldProcess("$address (priority $sntp_server_priority)", 'Remove SNTP server')) {
            $null = Invoke-ArubaSWWebRequest -method "DELETE" -uri $uri -connection $connection
        }
    }

    End {
    }
}
