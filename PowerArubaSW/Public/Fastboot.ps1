#
# Copyright 2026, PowerArubaSW contributors
# SPDX-License-Identifier: Apache-2.0
#

function Get-ArubaSWFastboot {

    <#
        .SYNOPSIS
        Get the fastboot setting of the switch.

        .DESCRIPTION
        Reads GET /fastboot -- returns `is_fastboot_enabled`. Fastboot shortens the boot
        process of the switch; what exactly is skipped depends on model and firmware
        (see the switch documentation).

        .EXAMPLE
        Get-ArubaSWFastboot

        Returns the current fastboot setting.
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

        $uri = "fastboot"

        $response = Invoke-ArubaSWWebRequest -method "GET" -uri $uri -connection $connection

        $response.content | ConvertFrom-Json
    }

    End {
    }
}

function Set-ArubaSWFastboot {

    <#
        .SYNOPSIS
        Enable or disable fastboot on the switch.

        .DESCRIPTION
        Sends PUT /fastboot. Partial-update-Pattern: nur explizit gesetzte
        Felder gehen in den Request-Body.

        .EXAMPLE
        Set-ArubaSWFastboot -is_fastboot_enabled:$true

        Enable fastboot (shorter boot).

        .EXAMPLE
        Set-ArubaSWFastboot -is_fastboot_enabled:$false

        Disable fastboot.
    #>

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    Param(
        [Parameter(Mandatory = $false)]
        [switch]$is_fastboot_enabled,
        [Parameter (Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$connection = (Get-ArubaSWDefaultConnection)
    )

    Begin {
    }

    Process {

        $uri = "fastboot"

        $fastboot = New-Object -TypeName PSObject

        if ($PsBoundParameters.ContainsKey('is_fastboot_enabled')) {
            $fastboot | Add-Member -name "is_fastboot_enabled" -membertype NoteProperty -Value ([bool]$is_fastboot_enabled)
        }

        if ($PSCmdlet.ShouldProcess($connection.server, 'Configure Fastboot')) {
            $response = Invoke-ArubaSWWebRequest -method "PUT" -body $fastboot -uri $uri -connection $connection

            $response.content | ConvertFrom-Json
        }
    }

    End {
    }
}
