#
# Copyright 2026, PowerArubaSW contributors
# SPDX-License-Identifier: Apache-2.0
#
# IP-Adressen je VLAN (Inkrement I38). Felder und Verhalten stammen von einer 2540 (YC.16.11.0010), nicht aus der Spec.

function Get-ArubaSWVlanIpAddress {

    <#
        .SYNOPSIS
        Get the IP addresses of a VLAN.

        .DESCRIPTION
        Reads GET /vlans/<vlan_id>/ipaddresses (all VLANs: Get-ArubaSWIpAddress). Returns one object per address with
        ip_address_mode (IAAM_STATIC or IAAM_DHCP), vlan_id, and for static addresses ip_address and ip_mask
        (objects with version and octets). A VLAN without an address returns nothing.

        .EXAMPLE
        Get-ArubaSWVlanIpAddress -vlan_id 100

        .EXAMPLE
        Get-ArubaSWVlans -id 100 | Get-ArubaSWVlanIpAddress
    #>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateRange(1, 4094)]
        [int]$vlan_id,
        [Parameter (Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$connection = (Get-ArubaSWDefaultConnection)
    )

    Begin {
    }

    Process {
        Get-ArubaSWPortResource -Path "vlans/${vlan_id}/ipaddresses" -ElementName 'ip_address_subnet_element' -Connection $connection
    }

    End {
    }
}

function Add-ArubaSWVlanIpAddress {

    <#
        .SYNOPSIS
        Add an IP address to a VLAN (static or DHCP).

        .DESCRIPTION
        Sends POST /vlans/<vlan_id>/ipaddresses. The switch needs vlan_id in the body as well (the cmdlet sends it;
        without it the answer is "Missing vlan_id"). Verified on a 2540 (YC.16.11):
        - a static address needs -ip_address and the mask as -ip_mask or -prefix_length;
        - -dhcp (IAAM_DHCP) takes the address from DHCP and REPLACES a static address of the VLAN;
        - the switch rejects an address in a network that overlaps one already configured ("An interface with the same
          IP address or subnet or an overlapping network ... already exists") and an invalid mask ("Invalid input").
        Changing the address of the management VLAN can cut the connection to the switch.

        .EXAMPLE
        Add-ArubaSWVlanIpAddress -vlan_id 701 -ip_address 192.0.2.1 -ip_mask 255.255.255.0

        .EXAMPLE
        Add-ArubaSWVlanIpAddress -vlan_id 701 -ip_address 192.0.2.1 -prefix_length 24

        .EXAMPLE
        Add-ArubaSWVlanIpAddress -vlan_id 701 -dhcp
    #>

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High', DefaultParameterSetName = 'mask')]
    Param(
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateRange(1, 4094)]
        [int]$vlan_id,
        [Parameter(Mandatory = $true, ParameterSetName = 'mask')]
        [Parameter(Mandatory = $true, ParameterSetName = 'prefix')]
        [ipaddress]$ip_address,
        [Parameter(Mandatory = $true, ParameterSetName = 'mask')]
        [ipaddress]$ip_mask,
        [Parameter(Mandatory = $true, ParameterSetName = 'prefix')]
        [ValidateRange(1, 32)]
        [int]$prefix_length,
        [Parameter(Mandatory = $true, ParameterSetName = 'dhcp')]
        [switch]$dhcp,
        [Parameter (Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$connection = (Get-ArubaSWDefaultConnection)
    )

    Begin {
    }

    Process {
        $uri = "vlans/${vlan_id}/ipaddresses"

        $conf = New-Object -TypeName PSObject
        $conf | Add-Member -name "vlan_id" -MemberType NoteProperty -Value $vlan_id

        if ($dhcp) {
            $conf | Add-Member -name "ip_address_mode" -MemberType NoteProperty -Value "IAAM_DHCP"
            $target = "VLAN $vlan_id (DHCP)"
        }
        else {
            if ($PSCmdlet.ParameterSetName -eq 'prefix') {
                $bits = ('1' * $prefix_length).PadRight(32, '0')
                $mask = (0, 8, 16, 24 | ForEach-Object { [Convert]::ToInt32($bits.Substring($_, 8), 2) }) -join '.'
            }
            else {
                $mask = $ip_mask.ToString()
            }
            $conf | Add-Member -name "ip_address_mode" -MemberType NoteProperty -Value "IAAM_STATIC"
            $conf | Add-Member -name "ip_address" -MemberType NoteProperty -Value ([pscustomobject]@{ version = 'IAV_IP_V4'; octets = $ip_address.ToString() })
            $conf | Add-Member -name "ip_mask" -MemberType NoteProperty -Value ([pscustomobject]@{ version = 'IAV_IP_V4'; octets = $mask })
            $target = "VLAN $vlan_id ($($ip_address.ToString())/$mask)"
        }

        if ($PSCmdlet.ShouldProcess($target, 'Add VLAN IP address')) {
            $response = Invoke-ArubaSWWebRequest -method "POST" -body $conf -uri $uri -connection $connection
            $response.content | ConvertFrom-Json
        }
    }

    End {
    }
}

function Remove-ArubaSWVlanIpAddress {

    <#
        .SYNOPSIS
        Remove an IP address from a VLAN.

        .DESCRIPTION
        Sends DELETE /vlans/<vlan_id>/ipaddresses/<mode>-<address> (IAAM_STATIC-<ip> or IAAM_DHCP-0.0.0.0).
        Pass the address with -vlan_id and -ip_address (or -dhcp), or pipe the object from Get-ArubaSWVlanIpAddress.
        Removing the address of the management VLAN cuts the connection to the switch.

        .EXAMPLE
        Remove-ArubaSWVlanIpAddress -vlan_id 701 -ip_address 192.0.2.1

        .EXAMPLE
        Get-ArubaSWVlanIpAddress -vlan_id 701 | Remove-ArubaSWVlanIpAddress
    #>

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High', DefaultParameterSetName = 'static')]
    Param(
        [Parameter(Mandatory = $true, ParameterSetName = 'static')]
        [Parameter(Mandatory = $true, ParameterSetName = 'dhcp')]
        [ValidateRange(1, 4094)]
        [int]$vlan_id,
        [Parameter(Mandatory = $true, ParameterSetName = 'static')]
        [ipaddress]$ip_address,
        [Parameter(Mandatory = $true, ParameterSetName = 'dhcp')]
        [switch]$dhcp,
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ParameterSetName = 'object')]
        [PSObject]$vlan_ip_address,
        [Parameter (Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$connection = (Get-ArubaSWDefaultConnection)
    )

    Begin {
    }

    Process {
        if ($PSCmdlet.ParameterSetName -eq 'object') {
            $vlan = $vlan_ip_address.vlan_id
            $mode = $vlan_ip_address.ip_address_mode
            $addr = if ($vlan_ip_address.ip_address) { $vlan_ip_address.ip_address.octets } else { '0.0.0.0' }
        }
        elseif ($dhcp) {
            $vlan = $vlan_id
            $mode = 'IAAM_DHCP'
            $addr = '0.0.0.0'
        }
        else {
            $vlan = $vlan_id
            $mode = 'IAAM_STATIC'
            $addr = $ip_address.ToString()
        }

        if ($PSCmdlet.ShouldProcess("VLAN $vlan ($mode-$addr)", 'Remove VLAN IP address')) {
            $null = Invoke-ArubaSWWebRequest -method "DELETE" -uri "vlans/${vlan}/ipaddresses/${mode}-${addr}" -connection $connection
        }
    }

    End {
    }
}
