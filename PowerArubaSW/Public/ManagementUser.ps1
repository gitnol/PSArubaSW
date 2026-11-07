#
# Copyright 2026, PowerArubaSW contributors
# SPDX-License-Identifier: Apache-2.0
#
# Verwaltungsbenutzer (Inkrement I39). Felder und Verhalten stammen von einer 2540 (YC.16.11.0010), nicht aus der Spec.

function Get-ArubaSWManagementUser {

    <#
        .SYNOPSIS
        Get the local management users (manager and operator).

        .DESCRIPTION
        Reads GET /management-user (list) or /management-user/<type>. The switch knows one user per type (UT_MANAGER, UT_OPERATOR); the password is
        always returned as "******". A switch without an operator user answers 404 for UT_OPERATOR.

        .EXAMPLE
        Get-ArubaSWManagementUser

        .EXAMPLE
        Get-ArubaSWManagementUser -type UT_MANAGER
    #>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [ValidateSet('UT_MANAGER', 'UT_OPERATOR')]
        [string]$type,
        [Parameter (Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$connection = (Get-ArubaSWDefaultConnection)
    )

    Begin {
    }

    Process {
        if ($PsBoundParameters.ContainsKey('type')) {
            Get-ArubaSWPortResource -Path "management-user" -ElementName 'device_management_user_element' -PortId $type -Connection $connection
        }
        else {
            Get-ArubaSWPortResource -Path "management-user" -ElementName 'device_management_user_element' -Connection $connection
        }
    }

    End {
    }
}

function Add-ArubaSWManagementUser {

    <#
        .SYNOPSIS
        Add (or replace) a local management user.

        .DESCRIPTION
        Sends POST /management-user with type, name, password and password_type PET_PLAIN_TEXT. The password is a SecureString and is sent in clear text in
        the request. Verified on a 2540 (YC.16.11) with UT_OPERATOR: the switch keeps one user per type, a second POST for the same type REPLACES the user.
        Do not use UT_MANAGER on a switch you reach with that account: the new password applies at once.

        .EXAMPLE
        Add-ArubaSWManagementUser -type UT_OPERATOR -name viewer -password (Read-Host -AsSecureString)
    #>

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    Param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('UT_MANAGER', 'UT_OPERATOR')]
        [string]$type,
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$name,
        [Parameter(Mandatory = $true)]
        [securestring]$password,
        [Parameter (Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$connection = (Get-ArubaSWDefaultConnection)
    )

    Begin {
    }

    Process {
        $conf = [pscustomobject]@{
            type          = $type
            name          = $name
            password      = [System.Net.NetworkCredential]::new('', $password).Password
            password_type = 'PET_PLAIN_TEXT'
        }

        if ($PSCmdlet.ShouldProcess("$type $name", 'Add management user')) {
            $response = Invoke-ArubaSWWebRequest -method "POST" -body $conf -uri "management-user" -connection $connection
            $response.content | ConvertFrom-Json
        }
    }

    End {
    }
}

function Set-ArubaSWManagementUser {

    <#
        .SYNOPSIS
        Change the password of a local management user.

        .DESCRIPTION
        Sends PUT /management-user/<type> with name, password and password_type PET_PLAIN_TEXT (the switch needs all of them, otherwise "Insufficient Parameters").
        Without -name the current user name is kept. The new password applies at once, also for the account you are connected with.

        .EXAMPLE
        Set-ArubaSWManagementUser -type UT_OPERATOR -password (Read-Host -AsSecureString)
    #>

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    Param(
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateSet('UT_MANAGER', 'UT_OPERATOR')]
        [string]$type,
        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]$name,
        [Parameter(Mandatory = $true)]
        [securestring]$password,
        [Parameter (Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$connection = (Get-ArubaSWDefaultConnection)
    )

    Begin {
    }

    Process {
        $uri = "management-user/${type}"
        if (-not $PsBoundParameters.ContainsKey('name')) {
            $name = ((Invoke-ArubaSWWebRequest -method "GET" -uri $uri -connection $connection).content | ConvertFrom-Json).name
        }
        $conf = [pscustomobject]@{
            type          = $type
            name          = $name
            password      = [System.Net.NetworkCredential]::new('', $password).Password
            password_type = 'PET_PLAIN_TEXT'
        }

        if ($PSCmdlet.ShouldProcess("$type $name", 'Change management user password')) {
            $response = Invoke-ArubaSWWebRequest -method "PUT" -body $conf -uri $uri -connection $connection
            $response.content | ConvertFrom-Json
        }
    }

    End {
    }
}

function Remove-ArubaSWManagementUser {

    <#
        .SYNOPSIS
        Remove a local management user.

        .DESCRIPTION
        Sends DELETE /management-user/<type>. Verified on a 2540 (YC.16.11) with UT_OPERATOR. Removing UT_MANAGER was not tried: it is the account the switch is managed with.

        .EXAMPLE
        Remove-ArubaSWManagementUser -type UT_OPERATOR
    #>

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    Param(
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateSet('UT_MANAGER', 'UT_OPERATOR')]
        [string]$type,
        [Parameter (Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$connection = (Get-ArubaSWDefaultConnection)
    )

    Begin {
    }

    Process {
        if ($PSCmdlet.ShouldProcess($type, 'Remove management user')) {
            $null = Invoke-ArubaSWWebRequest -method "DELETE" -uri "management-user/${type}" -connection $connection
        }
    }

    End {
    }
}
