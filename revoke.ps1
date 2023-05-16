##################################################
# HelloID-Conn-Prov-Target-Iloq-Entitlement-Revoke
#
# Version: 1.0.0
##################################################
# Initialize default values
$config = $configuration | ConvertFrom-Json
$p = $person | ConvertFrom-Json
$aRef = $AccountReference | ConvertFrom-Json
$pRef = $permissionReference | ConvertFrom-Json
$success = $false
$auditLogs = [System.Collections.Generic.List[PSCustomObject]]::new()

# Enable TLS1.2
[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor [System.Net.SecurityProtocolType]::Tls12

# Set debug logging
switch ($($config.IsDebug)) {
    $true { $VerbosePreference = 'Continue' }
    $false { $VerbosePreference = 'SilentlyContinue' }
}

#region functions
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
        $response = Invoke-RestMethod @params  -Verbose:$false
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
        $response = Invoke-RestMethod @params  -Verbose:$false
        Write-Output $response.LockGroup_ID
    } catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}

function Set-IloqResolvedURL {
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
        $resolvedUrl = Invoke-RestMethod @splatParams  -Verbose:$false

        if ([string]::IsNullOrEmpty($resolvedUrl) ) {
            Write-Verbose "No Resolved - URL found, keep on using the URL provided: $($config.BaseUrl)."
        } else {
            Write-Verbose "Resolved - URL found [$resolvedUrl , Using the found url to execute the following requests."
            $config.BaseUrl = $resolvedUrl
        }
    } catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}

function Get-IloqZoneId {
    [CmdletBinding()]
    param (
        [object]
        $config,

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
            Uri         = "$($config.BaseUrl)/api/v2/Zones"
            Method      = 'GET'
            Headers     = $headers
            ContentType = 'application/json'
        }
        # Use zone with type 4 as default
        $getAllZonesResponse = Invoke-RestMethod @splatParams  -Verbose:$false
        Write-Verbose $($getAllZonesResponse) -verbose
        $zoneId = $getAllZonesResponse | Where-Object { $_.type -eq $ZoneIdType }
        if ($null -eq $zoneId) {
            throw 'No valid ZoneId Type [4] found. Please verify for iLoq Configuration'
        }
        Write-Output $zoneId
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

function Confirm-IsUpdateRequiredEnddateKey {
    [CmdletBinding()]
    param(
        $NewEndDate,
        $CurrentEnddate
    )
    if ($null -ne $NewEndDate) {
        $_enddate = ([Datetime]$NewEndDate).ToShortDateString()
    }
    if ($null -ne $key.ExpireDate) {
        $_currentEnddate = ([Datetime]$CurrentEnddate).ToShortDateString()
    }
    if ($_currentEnddate -ne $_enddate) {
        Write-Output $true
    }
}
#endregion

# Begin
try {
    try {
        Write-Verbose "Verifying if a Iloq account for [$($p.DisplayName)] exists"
        if ($null -eq $aRef) {
            $dryRunMessage = 'No account Reference found. Skipping Action'
            $action = 'ARefNotFound'
        } else {
            Write-Verbose 'Setup iLOQ Session'
            $null = Set-IloqResolvedURL -Config $config
            $sessionId = Get-IloqSessionId -Config $config
            $lockGroupId = Get-IloqLockGroupId -Config $config -SessionId $sessionId
            $null = Set-IloqLockGroup -Config $config -SessionId $sessionId -LockGroupId $lockGroupId

            Write-Verbose 'Adding authorization headers'
            $headers = [System.Collections.Generic.Dictionary[string, string]]::new()
            $headers.Add('Content-Type', 'application/json; charset=utf-8')
            $headers.Add('SessionId', $sessionId)

            $splatParams = @{
                Uri         = "$($config.BaseUrl)/api/v2/Persons/$($aRef)"
                Method      = 'GET'
                Headers     = $headers
                ContentType = 'application/json; charset=utf-8'
            }
            $responseUser = Invoke-RestMethod @splatParams -Verbose:$false
            $action = 'Found'
            $dryRunMessage = "Revoke Iloq entitlement: [$($pRef.DisplayName)] to: [$($p.DisplayName)] will be executed during enforcement"
        }
    } catch {
        if ($_.ErrorDetails.Message -match 'Invalid value *') {
            $action = 'NotFound'
            $dryRunMessage = "Iloq account for: [$($p.DisplayName)] not found. Possibly already deleted. Skipping action"
        } else {
            throw $_
        }
    }

    # Add an auditMessage showing what will happen during enforcement
    if ($dryRun -eq $true) {
        Write-Warning "[DryRun] $dryRunMessage"
    }

    # Process

    switch ($action) {
        'Found' {
            Write-Verbose 'Verifying if an Iloq account has access keys assigned'
            $splatParams = @{
                Uri         = "$($config.BaseUrl)/api/v2/Persons/$($aRef)/Keys"
                Method      = 'GET'
                Headers     = $headers
                ContentType = 'application/json; charset=utf-8'
            }
            $responseKeys = Invoke-RestMethod @splatParams -Verbose:$false

            if ($responseKeys.Keys.Length -eq 0) {
                $auditLogs.Add([PSCustomObject]@{
                        Message = "No Keys assigned to Person: [$($responseUser.PersonCode)] Aref: [$($aRef)]. Skipping action"
                        IsError = $false
                    })
            } else {
                Write-Verbose "Revoking Iloq entitlement: [$($pRef.DisplayName)]"
                foreach ($key in $responseKeys.Keys) {
                    if (Confirm-IsUpdateRequiredEnddateKey -NewEndDate $p.PrimaryContract.Enddate -CurrentEnddate $key.ExpireDate) {
                        Write-Verbose "Enddate Update required of AccessKey [$($key.Description)]"

                        if ($dryRun -eq $true) {
                            Write-Warning "[DryRun] Update enddate AccessKey: [$($key.Description)] will be executed during enforcement"
                        }
                        if (-not($dryRun -eq $true)) {
                            $key.ExpireDate = $p.PrimaryContract.Enddate
                            $bodyKey = @{
                                Key = $key
                            } | ConvertTo-Json

                            $splatParams = @{
                                Uri         = "$($config.BaseUrl)/api/v2/Keys"
                                Method      = 'PUT'
                                Headers     = $headers
                                Body        = $bodyKey
                                ContentType = 'application/json; charset=utf-8'
                            }
                            $null = Invoke-RestMethod @splatParams -Verbose:$false
                            Write-Verbose "Updated endate of AccessKey: [$($key.Description)]. New Enddate is [$($key.ExpireDate)]"

                            $auditLogs.Add([PSCustomObject]@{
                                    Action  = 'UpdateAccount'
                                    Message = "Update enddate AccessKey: [$($key.Description)] was successful"
                                    IsError = $false
                                })
                        }
                    }

                    $splatParams = @{
                        Uri     = "$($config.BaseUrl)/api/v2/Keys/$($key.FNKey_ID)/SecurityAccesses/$($pRef.Reference)/CanDelete"
                        Method  = 'GET'
                        Headers = $headers
                    }
                    $canDelete = Invoke-RestMethod @splatParams -Verbose:$false

                    switch ($canDelete) {
                        1 {
                            if (-not($dryRun -eq $true)) {
                                $splatParams = @{
                                    Uri     = "$($config.BaseUrl)/api/v2/Keys/$($key.FNKey_ID)/SecurityAccesses/$($pRef.Reference)"
                                    Method  = 'DELETE'
                                    Headers = $headers
                                }
                                $null = Invoke-RestMethod @splatParams -Verbose:$false
                                $auditLogs.Add([PSCustomObject]@{
                                        Message = "Revoke Iloq entitlement [$($pRef.DisplayName)] from Key [$($key.Description)] was successful"
                                        IsError = $false
                                    })
                            }
                            $success = $true
                            break
                        }
                        2 {
                            $auditLogs.Add([PSCustomObject]@{
                                    Message = "Could not revoke Iloq Key [$($key.Description)]. Key is in unmodifiable state, for ex. blacklisted."
                                    IsError = $true
                                })
                            break
                        }
                        3 {
                            $success = $true
                            $auditLogs.Add([PSCustomObject]@{
                                    Message = "Revoke Iloq entitlement [$($pRef.DisplayName)] from Key [$($key.Description)] was successful. Security Access link already removed"
                                    IsError = $false
                                })
                            break
                        }
                        default {
                            $auditLogs.Add([PSCustomObject]@{
                                    Message = "Unkown return type [$canDelete] from 'CanDelete' please check the api reference: https://s5.iloq.com/iLOQPublicApiDoc#operation/Keys_CanDeleteSecurityAccess"
                                    IsError = $true
                                })
                        }
                    }
                }
            }
        }
        'NotFound' {
            $success = $true
            $auditLogs.Add([PSCustomObject]@{
                    Message = "Iloq account for: [$($p.DisplayName)] not found. Possibly already deleted. Skipping action"
                    IsError = $false
                })
            break
        }
        'ARefNotFound' {
            $success = $true
            $auditLogs.Add([PSCustomObject]@{
                    Message = "Account Reference for: [$($p.DisplayName)] not found. Skipping action"
                    IsError = $false
                })
            break
        }

    }
} catch {
    $success = $false
    $ex = $PSItem
    if ($($ex.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') -or
        $($ex.Exception.GetType().FullName -eq 'System.Net.WebException')) {
        $errorObj = Resolve-IloqError -ErrorObject $ex
        $auditMessage = "Could not revoke Iloq entitlement. Error: $($errorObj.FriendlyMessage)"
        Write-Verbose "Error at Line '$($errorObj.ScriptLineNumber)': $($errorObj.Line). Error: $($errorObj.ErrorDetails)"
    } else {
        $auditMessage = "Could not revoke Iloq entitlement. Error: $($ex.Exception.Message)"
        Write-Verbose "Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"
    }
    $auditLogs.Add([PSCustomObject]@{
            Message = $auditMessage
            IsError = $true
        })
    # End
} finally {
    $result = [PSCustomObject]@{
        Success   = $success
        Auditlogs = $auditLogs
    }
    Write-Output $result | ConvertTo-Json -Depth 10
}
