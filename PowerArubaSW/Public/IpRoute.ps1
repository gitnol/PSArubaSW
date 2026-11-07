#
# Copyright 2026, PowerArubaSW contributors
# SPDX-License-Identifier: Apache-2.0
#
# Statische IP-Routen (Inkrement I40). Felder und Verhalten stammen von einer 2540 (YC.16.11.0010), nicht aus der Spec.

function Get-ArubaSWIpRoute {

    <#
        .SYNOPSIS
        Get the IP routes (static, default route).

        .DESCRIPTION
        Reads GET /ip-route (list) or /ip-route/<id>. The id has the form <destination>-<mask>-<mode>-<gateway>, for the default route
        0.0.0.0-0.0.0.0-IRM_GATEWAY-198.51.100.254, for a reject route 203.0.113.0-255.255.255.0-IRM_REJECT.
        Each route has destination, mask, ip_route_mode, gateway, destination_vlan, metric, distance, name, tag.

        .EXAMPLE
        Get-ArubaSWIpRoute

        .EXAMPLE
        Get-ArubaSWIpRoute -id 0.0.0.0-0.0.0.0-IRM_GATEWAY-198.51.100.254
    #>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$id,
        [Parameter (Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$connection = (Get-ArubaSWDefaultConnection)
    )

    Begin {
    }

    Process {
        if ($PsBoundParameters.ContainsKey('id')) {
            Get-ArubaSWPortResource -Path "ip-route" -ElementName 'ip_route_element' -PortId $id -Connection $connection
        }
        else {
            Get-ArubaSWPortResource -Path "ip-route" -ElementName 'ip_route_element' -Connection $connection
        }
    }

    End {
    }
}

function Add-ArubaSWIpRoute {

    <#
        .SYNOPSIS
        Add a static IP route.

        .DESCRIPTION
        Sends POST /ip-route with destination, mask, ip_route_mode and gateway. Give the next hop with -gateway (IRM_GATEWAY) or use -reject
        (IRM_REJECT, no gateway). Verified on a 2540 (YC.16.11): the switch needs ip_route_mode ("IP route mode cannot be NULL"), accepts IRM_GATEWAY
        and IRM_REJECT, rejects IRM_BLACKHOLE and unknown names ("Invalid IP route mode") and accepts a gateway outside the connected networks.
        Several routes to the same destination with different gateways can exist. -metric, -distance, -name and -tag are optional (defaults: metric 1,
        distance 1, no name, no tag). A routing change can cut the connection to the switch.

        .EXAMPLE
        Add-ArubaSWIpRoute -destination 203.0.113.0 -prefix_length 24 -gateway 198.51.100.254

        .EXAMPLE
        Add-ArubaSWIpRoute -destination 203.0.113.0 -mask 255.255.255.0 -reject
    #>

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High', DefaultParameterSetName = 'mask')]
    Param(
        [Parameter(Mandatory = $true)]
        [ipaddress]$destination,
        [Parameter(Mandatory = $true, ParameterSetName = 'mask')]
        [ipaddress]$mask,
        [Parameter(Mandatory = $true, ParameterSetName = 'prefix')]
        [ValidateRange(0, 32)]
        [int]$prefix_length,
        [Parameter(Mandatory = $false)]
        [ipaddress]$gateway,
        [Parameter(Mandatory = $false)]
        [switch]$reject,
        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 255)]
        [int]$metric,
        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 255)]
        [int]$distance,
        [Parameter(Mandatory = $false)]
        [string]$name,
        [Parameter(Mandatory = $false)]
        [int]$tag,
        [Parameter (Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$connection = (Get-ArubaSWDefaultConnection)
    )

    Begin {
    }

    Process {
        if ([bool]$reject -eq $PsBoundParameters.ContainsKey('gateway')) {
            throw "Give either -gateway or -reject."
        }
        if ($PSCmdlet.ParameterSetName -eq 'prefix') {
            $bits = ('1' * $prefix_length).PadRight(32, '0')
            $maskText = (0, 8, 16, 24 | ForEach-Object { [Convert]::ToInt32($bits.Substring($_, 8), 2) }) -join '.'
        }
        else {
            $maskText = $mask.ToString()
        }

        $conf = New-Object -TypeName PSObject
        $conf | Add-Member -name "destination" -MemberType NoteProperty -Value ([pscustomobject]@{ version = 'IAV_IP_V4'; octets = $destination.ToString() })
        $conf | Add-Member -name "mask" -MemberType NoteProperty -Value ([pscustomobject]@{ version = 'IAV_IP_V4'; octets = $maskText })
        if ($reject) {
            $conf | Add-Member -name "ip_route_mode" -MemberType NoteProperty -Value "IRM_REJECT"
            $via = 'reject'
        }
        else {
            $conf | Add-Member -name "ip_route_mode" -MemberType NoteProperty -Value "IRM_GATEWAY"
            $conf | Add-Member -name "gateway" -MemberType NoteProperty -Value ([pscustomobject]@{ version = 'IAV_IP_V4'; octets = $gateway.ToString() })
            $via = "via $($gateway.ToString())"
        }
        foreach ($f in 'metric', 'distance', 'name', 'tag') {
            if ($PsBoundParameters.ContainsKey($f)) { $conf | Add-Member -name $f -MemberType NoteProperty -Value $PsBoundParameters[$f] }
        }

        if ($PSCmdlet.ShouldProcess("$($destination.ToString())/$maskText $via", 'Add IP route')) {
            $response = Invoke-ArubaSWWebRequest -method "POST" -body $conf -uri "ip-route" -connection $connection
            $response.content | ConvertFrom-Json
        }
    }

    End {
    }
}

function Remove-ArubaSWIpRoute {

    <#
        .SYNOPSIS
        Remove an IP route.

        .DESCRIPTION
        Sends DELETE /ip-route/<id>. Pass the id (<destination>-<mask>-<mode>-<gateway>) or pipe the route from Get-ArubaSWIpRoute.
        Verified on a 2540 (YC.16.11). Removing the default route cuts off every network behind the gateway, possibly also the connection to the switch.

        .EXAMPLE
        Remove-ArubaSWIpRoute -id 203.0.113.0-255.255.255.0-IRM_GATEWAY-198.51.100.254

        .EXAMPLE
        Get-ArubaSWIpRoute | Where-Object { $_.destination.octets -eq '203.0.113.0' } | Remove-ArubaSWIpRoute
    #>

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    Param(
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$id,
        [Parameter (Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$connection = (Get-ArubaSWDefaultConnection)
    )

    Begin {
    }

    Process {
        if ($PSCmdlet.ShouldProcess($id, 'Remove IP route')) {
            $null = Invoke-ArubaSWWebRequest -method "DELETE" -uri "ip-route/${id}" -connection $connection
        }
    }

    End {
    }
}

function Get-ArubaSWIpRouteSettings {

    <#
        .SYNOPSIS
        Get the global routing settings.

        .DESCRIPTION
        Reads GET /ip-route/settings: is_ip_routing_enable and is_ip_source_routing_enable (the REST names have no "d").

        .EXAMPLE
        Get-ArubaSWIpRouteSettings
    #>

    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseSingularNouns", "", Justification = "Name der REST-Ressource")]
    [CmdletBinding()]
    Param(
        [Parameter (Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$connection = (Get-ArubaSWDefaultConnection)
    )

    Begin {
    }

    Process {
        $response = Invoke-ArubaSWWebRequest -method "GET" -uri "ip-route/settings" -connection $connection
        $response.content | ConvertFrom-Json
    }

    End {
    }
}

function Set-ArubaSWIpRouteSettings {

    <#
        .SYNOPSIS
        Configure the global routing settings.

        .DESCRIPTION
        Sends PUT /ip-route/settings. Only the parameters you pass change. Use the REST names exactly: the switch ignores unknown fields without an error
        (a PUT with is_ip_routing_enabled would do nothing). Verified on a 2540 (YC.16.11) with -is_ip_source_routing_enable; switching IP routing off
        was not tried.

        .EXAMPLE
        Set-ArubaSWIpRouteSettings -is_ip_source_routing_enable:$false
    #>

    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseSingularNouns", "", Justification = "Name der REST-Ressource")]
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    Param(
        [Parameter(Mandatory = $false)]
        [switch]$is_ip_routing_enable,
        [Parameter(Mandatory = $false)]
        [switch]$is_ip_source_routing_enable,
        [Parameter (Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$connection = (Get-ArubaSWDefaultConnection)
    )

    Begin {
    }

    Process {
        $changes = @{}
        foreach ($name in 'is_ip_routing_enable', 'is_ip_source_routing_enable') {
            if ($PsBoundParameters.ContainsKey($name)) { $changes[$name] = [bool]$PsBoundParameters[$name] }
        }
        $uri = "ip-route/settings"
        $body = Get-ArubaSWMergedBody -Uri $uri -Changes $changes -Connection $connection

        if ($PSCmdlet.ShouldProcess('ip-route/settings', 'Configure routing settings')) {
            $response = Invoke-ArubaSWWebRequest -method "PUT" -body $body -uri $uri -connection $connection
            if ($response.content) {
                $response.content | ConvertFrom-Json
            }
        }
    }

    End {
    }
}
