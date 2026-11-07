#
# Copyright 2026, PowerArubaSW contributors
# SPDX-License-Identifier: Apache-2.0
#

function Test-ArubaSWTraceRoute {

    <#
        .SYNOPSIS
        Trace the route from the switch to a target (traceroute).

        .DESCRIPTION
        Sends POST /trace-route. Verified on a 2540 (YC.16.11): the body is
        { destination: { ip_address: { version, octets } }, max_ttl }; the REST reference names destination_ip, which
        the switch does not accept. The answer lists ttl_data with the probes of every hop (gateway, probe_time_in_millis).
        Returns one object per hop with the TTL, the answering gateway and the probe times in milliseconds.

        .EXAMPLE
        Test-ArubaSWTraceRoute -ipv4_address 192.0.2.1

        Trace the route to 192.0.2.1.

        .EXAMPLE
        Test-ArubaSWTraceRoute -ipv4_address 192.0.2.1 -max_ttl 5

        Stop after 5 hops.
    #>

    [CmdletBinding()]
    Param(
        [Parameter (Mandatory = $true)]
        [ipaddress]$ipv4_address,
        [Parameter (Mandatory = $false)]
        [ValidateRange(1, 255)]
        [int]$max_ttl,
        [Parameter (Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$connection = (Get-ArubaSWDefaultConnection)
    )

    Begin {
    }

    Process {

        $uri = "trace-route"

        $ip = New-Object -TypeName PSObject
        $ip | Add-Member -name "version" -MemberType NoteProperty -Value "IAV_IP_V4"
        $ip | Add-Member -name "octets" -MemberType NoteProperty -Value $ipv4_address.ToString()

        $dest = New-Object -TypeName PSObject
        $dest | Add-Member -name "ip_address" -MemberType NoteProperty -Value $ip

        $conf = New-Object -TypeName PSObject
        $conf | Add-Member -name "destination" -MemberType NoteProperty -Value $dest

        if ($PsBoundParameters.ContainsKey('max_ttl')) {
            $conf | Add-Member -name "max_ttl" -MemberType NoteProperty -Value $max_ttl
        }

        $response = Invoke-ArubaSWWebRequest -method "POST" -body $conf -uri $uri -connection $connection
        $run = $response.content | ConvertFrom-Json

        $ttl = 0
        foreach ($hop in @($run.ttl_data)) {
            $ttl++
            $probes = @($hop.ttl_probe_data)
            $gateways = @($probes | ForEach-Object { if ($_.gateway -and $_.gateway.ip_address) { $_.gateway.ip_address.octets } } | Select-Object -Unique)
            [pscustomobject]@{
                ttl      = $ttl
                gateway  = ($gateways -join ',')
                time_ms  = @($probes | ForEach-Object { $_.probe_time_in_millis })
                probes   = $probes
            }
        }
    }

    End {
    }
}
