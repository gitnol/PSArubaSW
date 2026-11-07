#
# Copyright 2026, PowerArubaSW contributors
# SPDX-License-Identifier: Apache-2.0
#

function Restart-ArubaSWSystem {

    <#
        .SYNOPSIS
        Reboot the switch (standalone switch, standby, or a specific stack member).

        .DESCRIPTION
        Without -Standby and -member_id the cmdlet sends `POST /system/reboot` with the body `{"boot_image": "..."}`. This is the reboot of a
        standalone switch and the form verified on a 2540 (YC.16.11): the switch restarts from the image given in -boot_image
        (BI_PRIMARY_IMAGE or BI_SECONDARY_IMAGE; `show flash` in the CLI tells which one is the default). The call does not return normally
        because the switch goes down; expect a timeout or a connection error and re-connect after about 3 minutes.

        - `-Standby`: `POST /system/reboot/standby`, only on stacked switches with an active standby.
        - `-member_id`: `POST /system/reboot/member/{memberId}`, one specific stack member.

        The two stack endpoints are taken from the spec and were not tried (they answer 404 on a 2540).

        This is a HARD reboot of switch hardware; the active REST session is invalidated as a side effect. ShouldProcess + ConfirmImpact='High'
        force a confirmation prompt by default; pass -Confirm:$false to suppress in scripts.

        .EXAMPLE
        Restart-ArubaSWSystem -boot_image BI_SECONDARY_IMAGE

        Reboots the switch from its secondary image.

        .EXAMPLE
        Restart-ArubaSWSystem -Standby -Confirm:$false

        Reboot the standby member without interactive confirmation.

        .EXAMPLE
        Restart-ArubaSWSystem -member_id 2 -Confirm:$false

        Reboot stack member 2.

        .NOTES
        Verified on a 2540 (YC.16.11.0010, I46): /system/reboot/commander answers 404 there; `POST /system/reboot` with
        {"boot_image": "BI_SECONDARY_IMAGE"} rebooted the switch (uptime 3 minutes afterwards). Without a body or with other field names the
        switch answers 400 "Invalid request". The configuration is not saved by the reboot: unsaved changes are lost (Save-ArubaSWConfig first).
    #>

    [CmdletBinding(DefaultParameterSetName = 'Switch', SupportsShouldProcess, ConfirmImpact = 'High')]
    Param(
        [Parameter(Mandatory = $true, ParameterSetName = 'Switch')]
        [ValidateSet('BI_PRIMARY_IMAGE', 'BI_SECONDARY_IMAGE')]
        [string]$boot_image,
        [Parameter(Mandatory = $false, ParameterSetName = 'Standby')]
        [switch]$Standby,
        [Parameter(Mandatory = $true, ParameterSetName = 'Member')]
        [ValidateRange(1, 16)]
        [int]$member_id,
        [Parameter (Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$connection = (Get-ArubaSWDefaultConnection)
    )

    Begin {
    }

    Process {

        # $Standby is used implicitly via ParameterSetName routing; this line
        # tells PSReviewUnusedParameter that the binding is intentional.
        [void]$Standby

        $body = $null
        switch ($PSCmdlet.ParameterSetName) {
            'Standby' { $uri = "system/reboot/standby"; $target = 'standby' }
            'Member'  { $uri = "system/reboot/member/${member_id}"; $target = "member $member_id" }
            default {
                $uri = "system/reboot"
                $target = "boot from $boot_image"
                $body = New-Object -TypeName PSObject
                $body | Add-Member -name "boot_image" -MemberType NoteProperty -Value $boot_image
            }
        }

        $shouldProcessTarget = "$($connection.server) ($target)"
        if ($PSCmdlet.ShouldProcess($shouldProcessTarget, 'Reboot switch')) {
            if ($body) {
                $response = Invoke-ArubaSWWebRequest -method "POST" -uri $uri -body $body -connection $connection
            }
            else {
                $response = Invoke-ArubaSWWebRequest -method "POST" -uri $uri -connection $connection
            }

            if ($response.content) {
                $response.content | ConvertFrom-Json
            }
        }
    }

    End {
    }
}
