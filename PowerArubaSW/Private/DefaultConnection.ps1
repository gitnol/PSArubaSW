#
# Copyright 2026, PowerArubaSW contributors
# SPDX-License-Identifier: Apache-2.0
#

function Get-ArubaSWDefaultConnection {

    <#
        .SYNOPSIS
        Return the default connection ($DefaultArubaSWConnection) or $null (internal)

        .DESCRIPTION
        Connect-ArubaSW stores the default connection in the global variable
        $DefaultArubaSWConnection, Disconnect-ArubaSW removes it again. Under Strict Mode
        reading a variable that does not exist is an error, so the cmdlets read it through
        this helper (default value of -connection) and get $null when nobody is connected.

        .EXAMPLE
        Get-ArubaSWDefaultConnection

        Return the default connection, or $null when not connected
    #>

    [CmdletBinding()]
    Param()

    Process {
        Get-Variable -Name DefaultArubaSWConnection -Scope Global -ValueOnly -ErrorAction SilentlyContinue
    }
}
