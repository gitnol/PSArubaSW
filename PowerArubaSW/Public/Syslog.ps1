#
# Copyright 2026, PowerArubaSW contributors
# SPDX-License-Identifier: Apache-2.0
#
# Syslog (Inkrement I27): GET/PUT /syslog, Filter-CRUD /syslog/filters, Ereigniskriterien
# /syslog/filters/{name}/event-criterias. Die OpenAPI-Spec und das 16.04-Referenz-PDF nennen
# nur die Operationen, NICHT die Felder von Syslog, SyslogFilter und SyslogEventCriteria.
# Deshalb erfinden diese Cmdlets keine Feldnamen: lesende Cmdlets geben die Antwort des
# Switches unveraendert zurueck, schreibende nehmen ein -Body-Objekt und reichen es
# unveraendert durch. Sobald Felder an einem echten Switch belegt sind, kommen typisierte
# Parameter und ein Spec-Schema dazu.

function Get-ArubaSWSyslog {

    <#
        .SYNOPSIS
        Get the global syslog configuration.

        .DESCRIPTION
        Reads GET /syslog.
        The fields of this resource are not documented in the OpenAPI spec or the 16.04 reference
        guide, so the response is returned exactly as the switch sends it.

        .EXAMPLE
        Get-ArubaSWSyslog

        Returns the syslog configuration as sent by the switch.
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

        $uri = "syslog"

        $response = Invoke-ArubaSWWebRequest -method "GET" -uri $uri -connection $connection

        $response.content | ConvertFrom-Json
    }

    End {
    }
}

function Set-ArubaSWSyslog {

    <#
        .SYNOPSIS
        Update the global syslog configuration.

        .DESCRIPTION
        Sends PUT /syslog.
        The fields of this resource are not documented in the OpenAPI spec or the 16.04 reference
        guide, so -Body is sent unchanged (hashtable or object, converted with ConvertTo-Json).
        Look at the output of the matching Get- cmdlet for the field names your firmware uses.
        Fields on the 2540 (YC.16.11): severity, facility, system_module, notify_running_config_change,
        transmission_interval, priority_descr, origin_id, prefix. The switch rejects transmission_interval
        ("notify_running_config_change should be true for setting transmission-interval") while
        notify_running_config_change is false, so leave it out of the body in that case.

        .EXAMPLE
        Set-ArubaSWSyslog -Body @{ severity = 'INFO'; prefix = 'lab' }

        Change only the fields in the body.

        .EXAMPLE
        $syslog = Get-ArubaSWSyslog | Select-Object -ExcludeProperty uri, transmission_interval
        $syslog.prefix = 'lab'
        Set-ArubaSWSyslog -Body $syslog

        Read-modify-write; transmission_interval is dropped because notify_running_config_change is false.
    #>

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    Param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [PSObject]$Body,
        [Parameter (Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$connection = (Get-ArubaSWDefaultConnection)
    )

    Begin {
    }

    Process {

        $uri = "syslog"

        if ($PSCmdlet.ShouldProcess($connection.server, 'Configure syslog')) {
            $response = Invoke-ArubaSWWebRequest -method "PUT" -body $Body -uri $uri -connection $connection
            if ($response.content) {
                $response.content | ConvertFrom-Json
            }
        }
    }

    End {
    }
}

function Get-ArubaSWSyslogFilter {

    <#
        .SYNOPSIS
        Get syslog filters (all, or one by name).

        .DESCRIPTION
        Reads GET /syslog/filters, or GET /syslog/filters/{filterName} with -FilterName.
        The fields of this resource are not documented in the OpenAPI spec or the 16.04 reference
        guide, so the response is returned exactly as the switch sends it.

        .EXAMPLE
        Get-ArubaSWSyslogFilter

        Returns the list of syslog filters.

        .EXAMPLE
        Get-ArubaSWSyslogFilter -FilterName MyFilter

        Returns the syslog filter MyFilter.
    #>

    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseSingularNouns", "")]
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [Alias('filter_name')]
        [String]$FilterName,
        [Parameter (Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$connection = (Get-ArubaSWDefaultConnection)
    )

    Begin {
    }

    Process {

        if ($PsBoundParameters.ContainsKey('FilterName')) {
            $filter = [System.Uri]::EscapeDataString($FilterName)
            $uri = "syslog/filters/${filter}"
        }
        else {
            $uri = "syslog/filters"
        }

        $response = Invoke-ArubaSWWebRequest -method "GET" -uri $uri -connection $connection

        $response.content | ConvertFrom-Json
    }

    End {
    }
}

function Add-ArubaSWSyslogFilter {

    <#
        .SYNOPSIS
        Add a syslog filter.

        .DESCRIPTION
        Sends POST /syslog/filters.
        The fields of this resource are not documented in the OpenAPI spec or the 16.04 reference
        guide, so -Body is sent unchanged (hashtable or object, converted with ConvertTo-Json).
        Look at the output of the matching Get- cmdlet for the field names your firmware uses.

        Fields on the 2540 (YC.16.11): filter_name, default_action (PERMIT | DENY), is_enabled; all three are mandatory.

        .EXAMPLE
        Add-ArubaSWSyslogFilter -Body @{ filter_name = 'F1'; default_action = 'PERMIT'; is_enabled = $true }

        Adds the syslog filter F1.
    #>

    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseSingularNouns", "")]
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    Param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [PSObject]$Body,
        [Parameter (Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$connection = (Get-ArubaSWDefaultConnection)
    )

    Begin {
    }

    Process {

        $uri = "syslog/filters"

        if ($PSCmdlet.ShouldProcess($connection.server, 'Add syslog filter')) {
            $response = Invoke-ArubaSWWebRequest -method "POST" -body $Body -uri $uri -connection $connection
            if ($response.content) {
                $response.content | ConvertFrom-Json
            }
        }
    }

    End {
    }
}

function Set-ArubaSWSyslogFilter {

    <#
        .SYNOPSIS
        Update a syslog filter by name.

        .DESCRIPTION
        Sends PUT /syslog/filters/{filterName}.
        The fields of this resource are not documented in the OpenAPI spec or the 16.04 reference
        guide, so -Body is sent unchanged (hashtable or object, converted with ConvertTo-Json).
        Look at the output of the matching Get- cmdlet for the field names your firmware uses.

        .EXAMPLE
        Set-ArubaSWSyslogFilter -FilterName MyFilter -Body $filter

        Updates the syslog filter MyFilter.
    #>

    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseSingularNouns", "")]
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    Param(
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [Alias('filter_name')]
        [String]$FilterName,
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [PSObject]$Body,
        [Parameter (Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$connection = (Get-ArubaSWDefaultConnection)
    )

    Begin {
    }

    Process {

        $filter = [System.Uri]::EscapeDataString($FilterName)
        $uri = "syslog/filters/${filter}"

        if ($PSCmdlet.ShouldProcess($FilterName, 'Configure syslog filter')) {
            $response = Invoke-ArubaSWWebRequest -method "PUT" -body $Body -uri $uri -connection $connection
            if ($response.content) {
                $response.content | ConvertFrom-Json
            }
        }
    }

    End {
    }
}

function Remove-ArubaSWSyslogFilter {

    <#
        .SYNOPSIS
        Delete a syslog filter by name.

        .DESCRIPTION
        Sends DELETE /syslog/filters/{filterName}.
        No request body.

        .EXAMPLE
        Remove-ArubaSWSyslogFilter -FilterName MyFilter

        Deletes the syslog filter MyFilter (asks for confirmation).

        .EXAMPLE
        Get-ArubaSWSyslogFilter -FilterName MyFilter | Remove-ArubaSWSyslogFilter -Confirm:$false

        Pipeline input works when the object has a FilterName property.
    #>

    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    Param(
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [Alias('filter_name')]
        [String]$FilterName,
        [Parameter (Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$connection = (Get-ArubaSWDefaultConnection)
    )

    Begin {
    }

    Process {

        $filter = [System.Uri]::EscapeDataString($FilterName)
        $uri = "syslog/filters/${filter}"

        if ($PSCmdlet.ShouldProcess($FilterName, 'Remove syslog filter')) {
            $null = Invoke-ArubaSWWebRequest -method "DELETE" -uri $uri -connection $connection
        }
    }

    End {
    }
}

function Get-ArubaSWSyslogEventCriteria {

    <#
        .SYNOPSIS
        Get the event criteria of a syslog filter (all, or one by id).

        .DESCRIPTION
        Reads GET /syslog/filters/{filterName}/event-criterias, or .../{criteriaId} with -CriteriaId.
        The fields of this resource are not documented in the OpenAPI spec or the 16.04 reference
        guide, so the response is returned exactly as the switch sends it.

        .EXAMPLE
        Get-ArubaSWSyslogEventCriteria -FilterName MyFilter

        Returns the event criteria of the filter MyFilter.

        .EXAMPLE
        Get-ArubaSWSyslogEventCriteria -FilterName MyFilter -CriteriaId 1

        Returns one criteria by id.
    #>

    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseSingularNouns", "")]
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [Alias('filter_name')]
        [String]$FilterName,
        [Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [Alias('criteria_id')]
        [String]$CriteriaId,
        [Parameter (Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$connection = (Get-ArubaSWDefaultConnection)
    )

    Begin {
    }

    Process {

        $filter = [System.Uri]::EscapeDataString($FilterName)
        $uri = "syslog/filters/${filter}/event-criterias"
        if ($PsBoundParameters.ContainsKey('CriteriaId')) {
            $criteria = [System.Uri]::EscapeDataString($CriteriaId)
            $uri = "syslog/filters/${filter}/event-criterias/${criteria}"
        }

        $response = Invoke-ArubaSWWebRequest -method "GET" -uri $uri -connection $connection

        $response.content | ConvertFrom-Json
    }

    End {
    }
}

function Add-ArubaSWSyslogEventCriteria {

    <#
        .SYNOPSIS
        Add an event criteria to a syslog filter.

        .DESCRIPTION
        Sends POST /syslog/filters/{filterName}/event-criterias.
        The fields of this resource are not documented in the OpenAPI spec or the 16.04 reference
        guide, so -Body is sent unchanged (hashtable or object, converted with ConvertTo-Json).
        Look at the output of the matching Get- cmdlet for the field names your firmware uses.

        Fields on the 2540 (YC.16.11): criteria_id, type (REG_EXPR; other types were rejected), reg_expr, action
        (PERMIT | DENY). A new filter already holds the default criteria 99 (reg_expr ".*"). The list endpoint
        answers with the wrapper syslog_event_criteria_element.

        .EXAMPLE
        Add-ArubaSWSyslogEventCriteria -FilterName MyFilter -Body @{ criteria_id = 1; type = 'REG_EXPR'; reg_expr = 'LLDP'; action = 'PERMIT' }

        Adds a regular-expression criteria to MyFilter.
    #>

    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseSingularNouns", "")]
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    Param(
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [Alias('filter_name')]
        [String]$FilterName,
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [PSObject]$Body,
        [Parameter (Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$connection = (Get-ArubaSWDefaultConnection)
    )

    Begin {
    }

    Process {

        $filter = [System.Uri]::EscapeDataString($FilterName)
        $uri = "syslog/filters/${filter}/event-criterias"

        if ($PSCmdlet.ShouldProcess($FilterName, 'Add syslog event criteria')) {
            $response = Invoke-ArubaSWWebRequest -method "POST" -body $Body -uri $uri -connection $connection
            if ($response.content) {
                $response.content | ConvertFrom-Json
            }
        }
    }

    End {
    }
}

function Set-ArubaSWSyslogEventCriteria {

    <#
        .SYNOPSIS
        Update an event criteria of a syslog filter.

        .DESCRIPTION
        Sends PUT /syslog/filters/{filterName}/event-criterias/{criteriaId}.
        The fields of this resource are not documented in the OpenAPI spec or the 16.04 reference
        guide, so -Body is sent unchanged (hashtable or object, converted with ConvertTo-Json).
        Look at the output of the matching Get- cmdlet for the field names your firmware uses.

        .EXAMPLE
        Set-ArubaSWSyslogEventCriteria -FilterName MyFilter -CriteriaId 1 -Body $criteria

        Updates criteria 1 of the filter MyFilter.
    #>

    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseSingularNouns", "")]
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
    Param(
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [Alias('filter_name')]
        [String]$FilterName,
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [Alias('criteria_id')]
        [String]$CriteriaId,
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [PSObject]$Body,
        [Parameter (Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$connection = (Get-ArubaSWDefaultConnection)
    )

    Begin {
    }

    Process {

        $filter = [System.Uri]::EscapeDataString($FilterName)
        $criteria = [System.Uri]::EscapeDataString($CriteriaId)
        $uri = "syslog/filters/${filter}/event-criterias/${criteria}"

        if ($PSCmdlet.ShouldProcess("$FilterName / $CriteriaId", 'Configure syslog event criteria')) {
            $response = Invoke-ArubaSWWebRequest -method "PUT" -body $Body -uri $uri -connection $connection
            if ($response.content) {
                $response.content | ConvertFrom-Json
            }
        }
    }

    End {
    }
}

function Remove-ArubaSWSyslogEventCriteria {

    <#
        .SYNOPSIS
        Delete an event criteria of a syslog filter.

        .DESCRIPTION
        Sends DELETE /syslog/filters/{filterName}/event-criterias/{criteriaId}.
        No request body.

        .EXAMPLE
        Remove-ArubaSWSyslogEventCriteria -FilterName MyFilter -CriteriaId 1

        Deletes criteria 1 of the filter MyFilter (asks for confirmation).
    #>

    [Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSUseSingularNouns", "")]
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    Param(
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [Alias('filter_name')]
        [String]$FilterName,
        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true)]
        [ValidateNotNullOrEmpty()]
        [Alias('criteria_id')]
        [String]$CriteriaId,
        [Parameter (Mandatory = $False)]
        [ValidateNotNullOrEmpty()]
        [PSObject]$connection = (Get-ArubaSWDefaultConnection)
    )

    Begin {
    }

    Process {

        $filter = [System.Uri]::EscapeDataString($FilterName)
        $criteria = [System.Uri]::EscapeDataString($CriteriaId)
        $uri = "syslog/filters/${filter}/event-criterias/${criteria}"

        if ($PSCmdlet.ShouldProcess("$FilterName / $CriteriaId", 'Remove syslog event criteria')) {
            $null = Invoke-ArubaSWWebRequest -method "DELETE" -uri $uri -connection $connection
        }
    }

    End {
    }
}
