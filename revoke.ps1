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

$account = [PSCustomObject]@{
    EmploymentEndDate = if ($null -ne $p.PrimaryContract.EndDate) { '{0:yyyy-MM-ddThh:mm:ss}' -f ([datetime]$p.PrimaryContract.EndDate) } else { '' };
}

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
        $zoneId = $getAllZonesResponse | Where-Object { $_.type -eq $ZoneIdType }
        if ($null -eq $zoneId) {
            throw 'No valid ZoneId Type [4] found. Please verify for iLOQ Configuration'
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
            Write-Verbose "ExpireDate of AccessKey [$($Key.Description)] not in sync. Updating ExpireDate"
            $Key.ExpireDate = $EndDate
            $bodyKey = @{
                Key = $Key
            } | ConvertTo-Json

            if (-not($dryRun -eq $true)) {
                $splatParams = @{
                    Uri         = "$($config.BaseUrl)/api/v2/Keys"
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
        Write-Verbose "Get KeyTimeLimitSlots of Key $($Key.Description)"
        $splatParams = @{
            Uri     = "$($config.BaseUrl)/api/v2/Keys/$($Key.FNKey_ID)/TimeLimitTitles?mode=0"
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
            Write-Verbose "EndDate Update required of AccessKey [$($Key.Description)]"
            Write-Verbose "Update TimeLimit of AccessKey: [$($Key.Description)]. New EndDate is [$($EndDate)]"

            # Retrieve the existing security accesses, Because updating Time Limits overwrites the existing accesses.
            $splatParams = @{
                Uri     = "$($config.BaseUrl)/api/v2/Keys/$($Key.FNKey_ID)/SecurityAccesses?mode=0"
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
            if ($dryRun -eq $true) {
                Write-Warning "[DryRun] Update EndDate AccessKey: [$($Key.Description)] will be executed during enforcement"
                Write-Verbose "Current EndDate [$($Key.ExpireDate)] New EndDate: [$($EndDate)]"
            }
            if (-not($dryRun -eq $true)) {
                $splatParams = @{
                    Uri         = "$($config.BaseUrl)/api/v2/Keys/$($Key.FNKey_ID)/SecurityAccesses"
                    Method      = 'PUT'
                    Headers     = $Headers
                    Body        = ($body | ConvertTo-Json -Depth 10)
                    ContentType = 'application/json; charset=utf-8'
                }
                $null = Invoke-RestMethod @splatParams -Verbose:$false
                $AuditLogs.Add([PSCustomObject]@{
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
#endregion

# Begin
try {
    try {
        Write-Verbose "Verifying if a iLOQ account for [$($p.DisplayName)] exists"
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
            $dryRunMessage = "Revoke iLOQ entitlement: [$($pRef.DisplayName)] to: [$($p.DisplayName)] will be executed during enforcement"
        }
    } catch {
        if ($_.ErrorDetails.Message -match 'Invalid value *') {
            $action = 'NotFound'
            $dryRunMessage = "iLOQ account for: [$($p.DisplayName)] not found. Possibly already deleted. Skipping action"
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
            Write-Verbose 'Verifying if an iLOQ account has access keys assigned'
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
                Write-Verbose "Revoking iLOQ entitlement: [$($pRef.DisplayName)]"
                foreach ($key in $responseKeys.Keys) {
                    # Updating Expire Date
                    $splatIloqAccessKeyExpireDate = @{
                        Key     = $key
                        EndDate = $account.EmploymentEndDate
                        Headers = $headers
                    }
                    Update-IloqAccessKeyExpireDate @splatIloqAccessKeyExpireDate

                    # Updating TimeLimitSlot
                    $splatIloqAccessKeyTimeLimitSlot = @{
                        Key     = $key
                        EndDate = $account.EmploymentEndDate
                        Headers = $headers
                    }
                    Update-IloqAccessKeyTimeLimitSlot @splatIloqAccessKeyTimeLimitSlot

                    # Revoking Security Accesses
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
                                    Message = "Revoke iLOQ entitlement: [$($pRef.DisplayName)] from key: [$($key.Description)] was successful"
                                    IsError = $false
                                })
                            }
                            break
                        }
                        2 {
                            $auditLogs.Add([PSCustomObject]@{
                                    Message = "Could not revoke iLOQ Key [$($key.Description)]. Key is in unmodifiable state, for ex. blacklisted."
                                    IsError = $true
                                })
                            break
                        }
                        3 {
                            $auditLogs.Add([PSCustomObject]@{
                                    Message = "Revoke iLOQ entitlement [$($pRef.DisplayName)] from Key [$($key.Description)] was successful. Security Access link already removed"
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

                    # Ordering Updated Access Key
                    if (($canDelete -eq 1) -or ($canDelete -eq 3)) {
                        Write-Verbose 'Checks if key can be ordered.'
                        $splatParams = @{
                            Uri     = "$($config.BaseUrl)/api/v2/Keys/$($key.FNKey_ID)/CanOrder"
                            Method  = 'GET'
                            Headers = $headers
                        }
                        $canOrder = Invoke-RestMethod @splatParams -Verbose:$false

                        if ($canOrder -eq 0) {
                            Write-Verbose 'Ok, can order key, ordering key..'
                            $splatParams = @{
                                Uri     = "$($config.BaseUrl)/api/v2/Keys/$($key.FNKey_ID)/Order"
                                Method  = 'GET'
                                Headers = $headers
                            }
                            $null = Invoke-RestMethod @splatParams -Verbose:$false
                            $success = $true
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
                            Write-Verbose "$($canOrderAuditMessage)"
                            $auditLogs.Add([PSCustomObject]@{
                                    Message = "Could not grant iLOQ entitlement [$($pRef.DisplayName)] to key: [$($key.Description)]. $($canOrderAuditMessage)"
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
                    Message = "iLOQ account for: [$($p.DisplayName)] not found. Possibly already deleted. Skipping action"
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
    if (-not ($auditLogs.isError -contains $true)) {
        $success = $true
    }

} catch {
    $success = $false
    $ex = $PSItem
    if ($($ex.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') -or
        $($ex.Exception.GetType().FullName -eq 'System.Net.WebException')) {
        $errorObj = Resolve-IloqError -ErrorObject $ex
        $auditMessage = "Could not revoke iLOQ entitlement. Error: $($errorObj.FriendlyMessage)"
        Write-Verbose "Error at Line '$($errorObj.ScriptLineNumber)': $($errorObj.Line). Error: $($errorObj.ErrorDetails)"
    } else {
        $auditMessage = "Could not revoke iLOQ entitlement. Error: $($ex.Exception.Message)"
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
