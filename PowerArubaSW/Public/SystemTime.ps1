#
# Copyright 2026, PowerArubaSW contributors
# SPDX-License-Identifier: Apache-2.0
#

function Get-ArubaSWSystemTime {

    <#
        .SYNOPSIS
        Get system time configuration.

        .DESCRIPTION
        Reads GET /system/time -- returns the global system time configuration
        (time_zone, system_time).

        .EXAMPLE
        Get-ArubaSWSystemTime

        Returns the current system time and time zone.
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

        $uri = "system/time"

        $response = Invoke-ArubaSWWebRequest -method "GET" -uri $uri -connection $connection

        $response.content | ConvertFrom-Json
    }

    End {
    }
}

function Set-ArubaSWSystemTime {

    <#
        .SYNOPSIS
        Update system time configuration.

        .DESCRIPTION
        Sends PUT /system/time with -local_utc_offset_in_seconds and/or -auto_adjust_dst.
        Fields on the 2540 (YC.16.11): local_utc_offset_in_seconds (3600 for CET), auto_adjust_dst,
        use_sntp_unicast, time_server_protocol and the read-only list time_servers. The former
        -time_zone and -system_time were unknown to the switch ("Atleast one parameter should be
        present") and were removed. The switch rejects auto_adjust_dst while no daylight-saving
        begin and end rule exists ("Auto adjust DST without DST end and DST begin Rule").
        Setting the clock itself is done with Set-ArubaSWSystemTimeManually.

        .EXAMPLE
        Set-ArubaSWSystemTime -local_utc_offset_in_seconds 3600

        Set the time zone to UTC+1.

        .EXAMPLE
        Set-ArubaSWSystemTime -local_utc_offset_in_seconds 0 -auto_adjust_dst:$false

        UTC without daylight-saving adjustment.
    #>

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    Param(
        [Parameter(Mandatory = $false)]
        [ValidateRange(-43200, 50400)]
        [int]$local_utc_offset_in_seconds,
        [Parameter(Mandatory = $false)]
        [switch]$auto_adjust_dst,
        [Parameter (Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$connection = (Get-ArubaSWDefaultConnection)
    )

    Begin {
    }

    Process {

        $uri = "system/time"

        $sysTime = New-Object -TypeName PSObject

        if ($PsBoundParameters.ContainsKey('local_utc_offset_in_seconds')) {
            $sysTime | Add-Member -name "local_utc_offset_in_seconds" -membertype NoteProperty -Value $local_utc_offset_in_seconds
        }

        if ($PsBoundParameters.ContainsKey('auto_adjust_dst')) {
            $sysTime | Add-Member -name "auto_adjust_dst" -membertype NoteProperty -Value ([bool]$auto_adjust_dst)
        }

        if ($PSCmdlet.ShouldProcess($connection.server, 'Configure System Time')) {
            $response = Invoke-ArubaSWWebRequest -method "PUT" -body $sysTime -uri $uri -connection $connection
            if ($response.content) {
                $response.content | ConvertFrom-Json
            }
        }
    }

    End {
    }
}

function Set-ArubaSWSystemTimeManually {

    <#
        .SYNOPSIS
        Set system date/time manually.

        .DESCRIPTION
        Sends POST /system/time/setmanually. Requires date and time strings.

        .EXAMPLE
        Set-ArubaSWSystemTimeManually -date "01/01/2026" -time "12:00:00"

        Set the date and time manually.
    #>

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    Param(
        [Parameter(Mandatory = $true)]
        [string]$date,
        [Parameter(Mandatory = $true)]
        [string]$time,
        [Parameter (Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$connection = (Get-ArubaSWDefaultConnection)
    )

    Begin {
    }

    Process {

        $uri = "system/time/setmanually"

        $payload = New-Object -TypeName PSObject
        $payload | Add-Member -name "date" -membertype NoteProperty -Value $date
        $payload | Add-Member -name "time" -membertype NoteProperty -Value $time

        if ($PSCmdlet.ShouldProcess($connection.server, 'Set System Time Manually')) {
            $response = Invoke-ArubaSWWebRequest -method "POST" -body $payload -uri $uri -connection $connection

            if ($response.content) {
                $response.content | ConvertFrom-Json
            }
        }
    }

    End {
    }
}
