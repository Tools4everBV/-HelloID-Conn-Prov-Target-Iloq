##################################################
# HelloID-Conn-Prov-Target-Iloq-Delete
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
    # Verify if [aRef] has a value
    if ([string]::IsNullOrEmpty($($actionContext.References.Account))) {
        throw 'The account reference could not be found'
    }

    Write-Information "Verifying if a Iloq account for [$($personContext.Person.DisplayName)] exists"

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

    try {
        $splatParams = @{
            Uri         = "$($actionContext.Configuration.BaseUrl)/api/v2/Persons/$($actionContext.References.Account)"
            Method      = 'GET'
            Headers     = $headers
            ContentType = 'application/json; charset=utf-8'
        }

        $correlatedAccount = Invoke-RestMethod @splatParams -Verbose:$false
    } catch {
        $correlatedAccount = $null
    }

    if ($null -ne $correlatedAccount) {
        $action = 'DeleteAccount'
        $dryRunMessage = "Delete Iloq account: [$($actionContext.References.Account)] for person: [$($personContext.Person.DisplayName)] will be executed during enforcement"
    } else {
        $action = 'NotFound'
        $dryRunMessage = "Iloq account: [$($actionContext.References.Account)] for person: [$($personContext.Person.DisplayName)] could not be found, possibly indicating that it may already have been deleted"
    }

    # Add a message and the result of each of the validations showing what will happen during enforcement
    if ($actionContext.DryRun -eq $true) {
        Write-Information "[DryRun] $dryRunMessage"
    }

    # Process
    if (-not($actionContext.DryRun -eq $true)) {
        switch ($action) {
            'DeleteAccount' {
                Write-Information "Deleting Iloq account with accountReference: [$($actionContext.References.Account)]"

                $splatParams = @{
                    Uri         = "$($actionContext.Configuration.BaseUrl)/api/v2/Persons/$($actionContext.References.Account)/CanDelete"
                    Method      = 'GET'
                    Headers     = $headers
                    ContentType = 'application/json; charset=utf-8'
                }

                $canDeleteResult = Invoke-RestMethod @splatParams -Verbose:$false

                switch ($canDeleteResult) {
                    0 {
                        $splatParams = @{
                            Uri         = "$($actionContext.Configuration.BaseUrl)/api/v2/Persons/$($actionContext.References.Account)"
                            Method      = 'DEL'
                            Headers     = $headers
                            ContentType = 'application/json; charset=utf-8'
                        }

                        $null = Invoke-RestMethod @splatParams -Verbose:$false

                        $outputContext.Success = $true
                        $outputContext.AuditLogs.Add([PSCustomObject]@{
                            Message = "Account: $($actionContext.References.Account). Delete account was successful"
                            IsError = $false
                        })
                    }
                    1 {
                         $outputContext.AuditLogs.Add([PSCustomObject]@{
                            Message = "Account: $($actionContext.References.Account). Has active keys which means keys must be returned before deleting person."
                            IsError = $true
                        })
                    }
                    2{
                         $outputContext.AuditLogs.Add([PSCustomObject]@{
                            Message = "Account: $($actionContext.References.Account). Has active user account in the locking system. Can't be deleted through API."
                            IsError = $true
                        })
                    }
                    3{
                         $outputContext.AuditLogs.Add([PSCustomObject]@{
                            Message = "Account: $($actionContext.References.Account). Has linked programming keys or network module. Remove this links before deleting person."
                            IsError = $true
                        })
                    }
                    4{
                         $outputContext.AuditLogs.Add([PSCustomObject]@{
                            Message = "Account: $($actionContext.References.Account). Has active user account in another locking system."
                            IsError = $true
                        })
                    }
                    5{
                         $outputContext.AuditLogs.Add([PSCustomObject]@{
                            Message = "Account: $($actionContext.References.Account). Is the same user currently logged in."
                            IsError = $true
                        })
                    }
                    6{
                         $outputContext.AuditLogs.Add([PSCustomObject]@{
                            Message = "Account: $($actionContext.References.Account). is S50 service user. This user can't be deleted."
                            IsError = $true
                        })
                    }
                    7{
                         $outputContext.AuditLogs.Add([PSCustomObject]@{
                            Message = "Account: $($actionContext.References.Account). Has calendar data orders which must be deleted first."
                            IsError = $true
                        })
                    }
                    8{
                         $outputContext.AuditLogs.Add([PSCustomObject]@{
                            Message = "Account: $($actionContext.References.Account). User has no right to delete person users."
                            IsError = $true
                        })
                    }
                    9{
                         $outputContext.AuditLogs.Add([PSCustomObject]@{
                            Message = "Account: $($actionContext.References.Account). Is last normal Manager user, it cannot be deleted otherwise only external users remain in system."
                            IsError = $true
                        })
                    }
                    -1{
                         $outputContext.AuditLogs.Add([PSCustomObject]@{
                            Message = "Account: $($actionContext.References.Account). Error occured. please check the api reference: https://s5.iloq.com/iLOQPublicApiDoc#operation/Persons_CanDelete"
                            IsError = $true
                        })
                    }
                    Default {
                         $outputContext.AuditLogs.Add([PSCustomObject]@{
                                Message = "Unkown return type from 'CanDelete' please check the api reference: https://s5.iloq.com/iLOQPublicApiDoc#operation/Persons_CanDelete"
                                IsError = $true
                            })
                    }
                }
                break
            }
            'NotFound' {
                $outputContext.Success = $true
                $outputContext.AuditLogs.Add([PSCustomObject]@{
                        Message = "Iloq account: [$($actionContext.References.Account)] for person: [$($personContext.Person.DisplayName)] could not be found, possibly indicating that it possibly indicating that it may already have been deleted"
                        IsError = $false
                    })
                break
            }
        }
    }
} catch {
    $outputContext.Success = $false
    $ex = $PSItem
    if ($($ex.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') -or
        $($ex.Exception.GetType().FullName -eq 'System.Net.WebException')) {
        $errorObj = Resolve-IloqError -ErrorObject $ex
        $auditMessage = "Could not delete Iloq account. Error: $($errorObj.FriendlyMessage)"
        Write-Warning "Error at Line '$($errorObj.ScriptLineNumber)': $($errorObj.Line). Error: $($errorObj.ErrorDetails)"
    }  else {
        $auditMessage = "Could not delete Iloq account. Error: $($_.Exception.Message)"
        Write-Warning "Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"
    }
    $outputContext.AuditLogs.Add([PSCustomObject]@{
            Message = $auditMessage
            IsError = $true
        })
}