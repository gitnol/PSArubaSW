#
# Copyright 2026, PowerArubaSW contributors
# SPDX-License-Identifier: Apache-2.0
#
# Transceiver, SmartRate und Portspiegelung (lesend) (Inkrement I39). Felder und Verhalten stammen von einer 2540 (YC.16.11.0010), nicht aus der Spec.

function Get-ArubaSWTransceiver {

    <#
        .SYNOPSIS
        Get the installed transceivers.

        .DESCRIPTION
        Reads GET /transceivers (list) or /transceivers/<serial_number>. The test switch has no SFP inserted: the list is empty and an unknown serial number gives 404.

        .EXAMPLE
        Get-ArubaSWTransceiver
    #>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$serial_number,
        [Parameter (Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$connection = (Get-ArubaSWDefaultConnection)
    )

    Begin {
    }

    Process {
        if ($PsBoundParameters.ContainsKey('serial_number')) {
            Get-ArubaSWPortResource -Path "transceivers" -ElementName 'transceiver_element' -PortId $serial_number -Connection $connection
        }
        else {
            Get-ArubaSWPortResource -Path "transceivers" -ElementName 'transceiver_element' -Connection $connection
        }
    }

    End {
    }
}

function Get-ArubaSWTransceiverDiagnostics {

    <#
        .SYNOPSIS
        Get the diagnostics (DOM values) of a transceiver.

        .DESCRIPTION
        Reads GET /transceivers/<serial_number>/diagnostics. The test switch has no SFP inserted, so this call was only seen to answer 404 for an unknown serial number.

        .EXAMPLE
        Get-ArubaSWTransceiver | Get-ArubaSWTransceiverDiagnostics
    #>

    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseSingularNouns", "", Justification = "Name der REST-Ressource")]
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$serial_number,
        [Parameter (Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$connection = (Get-ArubaSWDefaultConnection)
    )

    Begin {
    }

    Process {
        $response = Invoke-ArubaSWWebRequest -method "GET" -uri "transceivers/${serial_number}/diagnostics" -connection $connection
        $response.content | ConvertFrom-Json
    }

    End {
    }
}

function Get-ArubaSWAllowUnsupportedTransceiver {

    <#
        .SYNOPSIS
        Get whether unsupported transceivers are allowed.

        .DESCRIPTION
        Reads GET /allow_unsupported_transceiver: is_allow_unsupported_transceiver_enabled.

        .EXAMPLE
        Get-ArubaSWAllowUnsupportedTransceiver
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
        $response = Invoke-ArubaSWWebRequest -method "GET" -uri "allow_unsupported_transceiver" -connection $connection
        $response.content | ConvertFrom-Json
    }

    End {
    }
}

function Set-ArubaSWAllowUnsupportedTransceiver {

    <#
        .SYNOPSIS
        Allow or forbid unsupported transceivers.

        .DESCRIPTION
        Sends PUT /allow_unsupported_transceiver. Verified on a 2540 (YC.16.11).

        .EXAMPLE
        Set-ArubaSWAllowUnsupportedTransceiver -is_allow_unsupported_transceiver_enabled
    #>

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    Param(
        [Parameter(Mandatory = $false)]
        [switch]$is_allow_unsupported_transceiver_enabled,
        [Parameter (Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$connection = (Get-ArubaSWDefaultConnection)
    )

    Begin {
    }

    Process {
        $changes = @{}
        if ($PsBoundParameters.ContainsKey('is_allow_unsupported_transceiver_enabled')) { $changes['is_allow_unsupported_transceiver_enabled'] = [bool]$is_allow_unsupported_transceiver_enabled }

        $uri = "allow_unsupported_transceiver"
        $body = Get-ArubaSWMergedBody -Uri $uri -Changes $changes -Connection $connection

        if ($PSCmdlet.ShouldProcess('allow_unsupported_transceiver', 'Allow or forbid unsupported transceivers')) {
            $response = Invoke-ArubaSWWebRequest -method "PUT" -body $body -uri $uri -connection $connection
            if ($response.content) {
                $response.content | ConvertFrom-Json
            }
        }
    }

    End {
    }
}

function Get-ArubaSWSmartrate {

    <#
        .SYNOPSIS
        Get the SmartRate settings of ports.

        .DESCRIPTION
        Reads GET /smartrate/ports (all SmartRate ports) or /smartrate/ports/<port_id>. A 2540 has no SmartRate ports: the list is empty and a port gives 404.

        .EXAMPLE
        Get-ArubaSWSmartrate
    #>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
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
            Get-ArubaSWPortResource -Path "smartrate/ports" -ElementName 'smartrate_port_element' -PortId $port_id -Connection $connection
        }
        else {
            Get-ArubaSWPortResource -Path "smartrate/ports" -ElementName 'smartrate_port_element' -Connection $connection
        }
    }

    End {
    }
}

function Get-ArubaSWPortMirror {

    <#
        .SYNOPSIS
        Get the port mirror sessions.

        .DESCRIPTION
        Reads GET /port-mirror (list) or /port-mirror/<session_id>. Each session has session_id (always 0 on a 2540, YC.16.11), destination_port_id
        (the mirror port, a string) and source_port_id (the monitored ports, an array of strings, may be empty).

        .EXAMPLE
        Get-ArubaSWPortMirror
    #>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$session_id,
        [Parameter (Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$connection = (Get-ArubaSWDefaultConnection)
    )

    Begin {
    }

    Process {
        if ($PsBoundParameters.ContainsKey('session_id')) {
            Get-ArubaSWPortResource -Path "port-mirror" -ElementName 'port_mirror_session_element' -PortId $session_id -Connection $connection
        }
        else {
            Get-ArubaSWPortResource -Path "port-mirror" -ElementName 'port_mirror_session_element' -Connection $connection
        }
    }

    End {
    }
}

function Add-ArubaSWPortMirror {

    <#
        .SYNOPSIS
        Add the port mirror session (monitor ports to a mirror port).

        .DESCRIPTION
        Sends POST /port-mirror with session_id, destination_port_id and source_port_id. Verified on a 2540 (YC.16.11): there is exactly one session
        with session_id 0 (1 to 4 answer "Invalid session id"); a second POST answers "Session Exists" (change it with Set-ArubaSWPortMirror). The
        field names of openapi.yaml (mirror_port, src_ports_ingress, ...) are wrong; the switch wants destination_port_id (string) and source_port_id
        (array of strings). Mirrors both directions; direction cannot be chosen. A mirror port copies the traffic of the source ports and should be
        a spare port. Never use the uplink or the port you are connected through.

        .EXAMPLE
        Add-ArubaSWPortMirror -destination_port_id 22 -source_port_id 21, 23
    #>

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    Param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$destination_port_id,
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [string[]]$source_port_id,
        [Parameter(Mandatory = $false)]
        [ValidateRange(0, 4)]
        [int]$session_id = 0,
        [Parameter (Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$connection = (Get-ArubaSWDefaultConnection)
    )

    Begin {
    }

    Process {
        $conf = New-Object -TypeName PSObject
        $conf | Add-Member -name "session_id" -MemberType NoteProperty -Value $session_id
        $conf | Add-Member -name "destination_port_id" -MemberType NoteProperty -Value $destination_port_id
        $conf | Add-Member -name "source_port_id" -MemberType NoteProperty -Value ([string[]]@($source_port_id))

        if ($PSCmdlet.ShouldProcess("session $session_id (mirror port $destination_port_id)", 'Add port mirror session')) {
            $response = Invoke-ArubaSWWebRequest -method "POST" -body $conf -uri "port-mirror" -connection $connection
            $response.content | ConvertFrom-Json
        }
    }

    End {
    }
}

function Set-ArubaSWPortMirror {

    <#
        .SYNOPSIS
        Change the monitored ports of a port mirror session.

        .DESCRIPTION
        Sends PUT /port-mirror/<session_id> with the complete object (the cmdlet reads the session first). Only the source ports can be changed: the
        switch answers a different destination_port_id with "Desintaion port cannot be changed via PUT" (remove the session and add it again). An empty
        -source_port_id removes all monitored ports and keeps the session. Verified on a 2540 (YC.16.11).

        .EXAMPLE
        Set-ArubaSWPortMirror -source_port_id 21, 23, 24
    #>

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    Param(
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [ValidateRange(0, 4)]
        [int]$session_id = 0,
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [string[]]$source_port_id,
        [Parameter (Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$connection = (Get-ArubaSWDefaultConnection)
    )

    Begin {
    }

    Process {
        $uri = "port-mirror/${session_id}"
        $body = Get-ArubaSWMergedBody -Uri $uri -Changes @{ source_port_id = [string[]]@($source_port_id) } -Connection $connection

        if ($PSCmdlet.ShouldProcess("session $session_id", 'Configure port mirror session')) {
            $response = Invoke-ArubaSWWebRequest -method "PUT" -body $body -uri $uri -connection $connection
            $response.content | ConvertFrom-Json
        }
    }

    End {
    }
}

function Remove-ArubaSWPortMirror {

    <#
        .SYNOPSIS
        Remove a port mirror session.

        .DESCRIPTION
        Sends DELETE /port-mirror/<session_id>; the mirror port and all monitored ports are released. Verified on a 2540 (YC.16.11).

        .EXAMPLE
        Remove-ArubaSWPortMirror

        .EXAMPLE
        Get-ArubaSWPortMirror | Remove-ArubaSWPortMirror
    #>

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    Param(
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [ValidateRange(0, 4)]
        [int]$session_id = 0,
        [Parameter (Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$connection = (Get-ArubaSWDefaultConnection)
    )

    Begin {
    }

    Process {
        if ($PSCmdlet.ShouldProcess("session $session_id", 'Remove port mirror session')) {
            $null = Invoke-ArubaSWWebRequest -method "DELETE" -uri "port-mirror/${session_id}" -connection $connection
        }
    }

    End {
    }
}
