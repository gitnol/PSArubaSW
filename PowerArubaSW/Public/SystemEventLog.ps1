#
# Copyright 2026, PowerArubaSW contributors
# SPDX-License-Identifier: Apache-2.0
#

function Get-ArubaSWSystemEventLog {

    <#
        .SYNOPSIS
        Get the event log of the switch.

        .DESCRIPTION
        Reads GET /system-event-log (REST v3 and later) and returns the entries from device_event_element, newest first:
        event_type, syslog_message and event_data (event_id, severity, system_module, date_time).
        The switch knows only the query parameter count (verified on a 2540); every other parameter, including the
        filter named in the REST reference, is accepted but returns an EMPTY list. Severity, module and time are
        therefore filtered here, after the switch has answered. -Count limits the number of entries at the switch
        and should be combined with the filters only when the filtered result is expected to be in the newest entries.

        .EXAMPLE
        Get-ArubaSWSystemEventLog -Count 20

        The 20 newest entries.

        .EXAMPLE
        Get-ArubaSWSystemEventLog -Severity WARNING, ERROR

        All entries with severity WARNING or ERROR.

        .EXAMPLE
        Get-ArubaSWSystemEventLog -Module MGR -Since (Get-Date).AddHours(-1)

        Entries of the management module in the last hour.
    #>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 100000)]
        [int]$Count,
        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string[]]$Severity,
        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string[]]$Module,
        [Parameter(Mandatory = $false)]
        [datetime]$Since,
        [Parameter (Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$connection = (Get-ArubaSWDefaultConnection)
    )

    Begin {
    }

    Process {

        $uri = "system-event-log"
        if ($PsBoundParameters.ContainsKey('Count')) {
            $uri += "?count=$Count"
        }

        $response = Invoke-ArubaSWWebRequest -method "GET" -uri $uri -connection $connection
        $body = $response.content | ConvertFrom-Json

        $entries = @()
        if ($body.PSObject.Properties['device_event_element']) {
            $entries = @($body.device_event_element)
        }

        if ($PsBoundParameters.ContainsKey('Severity')) {
            $entries = @($entries | Where-Object { $_.event_data.severity -in $Severity })
        }
        if ($PsBoundParameters.ContainsKey('Module')) {
            $entries = @($entries | Where-Object { $_.event_data.system_module -in $Module })
        }
        if ($PsBoundParameters.ContainsKey('Since')) {
            $limit = [DateTimeOffset]::new($Since.ToUniversalTime()).ToUnixTimeSeconds()
            $entries = @($entries | Where-Object { $_.event_data.date_time.seconds_since_unix_epoch -ge $limit })
        }

        $entries
    }

    End {
    }
}
