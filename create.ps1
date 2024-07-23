#################################################
# HelloID-Conn-Prov-Target-Iloq-Create
# PowerShell V2
#################################################

# Enable TLS1.2
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12

#region functions

function Get-IloqResolvedURL {
    [CmdletBinding()]
    param (
        [object]
        $config
    )
    try {
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12
        $headers = [System.Collections.Generic.Dictionary[string, string]]::new()
        $headers.Add('Content-Type', 'application/json')
        $headers.Add('SessionId', $SessionId)

        $splatParams = @{
            Uri         = "$($config.BaseUrl)/api/v2/Url/GetUrl"
            Method      = 'POST'
            ContentType = 'application/json'
            Body        = @{
                'CustomerCode' = $($config.CustomerCode)
            }  | ConvertTo-Json
        }
        $resolvedUrl = Invoke-RestMethod @splatParams -Verbose:$false

        if ([string]::IsNullOrEmpty($resolvedUrl) ) {
            Write-Information "No Resolved - URL found, keep on using the URL provided: $($config.BaseUrl)."
        } else {
            Write-Information "Resolved - URL found [$resolvedUrl , Using the found url to execute the subsequent requests."
            $config.BaseUrl = $resolvedUrl
        }
    } catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}

function Get-IloqSessionId {
    [CmdletBinding()]
    param (
        [object]
        $config
    )

    try {
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12

        $headers = [System.Collections.Generic.Dictionary[string, string]]::new()
        $headers.Add('Content-Type', 'application/json')
        $params = @{
            Uri     = "$($config.BaseUrl)/api/v2/CreateSession"
            Method  = 'POST'
            Headers = $headers
            Body    = @{
                'CustomerCode' = $($config.CustomerCode)
                'UserName'     = $($config.UserName)
                'Password'     = $($config.Password)
            } | ConvertTo-Json
        }
        $response = Invoke-RestMethod @params -Verbose:$false
        Write-Output $response.SessionID
    } catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}

function Get-IloqLockGroupId {
    [CmdletBinding()]
    param (
        [object]
        $config,

        [string]
        $SessionId
    )

    try {
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12

        $headers = [System.Collections.Generic.Dictionary[string, string]]::new()
        $headers.Add('Content-Type', 'application/json')
        $headers.Add('SessionId', $SessionId)
        $params = @{
            Uri     = "$($config.BaseUrl)/api/v2/LockGroups"
            Method  = 'GET'
            Headers = $headers
        }
        $response = Invoke-RestMethod @params -Verbose:$false
        Write-Output $response.LockGroup_ID
    } catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}
function Set-IloqLockGroup {
    [CmdletBinding()]
    param (
        [object]
        $config,

        [string]
        $SessionId,

        [string]
        $LockGroupId
    )

    try {
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12

        $headers = [System.Collections.Generic.Dictionary[string, string]]::new()
        $headers.Add('Content-Type', 'application/json')
        $headers.Add('SessionId', $SessionId)
        $params = @{
            Uri     = "$($config.BaseUrl)/api/v2/SetLockGroup"
            Method  = 'POST'
            Headers = $headers
            Body    = @{
                'LockGroup_ID' = $LockGroupId
            } | ConvertTo-Json
        }
        $response = Invoke-RestMethod @params -Verbose:$false
        Write-Output $response.LockGroup_ID
    } catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}
function Get-IloqZoneId {
    [CmdletBinding()]
    param (
        [string]
        $BaseUrl,

        [string]
        $SessionId,

        [int]
        $ZoneIdType
    )
    try {
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12
        $headers = [System.Collections.Generic.Dictionary[string, string]]::new()
        $headers.Add('Content-Type', 'application/json')
        $headers.Add('SessionId', $SessionId)

        $splatParams = @{
            Uri         = "$BaseUrl/api/v2/Zones"
            Method      = 'GET'
            Headers     = $headers
            ContentType = 'application/json'
        }
        # Use zone with type configured type as default
        $getAllZonesResponse = Invoke-RestMethod @splatParams -Verbose:$false
        $zoneId = $getAllZonesResponse | Where-Object { $_.type -eq $ZoneIdType }
        if ($null -eq $zoneId) {
            throw "No valid ZoneId Type [$ZoneIdType] found. Please verify for iLOQ Configuration"
        }
        Write-Output $zoneId
    } catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}

function Resolve-IloqError {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [object]
        $ErrorObject
    )
    process {
        $httpErrorObj = [PSCustomObject]@{
            ScriptLineNumber = $ErrorObject.InvocationInfo.ScriptLineNumber
            Line             = $ErrorObject.InvocationInfo.Line
            ErrorDetails     = ''
            FriendlyMessage  = ''
        }

        if ($null -eq $ErrorObject.Exception.Response) {
            $httpErrorObj.ErrorDetails = $ErrorObject.Exception.Message
            $httpErrorObj.FriendlyMessage = $ErrorObject.Exception.Message
        } else {
            $httpErrorObj.ErrorDetails = $ErrorObject.ErrorDetails.Message
            $httpErrorObj.FriendlyMessage = ($ErrorObject.ErrorDetails.Message | ConvertFrom-Json).Message
        }
        Write-Output $httpErrorObj
    }
}

#endregion

try {
    # Initial Assignments
    $outputContext.AccountReference = 'Currently not available'

    # First step is to get the correct url to use for the rest of the API calls.
    $null = Get-IloqResolvedURL -Config $actionContext.Configuration

    # Get the iLOQ sessionId
    $sessionId = Get-IloqSessionId -Config $actionContext.Configuration

    # Get the iLOQ lockGroupId
    $lockGroupId = Get-IloqLockGroupId -Config $actionContext.Configuration -SessionId $sessionId

    # Set the iLOQ lockGroup in order to make authenticated calls
    $null = Set-IloqLockGroup -Config $actionContext.Configuration -SessionId $sessionId -LockGroupId $lockGroupId

    $headers = [System.Collections.Generic.Dictionary[string, string]]::new()
    $headers.Add('Content-Type', 'application/json; charset=utf-8')
    $headers.Add('SessionId', $sessionId)

    # Validate correlation configuration
    if ($actionContext.CorrelationConfiguration.Enabled) {
        $correlationField = $actionContext.CorrelationConfiguration.accountField
        $correlationValue = $actionContext.CorrelationConfiguration.accountFieldValue

        if ([string]::IsNullOrEmpty($($correlationField))) {
            throw 'Correlation is enabled but not configured correctly'
        }
        if ([string]::IsNullOrEmpty($($correlationValue))) {
            throw 'Correlation is enabled but [accountFieldValue] is empty. Please make sure it is correctly mapped'
        }

        # Verify if a user must be either [created ] or just [correlated]

        $splatParams = @{
            Uri         = "$($actionContext.Configuration.BaseUrl)/api/v2/Persons/GetByExternalPersonIds?externalPersonIds=$($actionContext.CorrelationConfiguration.accountFieldValue)"
            Method      = 'GET'
            Headers     = $headers
            ContentType = 'application/json'
        }
        try {
            $correlatedAccount = Invoke-RestMethod @splatParams -Verbose:$false
        } catch {
            if ($_.Errordetails.Message -match 'for parameter externalPersonIds') {
                $correlatedAccount = $null
            } else{
                throw $_
            }
        }
    }

    if ($null -ne $correlatedAccount) {
        $action = 'CorrelateAccount'
    } else {
        $action = 'CreateAccount'
    }

    # Add a message and the result of each of the validations showing what will happen during enforcement
    if ($actionContext.DryRun -eq $true) {
        Write-Information "[DryRun] $action Iloq account for: [$($personContext.Person.DisplayName)], will be executed during enforcement"
    }

    # Process

    switch ($action) {
        'CreateAccount' {
            Write-Information 'Creating and correlating Iloq account'

            $account = [PSCustomObject]@{
                Person  = [PSCustomObject]$actionContext.Data
                ZoneIds = @()
            }

            $nGuid = [guid]::NewGuid()
            $account.Person |  Add-Member -MemberType NoteProperty  -Name "Person_ID" -Value  $nGuid

            [bool] $externalCanEdit = $false
            if ($actionContext.Data.ExternalCanEdit -eq "true") {
                $externalCanEdit = $true
            }
            $account.Person |  Add-Member -Force -MemberType NoteProperty  -Name "ExternalCanEdit" -Value  $externalCanEdit

            $resolveZoneID = Get-IloqZoneId -BaseUrl $actionContext.Configuration.BaseUrl -SessionId $sessionId -ZoneIdType $actionContext.Configuration.defaultZoneIdType
            $account.ZoneIds += $resolveZoneID.Zone_ID

            $splatParams = @{
                Uri         = "$($actionContext.Configuration.BaseUrl)/api/v2/Persons"
                Method      = 'POST'
                Headers     = $headers
                Body        = $account | ConvertTo-Json
                ContentType = 'application/json; charset=utf-8'
            }


            if (-not($actionContext.DryRun -eq $true)) {
                $createUserResponse = Invoke-RestMethod @splatParams -Verbose:$false

                #$outputContext.Data = $actionContext.Data
                $outputContext.AccountReference = $createUserResponse.PersonIds | Select-Object -First 1
                $auditLogMessage = "Create account was successful. AccountReference is: [$($outputContext.AccountReference)"
            }
            break
        }

        'CorrelateAccount' {
            Write-Information 'Correlating Iloq account'

            $outputContext.Data = $correlatedAccount
            $outputContext.AccountReference = $correlatedAccount.Person_ID
            $outputContext.AccountCorrelated = $true
            $auditLogMessage = "Correlated account: [$($correlatedAccount.ExternalId)] on field: [$($correlationField)] with value: [$($correlationValue)]"
            break
        }
    }

    $outputContext.Success = $true
    $outputContext.AuditLogs.Add([PSCustomObject]@{
            Action  = $action
            Message = $auditLogMessage
            IsError = $false
        })

} catch {
    $outputContext.Success = $false
    $ex = $PSItem
    if ($($ex.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') -or
        $($ex.Exception.GetType().FullName -eq 'System.Net.WebException')) {
        $errorObj = Resolve-IloqError -ErrorObject $ex
        $auditMessage = "Could not create or correlate Iloq account. Error: $($errorObj.FriendlyMessage)"
        Write-Warning "Error at Line '$($errorObj.ScriptLineNumber)': $($errorObj.Line). Error: $($errorObj.ErrorDetails)"
    } else {
        $auditMessage = "Could not create or correlate Iloq account. Error: $($ex.Exception.Message)"
        Write-Warning "Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"
    }
    $outputContext.AuditLogs.Add([PSCustomObject]@{
            Message = $auditMessage
            IsError = $true
        })
}
