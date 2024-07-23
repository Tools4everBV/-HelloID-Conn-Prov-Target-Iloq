################################################################
# HelloID-Conn-Prov-Target-Iloq-GrantPermission-Group
# PowerShell V2
################################################################

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

function Confirm-UpdateRequiredExpireDate {
    [CmdletBinding()]
    param(
        [Parameter()]
        $NewEndDate,

        [Parameter()]
        $CurrentEndDate
    )
    if (-not [string]::IsNullOrEmpty($NewEndDate)) {
        $_enddate = ([Datetime]$NewEndDate).ToShortDateString()
    }
    if (-not [string]::IsNullOrEmpty($CurrentEndDate)) {
        $_currentEnddate = ([Datetime]$CurrentEndDate).ToShortDateString()
    }
    if ($_currentEnddate -ne $_enddate) {
        Write-Output $true
    }
}
function Update-ILOQAccessKeyExpireDate {
    [CmdletBinding()]
    param(
        [Parameter(mandatory)]
        $Key,

        [Parameter(mandatory)]
        [AllowNull()]
        $EndDate,

        [Parameter(mandatory)]
        $Headers
    )
    try {
        if (Confirm-UpdateRequiredExpireDate -NewEndDate $EndDate -CurrentEndDate $Key.ExpireDate) {
            Write-Information "ExpireDate of AccessKey [$($Key.Description)] not in sync. Updating ExpireDate"
            $Key.ExpireDate = $EndDate
            $bodyKey = @{
                Key = $Key
            } | ConvertTo-Json

            if (-not($actionContext.dryRun -eq $true)) {
                $splatParams = @{
                    Uri         = "$($actionContext.Configuration.BaseUrl)/api/v2/Keys"
                    Method      = 'PUT'
                    Headers     = $Headers
                    Body        = $bodyKey
                    ContentType = 'application/json; charset=utf-8'
                }
                $null = Invoke-RestMethod @splatParams -Verbose:$false
            }
        }
    } catch {
        $PSCmdlet.ThrowTerminatingError($_)
    }
}
function Update-IloqAccessKeyTimeLimitSlot {
    [CmdletBinding()]
    param(
        [Parameter(mandatory)]
        $Key,

        [Parameter(mandatory)]
        [AllowNull()]
        $EndDate,

        [Parameter(mandatory)]
        $Headers
    )
    try {
        Write-Information "Get KeyTimeLimitSlots of Key $($Key.Description)"
        $splatParams = @{
            Uri     = "$($actionContext.Configuration.BaseUrl)/api/v2/Keys/$($Key.FNKey_ID)/TimeLimitTitles?mode=0"
            Method  = 'GET'
            Headers = $Headers
        }
        $TimeLimitTitles = Invoke-RestMethod @splatParams -Verbose:$false
        $endDateObject = $TimeLimitTitles.KeyTimeLimitSlots | Where-Object { $_.slotNo -eq 1 }
        $currentEndDate = $null
        if ($null -ne $endDateObject ) {
            $currentEndDate = $endDateObject.LimitDateLg
        }
        if (Confirm-UpdateRequiredExpireDate -NewEndDate $EndDate -CurrentEndDate $currentEndDate) {
            Write-Information "EndDate Update required of AccessKey [$($Key.Description)]"
            Write-Information "Update TimeLimit of AccessKey: [$($Key.Description)]. New EndDate is [$($EndDate)]"

            # Retrieve the existing security accesses, Because updating Time Limits overwrites the existing accesses.
            $splatParams = @{
                Uri     = "$($actionContext.Configuration.BaseUrl)/api/v2/Keys/$($Key.FNKey_ID)/SecurityAccesses?mode=0"
                Method  = 'GET'
                Headers = $Headers
            }
            $currentSecurityAccesses = ([array](Invoke-RestMethod @splatParams -Verbose:$false).SecurityAccesses)

            $body = @{
                KeyScheduler                       = @{}
                OfflineExpirationSeconds           = 0
                OutsideUserZoneTimeLimitTitleSlots = @()
                SecurityAccessIds                  = @()
                TimeLimitSlots                     = @()
            }
            if ( $null -ne $currentSecurityAccesses.SecurityAccess_ID  ) {
                $body.SecurityAccessIds += $currentSecurityAccesses.SecurityAccess_ID
            }

            if (-not ([string]::IsNullOrEmpty($EndDate))) {
                $body.TimeLimitSlots += @{
                    LimitDateLg   = $EndDate
                    SlotNo        = 1
                    TimeLimitData = @()
                }
            }
            if ($actionContext.dryRun -eq $true) {
                Write-Warning "[DryRun] Update EndDate AccessKey: [$($Key.Description)] will be executed during enforcement"
                Write-Information "Current EndDate [$($Key.ExpireDate)] New EndDate: [$($EndDate)]"
            }
            if (-not($actionContext.dryRun -eq $true)) {
                $splatParams = @{
                    Uri         = "$($actionContext.Configuration.BaseUrl)/api/v2/Keys/$($Key.FNKey_ID)/SecurityAccesses"
                    Method      = 'PUT'
                    Headers     = $Headers
                    Body        = ($body | ConvertTo-Json -Depth 10)
                    ContentType = 'application/json; charset=utf-8'
                }
                $null = Invoke-RestMethod @splatParams -Verbose:$false
                $outputContext.AuditLogs.Add([PSCustomObject]@{
                        Action  = 'UpdateAccount'
                        Message = "Update end date AccessKey: [$($key.Description)] was successful"
                        IsError = $false
                    })
            }
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


# Begin
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
        if ($_.Errordetails.message -match 'Invalid value') {
            $correlatedAccount = $null
        } else{
            throw $_
        }
    }

    if ($null -ne $correlatedAccount) {

        Write-Information 'Verifying if an iLOQ account has access keys assigned'
        $splatParams = @{
            Uri         = "$($actionContext.Configuration.BaseUrl)/api/v2/Persons/$($actionContext.References.Account)/Keys"
            Method      = 'GET'
            Headers     = $headers
            ContentType = 'application/json; charset=utf-8'
        }
        $responseKeys = Invoke-RestMethod @splatParams -Verbose:$false

        if ($responseKeys.keys.Length -eq 0) {
            $action = 'KeysNotFound'
            $dryRunMessage = "Iloq account: [$($actionContext.References.Account)] for person: [$($personContext.Person.DisplayName)] has no keys, possibly indicating that it is disabled"
        } else {
            $action = 'GrantPermission'
            $dryRunMessage = "Grant Iloq permission: [$($actionContext.References.Permission.DisplayName)] will be executed during enforcement"
        }
    } else {
        $action = 'NotFound'
        $dryRunMessage = "Iloq account: [$($actionContext.References.Account)] for person: [$($personContext.Person.DisplayName)] could not be found, indicating that it may have been deleted"
    }

    # Add a message and the result of each of the validations showing what will happen during enforcement
    if ($actionContext.DryRun -eq $true) {
        Write-Information "[DryRun] $dryRunMessage"
    }

    # Process

    switch ($action) {
        'GrantPermission' {
            Write-Information "Granting Iloq permission: [$($actionContext.References.Permission.DisplayName)] - [$($actionContext.References.Permission.Reference)]"

            foreach ($key in $responseKeys.Keys) {
                $splatIloqAccessKeyExpireDate = @{
                    Key     = $key
                    EndDate = $account.EmploymentEndDate
                    Headers = $headers
                }
                Update-IloqAccessKeyExpireDate @splatIloqAccessKeyExpireDate

                $splatIloqAccessKeyTimeLimitSlot = @{
                    Key     = $key
                    EndDate = $account.EmploymentEndDate
                    Headers = $headers
                }
                Update-IloqAccessKeyTimeLimitSlot @splatIloqAccessKeyTimeLimitSlot

                if ($actionContext.DryRun -eq $true) {
                    Write-Information "[DryRun] Grant iLOQ permission: [$($actionContext.References.Permission.DisplayName)] to key : [$($key.Description)] will be executed during enforcement"
                }
                if (-not($actionContext.DryRun -eq $true)) {
                    Write-Information "Granting iLOQ permission: [$($actionContext.References.Permission.DisplayName)] to key : [$($key.Description)]"

                    # Granting Security Accesses
                    $splatParams = @{
                        Uri     = "$($actionContext.Configuration.BaseUrl)/api/v2/Keys/$($key.FNKey_ID)/SecurityAccesses/CanAdd"
                        Method  = 'GET'
                        Headers = $headers
                    }
                    $canAdd = Invoke-RestMethod @splatParams -Verbose:$false

                    switch ($canAdd) {
                        1 {
                            $body = @{
                                SecurityAccess_ID = $actionContext.References.Permission.Reference
                            }
                            $splatParams = @{
                                Uri         = "$($actionContext.Configuration.BaseUrl)/api/v2/Keys/$($key.FNKey_ID)/SecurityAccesses"
                                Method      = 'POST'
                                Headers     = $headers
                                Body        = $body | ConvertTo-Json
                                ContentType = 'application/json; charset=utf-8'
                            }
                            $null = Invoke-RestMethod @splatParams -Verbose:$false # 204
                            $outputContext.SubPermissions.Add([PSCustomObject]@{
                                    DisplayName = "Person [$($responseUser.PersonCode)] - AccessKey [$($key.Description)]"
                                    Reference   = [PSCustomObject]@{
                                        AccessKey  = $($key.Description)
                                        Permission = $actionContext.References.Permission.DisplayName
                                    }
                                })
                            break
                        }
                        2 {
                            $outputContext.AuditLogs.Add([PSCustomObject]@{
                                    Message = "Could not grant iLOQ permission [$($actionContext.References.Permission.DisplayName)] to key: [$($key.Description)]. Key is in unmodifiable state, for ex. blacklisted"
                                    IsError = $true
                                })
                            break
                        }
                        3 {
                            $outputContext.AuditLogs.Add([PSCustomObject]@{
                                    Message = "Could not grant iLOQ permission [$($actionContext.References.Permission.DisplayName)] to key: [$($key.Description)]. Key has maximum number of security accesses"
                                    IsError = $true
                                })
                            break
                        }
                    }

                    # Ordering Updated Access Key
                    if ($canAdd -eq 1) {
                        Write-Information 'Checks if key can be ordered.'
                        $splatParams = @{
                            Uri     = "$($actionContext.Configuration.BaseUrl)/api/v2/Keys/$($key.FNKey_ID)/CanOrder"
                            Method  = 'GET'
                            Headers = $headers
                        }
                        $canOrder = Invoke-RestMethod @splatParams -Verbose:$false

                        if ($canOrder -eq 0) {
                            Write-Information 'Ok, can order key, ordering key..'
                            $splatParams = @{
                                Uri     = "$($actionContext.Configuration.BaseUrl)/api/v2/Keys/$($key.FNKey_ID)/Order"
                                Method  = 'GET'
                                Headers = $headers
                            }
                            $null = Invoke-RestMethod @splatParams -Verbose:$false
                            $outputContext.AuditLogs.Add([PSCustomObject]@{
                                    Message = "Grant iLOQ permission: [$($actionContext.References.Permission.DisplayName)] to key: [$($key.Description)] was successful"
                                    IsError = $false
                                })
                        } else {
                            $canOrderAuditMessage = switch ($canOrder) {
                                1 { 'Key has changes which require iLOQ Manager + token to order.'; break; }
                                2 { "Key isn't a phone or 5 Series key and can't be ordered using public api"; break; }
                                3 { "Key can't be ordered because the license limit has been exceeded. Return keys or contact iLOQ to acquire more licenses."; break; }
                                4 { 'Key is in wrong state. Only keys in planning state can be ordered.'; break; }
                                5 { "Key's id is too large."; break; }
                                6 { 'Key has security accesses which are outside his zones. This can only occur if key is a new key.'; break; }
                                7 { 'Key has time limits which are outside his zones. This can only occur if key is a new key.'; break; }
                                8 { 'Key is in block list.'; break; }
                                9 { "Phone key doesn't have phone number set on FNKeyPhone"; break; }
                                10 { "Phone key doesn't have email address set on FNKeyPhone and FNKeyPhone.OptionMask states that messages are sent via email."; break; }
                                11 { 'Key has too many timelimits defined.'; break; }
                                12 { 'Key main zone is not set and is required.'; break; }
                                13 { "Key doesn't have person attached in to it"; break; }
                                14 { "External Key doesn't have TagKey set"; break; }
                                -1 { 'Error occurred during checking'; break; }
                            }
                            Write-Information "$($canOrderAuditMessage)"
                            $outputContext.AuditLogs.Add([PSCustomObject]@{
                                    Message = "Could not grant iLOQ permission [$($actionContext.References.Permission.DisplayName)] to key: [$($key.Description)]. $($canOrderAuditMessage)"
                                    IsError = $true
                                })
                        }
                    }
                }
            }

            if( -not ($outputContext.AuditLogs.isError -contains $true) ){
                $outputContext.Success = $false
            }

        }

        'KeysNotFound' {
            $outputContext.Success = $false
            $outputContext.AuditLogs.Add([PSCustomObject]@{
                    Message = "Iloq account: [$($actionContext.References.Account)] for person: [$($personContext.Person.DisplayName)] has no keys, possibly indicating that it is disabled"
                    IsError = $true
                })
        }
        'NotFound' {
            $outputContext.Success = $false
            $outputContext.AuditLogs.Add([PSCustomObject]@{
                    Message = "Iloq account: [$($actionContext.References.Account)] for person: [$($personContext.Person.DisplayName)] could not be found, possibly indicating that it could be deleted, or the account is not correlated"
                    IsError = $true
                })
            break
        }
    }
} catch {
    $outputContext.Success = $false
    $ex = $PSItem
    if ($($ex.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') -or
        $($ex.Exception.GetType().FullName -eq 'System.Net.WebException')) {
        $errorObj = Resolve-IloqError -ErrorObject $ex
        $auditMessage = "Could not grant Iloq permission. Error: $($errorObj.FriendlyMessage)"
        Write-Warning "Error at Line '$($errorObj.ScriptLineNumber)': $($errorObj.Line). Error: $($errorObj.ErrorDetails)"
    } else {
        $auditMessage = "Could not grant Iloq permission. Error: $($_.Exception.Message)"
        Write-Warning "Error at Line '$($ex.InvocationInfo.ScriptLineNumber)': $($ex.InvocationInfo.Line). Error: $($ex.Exception.Message)"
    }
    $outputContext.AuditLogs.Add([PSCustomObject]@{
            Message = $auditMessage
            IsError = $true
        })
}