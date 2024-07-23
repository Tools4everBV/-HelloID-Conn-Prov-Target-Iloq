##################################################
# HelloID-Conn-Prov-Target-Iloq-Disable
# PowerShell V2
##################################################

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
    # Verify if [$actionContext.References.Account] has a value
    if ([string]::IsNullOrEmpty($($actionContext.References.Account))) {
        throw 'The account reference could not be found'
    }

    Write-Information "Verifying if a Iloq account for [$($personContext.Person.DisplayName)] exists"

    # First step is to get the correct url to use for the rest of the API calls.
    $null = Get-IloqResolvedURL -Config $ActionContext.Configuration

    # Get the iLOQ sessionId
    $sessionId = Get-IloqSessionId -Config $ActionContext.Configuration

    # Get the iLOQ lockGroupId
    $lockGroupId = Get-IloqLockGroupId -Config $ActionContext.Configuration -SessionId $sessionId

    # Set the iLOQ lockGroup in order to make authenticated calls
    $null = Set-IloqLockGroup -Config $ActionContext.Configuration -SessionId $sessionId -LockGroupId $lockGroupId

    $headers = [System.Collections.Generic.Dictionary[string, string]]::new()
    $headers.Add('Content-Type', 'application/json; charset=utf-8')
    $headers.Add('SessionId', $sessionId)

    try {
        $splatParams = @{
            Uri         = "$($ActionContext.Configuration.BaseUrl)/api/v2/Persons/$($actionContext.References.Account)"
            Method      = 'GET'
            Headers     = $headers
            ContentType = 'application/json; charset=utf-8'
        }

        $correlatedAccount = Invoke-RestMethod @splatParams -Verbose:$false
    } catch {
        if ($_.Errordetails.message -match 'Invalid value') {
            $correlatedAccount = $null
        } else{
            throw $_
        }
    }

    if ($null -ne $correlatedAccount) {
        $action = 'DisableAccount'
        $dryRunMessage = "Disable Iloq account: [$($actionContext.References.Account)] for person: [$($personContext.Person.DisplayName)] will be executed during enforcement"
    } else {
        $action = 'NotFound'
        $dryRunMessage = "Iloq account: [$($actionContext.References.Account)] for person: [$($personContext.Person.DisplayName)] could not be found, possibly indicating that it could be deleted, or the account is not correlated"
    }

    # Add a message and the result of each of the validations showing what will happen during enforcement
    if ($actionContext.DryRun -eq $true) {
        Write-Information "[DryRun] $dryRunMessage"
    }

    # Process
    if (-not($actionContext.DryRun -eq $true)) {
        switch ($action) {
            'DisableAccount' {
                Write-Information "Disabling Iloq account with accountReference: [$($actionContext.References.Account)]"

                $correlatedAccount.EmploymentEndDate= $ActionContext.EmploymentEndDate
                $account = [PSCustomObject]@{
                    Person = [PSCustomObject]$correlatedAccount
                }

                $splatParams = @{
                    Uri         = "$($ActionContext.Configuration.BaseUrl)/api/v2/Persons"
                    Method      = 'PUT'
                    Headers     = $headers
                    Body        = $account | ConvertTo-Json
                    ContentType = 'application/json; charset=utf-8'
                }

                $null = Invoke-RestMethod @splatParams -Verbose:$false

                $splatParams = @{
                    Uri         = "$($actionContext.Configuration.BaseUrl)/api/v2/Persons/$($actionContext.References.Account)/Keys"
                    Method      = 'GET'
                    Headers     = $headers
                    ContentType = 'application/json; charset=utf-8'
                }

                $keys = Invoke-RestMethod @splatParams -Verbose:$false

                if ($keys.keys.count -eq 0) {
                    $outputContext.Success = $true
                    $outputContext.AuditLogs.Add([PSCustomObject]@{
                            Message = "Account: $($actionContext.References.Account). Has no keys to return"
                            IsError = $false
                        })
                } else {
                    foreach ($key in $keys.keys) {
                        #Check if key can be returned $($key.FNKey_ID)
                        $splatParams = @{
                            Uri         = "$($actionContext.Configuration.BaseUrl)/api/v2/Keys/$($key.FNKey_ID)/CanReturn"
                            Method      = 'GET'
                            Headers     = $headers
                            ContentType = 'application/json; charset=utf-8'
                        }

                        $result = Invoke-RestMethod @splatParams  -Verbose:$false
                        switch ($result) {
                            0 {
                                #return keys
                                $splatParams = @{
                                    Uri         = "$($actionContext.Configuration.BaseUrl)/api/v2/Keys/$($key.FNKey_ID)/Return"
                                    Method      = 'POST'
                                    Headers     = $headers
                                    Body        = $account | ConvertTo-Json
                                    ContentType = 'application/json; charset=utf-8'
                                }

                                $null = Invoke-RestMethod @splatParams  -Verbose:$false

                                $outputContext.Success = $true
                                $outputContext.AuditLogs.Add([PSCustomObject]@{
                                        Message = "Account: $($actionContext.References.Account). Revoke key [$($key.FNKey_ID)] was successfull"
                                        IsError = $false
                                    })
                            }
                            1 {
                                $outputContext.AuditLogs.Add([PSCustomObject]@{
                                        Message = "Account: $($actionContext.References.Account). Returning key [$($key.FNKey_ID)] requires iLOQ Manager + token."
                                        IsError = $true
                                    })
                            }
                            2 {
                                $outputContext.AuditLogs.Add([PSCustomObject]@{
                                        Message = "Account: $($actionContext.References.Account). Key [$($key.FNKey_ID)]  isn't a phone and can't be returned using public api."
                                        IsError = $true
                                    })
                            }
                            3 {
                                $outputContext.AuditLogs.Add([PSCustomObject]@{
                                        Message = "Account: $($actionContext.References.Account). Key [$($key.FNKey_ID)]  has never been programmed. It can't be returned before it's programmed. Call Delete endpoint instead."
                                        IsError = $true
                                    })
                            }
                            Default {
                                $outputContext.AuditLogs.Add([PSCustomObject]@{
                                        Message = "Unkown return type from 'CanReturn' please check the api reference: https://s5.iloq.com/iLOQPublicApiDoc#operation/Keys_CanReturnKey"
                                        IsError = $true
                                    })
                            }
                        }
                    }
               }
            }

            'NotFound' {
                $outputContext.Success = $true
                $outputContext.AuditLogs.Add([PSCustomObject]@{
                        Message = "Iloq account: [$($actionContext.References.Account)] for person: [$($personContext.Person.DisplayName)] could not be found, possibly indicating that it could be deleted, or the account is not correlated"
                        IsError = $false
                    })
                break
            }
        }
    }
} catch {
    $outputContext.success = $false
    $ex = $PSItem
    if ($($ex.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') -or
        $($ex.Exception.GetType().FullName -eq 'System.Net.WebException')) {
        $errorObj = Resolve-IloqError -ErrorObject $ex
        $auditMessage = "Could not disable Iloq account. Error: $($errorObj.FriendlyMessage)"
        Write-Warning "Error at Line '$($errorObj.ScriptLineNumber)': $($errorObj.Line). Error: $($errorObj.ErrorDetails)"
    } else {
        $auditMessage = "Could not disable Iloq account. Error: $($_.Exception.Message)"
        Write-Warning "Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"
    }
    $outputContext.AuditLogs.Add([PSCustomObject]@{
            Message = $auditMessage
            IsError = $true
        })
}