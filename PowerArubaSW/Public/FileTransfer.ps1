#
# Copyright 2026, PowerArubaSW contributors
# SPDX-License-Identifier: Apache-2.0
#
# Dateiuebertragung (Inkrement I41). Felder und Verhalten stammen von einer 2540 (YC.16.11.0010), nicht aus der Spec.

function Start-ArubaSWFileTransfer {

    <#
        .SYNOPSIS
        Start a file transfer between the switch and a web server (config backup, firmware, show tech).

        .DESCRIPTION
        Sends POST /file-transfer with url, file_type and action. The switch itself talks to the server, so the server must be reachable from the
        switch and accept the transfer: an upload is an HTTP PUT with the file as body (chunked, Expect: 100-continue), a download is an HTTP GET.
        The call only starts the transfer ("File transfer initiated") and returns at once; the result is in the event log
        (Get-ArubaSWSystemEventLog: "Upload of ... completed successfully" or "Connection to ... failed"). Only one transfer runs at a time, a second
        one is rejected with "Another download is in progress" until the first has ended (an unreachable server takes about 3 minutes).

        Verified on a 2540 (YC.16.11): file_type FTT_CONFIG, FTT_FIRMWARE and FTT_SHOW_TECH are accepted, all others are rejected ("Invalid file_type");
        action FTA_UPLOAD (switch sends the file to the server, harmless) and FTA_DOWNLOAD (switch fetches the file from the server and installs it);
        of the URL schemes only http:// is accepted (tftp, sftp, scp, ftp and plain host names: "The source specified is not a valid URL").
        An upload of FTT_CONFIG delivered the startup configuration (without the passwords). FTA_DOWNLOAD was not tried: it replaces the configuration
        or the firmware of the switch.

        .EXAMPLE
        Start-ArubaSWFileTransfer -action FTA_UPLOAD -file_type FTT_CONFIG -url http://192.0.2.50:8080/switch-config.cfg

        .EXAMPLE
        Start-ArubaSWFileTransfer -action FTA_UPLOAD -file_type FTT_SHOW_TECH -url http://192.0.2.50:8080/show-tech.txt
    #>

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    Param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('FTA_UPLOAD', 'FTA_DOWNLOAD')]
        [string]$action,
        [Parameter(Mandatory = $true)]
        [ValidateSet('FTT_CONFIG', 'FTT_FIRMWARE', 'FTT_SHOW_TECH')]
        [string]$file_type,
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$url,
        [Parameter (Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$connection = (Get-ArubaSWDefaultConnection)
    )

    Begin {
    }

    Process {
        $conf = New-Object -TypeName PSObject
        $conf | Add-Member -name "url" -MemberType NoteProperty -Value $url
        $conf | Add-Member -name "file_type" -MemberType NoteProperty -Value $file_type
        $conf | Add-Member -name "action" -MemberType NoteProperty -Value $action

        if ($PSCmdlet.ShouldProcess($url, "$action $file_type")) {
            $response = Invoke-ArubaSWWebRequest -method "POST" -body $conf -uri "file-transfer" -connection $connection
            $response.content | ConvertFrom-Json
        }
    }

    End {
    }
}
