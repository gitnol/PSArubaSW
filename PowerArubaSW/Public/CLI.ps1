#
# Copyright 2018, Alexis La Goutte <alexis dot lagoutte at gmail dot com>
# Copyright 2018, Cedric Moreau <moreaucedric0 at gmail dot com>
#
# SPDX-License-Identifier: Apache-2.0
#

function Get-ArubaSWCli {

    <#
        .SYNOPSIS
        Get the result of a cli command on ArubaOS Switch.

        .DESCRIPTION
        Get the result of a cli command.

        All configuration and execution commands in non-interactive mode are supported.
        crypto, copy, process-tracking, recopy, redo, repeat, session, end, print, terminal,
        logout, menu, page, restore, update, upgrade-software, return, setup, screen-length,
        vlan range and help commands are not supported.
        Testmode commands are not supported.
        All show commands are supported except show tech and show history

        .EXAMPLE
        Get-ArubaSWCli -cmd "Show running-config"

        This function give you the result (cmd, status, result, error_mesg...) of a cli command on the switch.

        .EXAMPLE
        Get-ArubaSWCli -cmd "Show running-config" -display_result

        This function give only ther esult of a cli command on the switch.

        .NOTES
        SECURITY (I9, 2026-05-27): this cmdlet forwards the raw -cmd string to
        the switch CLI without further validation beyond rejecting embedded
        newlines (which would be a multi-command injection). Build the -cmd
        argument ONLY from trusted input. Do NOT concatenate user-supplied
        strings (web form input, untrusted file content, ...) into -cmd;
        use Send-ArubaSWCliBatch with a fixed command list instead, and treat
        every CLI use as privileged operation on the switch.
    #>

    [CmdletBinding()]
    Param(
        [Parameter (Mandatory = $true, Position = 1)]
        [ValidateScript({
            if ($_ -match '[\r\n]') {
                throw 'Get-ArubaSWCli accepts a single command line; embedded newlines look like a multi-command injection. Use Send-ArubaSWCliBatch for multi-line CLI sequences.'
            }
            $true
        })]
        [string]$cmd,
        [Parameter (Mandatory = $false)]
        [switch]$display_result,
        [Parameter (Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$connection = (Get-ArubaSWDefaultConnection)
    )

    Begin {
    }

    Process {

        $uri = "cli"

        $run = New-Object -TypeName PSObject

        $run | Add-Member -name "cmd" -membertype NoteProperty -Value "$cmd"

        $response = Invoke-ArubaSWWebRequest -method "POST" -body $run -uri $uri -connection $connection

        $conf = ($response | ConvertFrom-Json)

        $result_base64_encoded = $conf.result_base64_encoded

        $result = [System.Convert]::FromBase64String($result_base64_encoded)

        $result = [System.Text.Encoding]::UTF8.GetString($result)

        $conf | Add-Member -name "result" -membertype NoteProperty -value $result

        if ($display_result) {
            #only display CLI output
            $conf.result
        }
        else {
            $conf
        }
    }

    End {
    }
}

function Send-ArubaSWCliBatch {

    <#
        .SYNOPSIS
        Send a cli batch command.

        .DESCRIPTION
        Send a cli batch command on Aruba OS Switch.
        All configuration commands in non-interactive mode  are supported. Exit, configure, erase, startup-config commands are supported.
        Crypto, show, execution and testmode commands are NOT supported.

        .EXAMPLE
        Send-ArubaSWCliBatch -command "interface 4 disable"

        Send a cli batch command (disable interface 4) on the switch, use Get-ArubaSWCliBatchStatus for get result

        .EXAMPLE
        Send-ArubaSWCliBatch -command "interface 4", "enable", "name PowerArubaSW-int"

        Send a cli batch command (disable interface 4) on the switch, use Get-ArubaSWCliBatchStatus for get result

        .NOTES
        SECURITY (I9, 2026-05-27): this cmdlet sends the -command array as a
        Base64-encoded CLI batch directly to the switch. The list is NOT
        validated; build it ONLY from trusted, hard-coded strings or from
        values you have authoritatively validated. NEVER interpolate user
        input (web form, untrusted file, environment variable) into a -command
        element. Every batch runs with the privileges of the connected switch
        account.
        #>

    [CmdletBinding()]
    Param(
        [Parameter (Mandatory = $true)]
        [string[]]$command,
        [Parameter (Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$connection = (Get-ArubaSWDefaultConnection)
    )

    Begin {
    }

    Process {

        $nb = 0
        $result = ""

        foreach ($line in $command) {
            $result = $result + $command[$nb] + "`n"
            $nb = $nb + 1
        }

        $uri = "cli_batch"

        $conf = New-Object -TypeName PSObject

        $encode = [System.Text.Encoding]::UTF8.GetBytes($result)

        $EncodedText = [Convert]::ToBase64String($encode)

        $conf | Add-Member -name "cli_batch_base64_encoded" -membertype NoteProperty -Value $EncodedText

        $response = Invoke-ArubaSWWebRequest -method "POST" -body $conf -uri $uri -connection $connection

        $run = $response | ConvertFrom-Json

        $run
    }

    End {
    }
}

function Get-ArubaSWCliBatchStatus {

    <#
        .SYNOPSIS
        Get a cli batch command status.

        .DESCRIPTION
        Get a cli batch command status on Aruba OS Switch.

        .EXAMPLE
        Get-ArubaSWCliBatchStatus

        Get a cli batch command status on the switch.
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

        $uri = "cli_batch/status"

        $response = Invoke-ArubaSWWebRequest -method "GET" -uri $uri -connection $connection

        $run = ($response | ConvertFrom-Json).cmd_exec_logs

        $run
    }

    End {
    }
}
