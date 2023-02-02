#####################################################
# HelloID-Conn-Prov-Target-iloq-Delete
#
# Version: 1.0.0
#####################################################
# Initialize default values
$config = $configuration | ConvertFrom-Json
$p = $person | ConvertFrom-Json
$aRef = $AccountReference | ConvertFrom-Json
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
            Uri    = "$($config.BaseUrl)/api/v2/CreateSession"
            Method = 'POST'
            Headers = $headers
            Body = @{
                'CustomerCode' = $($config.CustomerCode)
                'UserName'     = $($config.UserName)
                'Password'     = $($config.Password)
            } | ConvertTo-Json
        }
        $response = Invoke-RestMethod @params
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
        $response = Invoke-RestMethod @params
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
            Body = @{
                'LockGroup_ID' = $LockGroupId
            } | ConvertTo-Json
        }
        $response = Invoke-RestMethod @params
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
        $resolvedUrl = Invoke-RestMethod @splatParams

        if ([string]::IsNullOrEmpty($resolvedUrl) ) {
            Write-Verbose "No Resolved - URL found, keep on using the URL provided: $($config.BaseUrl)."
        } else {
            Write-Verbose "Resolved - URL found [$resolvedUrl , Using the found url to execute the following requests."
            $config.BaseUrl =  $resolvedUrl
        }
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
    # First step is to get the correct url to use for the rest of the API calls.
    $null =  Set-IloqResolvedURL -Config $config

    # Get the Iloq sessionId
    $sessionId = Get-IloqSessionId -Config $config

    # Get the Iloq lockGroupId
    $lockGroupId = Get-IloqLockGroupId -Config $config -SessionId $sessionId

    # Set the Iloq lockGroup in order to make authenticated calls
    $null = Set-IloqLockGroup -Config $config -SessionId $sessionId -LockGroupId $lockGroupId

    Write-Verbose 'Adding authorization headers'
    $headers = [System.Collections.Generic.Dictionary[string, string]]::new()
    $headers.Add('Content-Type', 'application/json; charset=utf-8')
    $headers.Add('SessionId', $sessionId)

    try {
        Write-Verbose "verifying if a iLOQ account for [$($p.Name.GivenName)] exists"

        $splatParams = @{
            Uri         = "$($config.BaseUrl)/api/v2/Persons/$($aRef)"
            Method      = 'GET'
            Headers     = $headers
            ContentType = 'application/json; charset=utf-8'
        }

        $responseUser = Invoke-RestMethod @splatParams
        $action = 'Found'
        $dryRunMessage = "Delete iLOQ account for: [$($p.Name.GivenName)] will be executed during enforcement"
    }
    catch{
        $action = 'NotFound'
        $dryRunMessage = "iLOQ account for: [$($p.Name.GivenName)] not found. Possibly already deleted. Skipping action "    
    }

    # Add an auditMessage showing what will happen during enforcement
    if ($dryRun -eq $true) {
        Write-Warning "[dryrun] $($dryRunMessage)"
    }

    if (-not($dryRun -eq $true)) {
        switch ($action) {
            'Found' { 
                Write-Verbose "Deleting iLOQ account with accountReference: [$aRef]"
                $splatParams = @{
                    Uri         = "$($config.BaseUrl)/api/v2/Persons/$($aRef)/CanDelete"
                    Method      = 'GET'
                    Headers     = $headers
                    ContentType = 'application/json; charset=utf-8'
                }

                $canDeleteResult = Invoke-RestMethod @splatParams

                switch ($canDeleteResult) {
                    0 {  
                        $splatParams = @{
                            Uri         = "$($config.BaseUrl)/api/v2/Persons/$($aRef)"
                            Method      = 'DEL'
                            Headers     = $headers
                            ContentType = 'application/json; charset=utf-8'
                        }
        
                        $null = Invoke-RestMethod @splatParams
                        
                        $auditLogs.Add([PSCustomObject]@{
                            Message = "Account: $($aRef). Delete account was successfull"
                            IsError = $false
                        })
                    }
                    1 {
                        $auditLogs.Add([PSCustomObject]@{
                            Message = "Account: $($aRef). Has active keys which means keys must be returned before deleting person."
                            IsError = $true
                        })
                    }
                    2{
                        $auditLogs.Add([PSCustomObject]@{
                            Message = "Account: $($aRef). Has active user account in the locking system. Can't be deleted through API."
                            IsError = $true
                        })
                    }
                    3{
                        $auditLogs.Add([PSCustomObject]@{
                            Message = "Account: $($aRef). Has linked programming keys or network module. Remove this links before deleting person."
                            IsError = $true
                        })
                    }
                    4{
                        $auditLogs.Add([PSCustomObject]@{
                            Message = "Account: $($aRef). Has active user account in another locking system."
                            IsError = $true
                        })
                    }
                    5{
                        $auditLogs.Add([PSCustomObject]@{
                            Message = "Account: $($aRef). Is the same user currently logged in."
                            IsError = $true
                        })
                    }
                    6{
                        $auditLogs.Add([PSCustomObject]@{
                            Message = "Account: $($aRef). is S50 service user. This user can't be deleted."
                            IsError = $true
                        })
                    }
                    7{
                        $auditLogs.Add([PSCustomObject]@{
                            Message = "Account: $($aRef). Has calendar data orders which must be deleted first."
                            IsError = $true
                        })
                    }
                    8{
                        $auditLogs.Add([PSCustomObject]@{
                            Message = "Account: $($aRef). User has no right to delete person users."
                            IsError = $true
                        })
                    }
                    9{
                        $auditLogs.Add([PSCustomObject]@{
                            Message = "Account: $($aRef). Is last normal Manager user, it cannot be deleted otherwise only external users remain in system."
                            IsError = $true
                        })
                    }
                    -1{
                        $auditLogs.Add([PSCustomObject]@{
                            Message = "Account: $($aRef). Error occured. please check the api reference: https://s5.iloq.com/iLOQPublicApiDoc#operation/Persons_CanDelete"
                            IsError = $true
                        })
                    }
                    Default {
                        $auditLogs.Add([PSCustomObject]@{
                                Message = "Unkown return type from 'CanDelete' please check the api reference: https://s5.iloq.com/iLOQPublicApiDoc#operation/Persons_CanDelete"
                                IsError = $true
                            })
                    }
                }
                $success = $true
            }
            'NotFound' {
                $success = $true
                $auditLogs.Add([PSCustomObject]@{
                    Message = $dryRunMessage
                    IsError = $false
                })
            }
        }
    }
} catch {
    $success = $false
    $ex = $PSItem
    if ($($ex.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') -or
        $($ex.Exception.GetType().FullName -eq 'System.Net.WebException')) {
        $errorObj = Resolve-IloqError -ErrorObject $ex
        $errorMessage = "Could not delete iLOQ account. Error: $($errorObj.ErrorMessage)"
    } else {
        $errorMessage = "Could not delete iLOQ account. Error: $($ex.Exception.Message)"
    }
    Write-Verbose $errorMessage
    $auditLogs.Add([PSCustomObject]@{
            Message = $errorMessage
            IsError = $true
        })
} finally {
    $result = [PSCustomObject]@{
        Success   = $success
        Auditlogs = $auditLogs
    }
    Write-Output $result | ConvertTo-Json -Depth 10
}