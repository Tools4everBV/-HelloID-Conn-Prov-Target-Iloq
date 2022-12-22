#####################################################
# HelloID-Conn-Prov-Target-iloq-Disable
#
# Version: 1.0.0
#####################################################
# Initialize default values
$config = $configuration | ConvertFrom-Json
$p = $person | ConvertFrom-Json
$aRef = $AccountReference | ConvertFrom-Json
$success = $false
$auditLogs = [System.Collections.Generic.List[PSCustomObject]]::new()

# Account mapping
$account = [PSCustomObject]@{
    person = @{
        CompanyName       = ''
        ContactInfo       = ''
        Country           = ''
        Description       = ''
        EmploymentEndDate = $p.PrimaryContract.EndDate
        ExternalCanEdit   = ''
        ExternalPersonId  = $p.ExternalId
        FirstName         = $p.Name.GivenName
        LanguageCode      = ''
        LastName          = $p.Name.FamilyName
        Person_ID         = '' #leave empty Iloq generates this automaticaly
        Phone1            = ''
        Phone2            = ''
        Phone3            = ''
        PostOffice        = ''
        State             = ''
        WorkTitle         = $p.PrimaryContract.Title.Name
        ZipCode           = ''
        # Mandatory fields
        eMail             = $p.Contact.Business.Email
        PersonCode        = $p.ExternalId
        Address           = ''
    }
    # The ZoneIds are mandatory when creating a new person
    ZoneIds = @()
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
        $response = Invoke-RestMethod @params
        Write-Output $response.SessionID
    }
    catch {
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
    }
    catch {
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
        $response = Invoke-RestMethod @params
        Write-Output $response.LockGroup_ID
    }
    catch {
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
        }
        else {
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
        Write-Verbose "verifying if a iLOQ account for [$($account.person.FirstName)] exists"

        $splatParams = @{
            Uri         = "$($config.BaseUrl)/api/v2/Persons/$($aRef)"
            Method      = 'GET'
            Headers     = $headers
            ContentType = 'application/json; charset=utf-8'
        }

        $responseUser = Invoke-RestMethod @splatParams
        $action = 'Found'
        $dryRunMessage = "Disable iLOQ account for: [$($account.person.FirstName)] will be executed during enforcement"
    }
    catch{
        $action = 'NotFound'
        $dryRunMessage = "iLOQ account for: [$($account.person.FirstName)] not found. Possibly already deleted. Skipping action "    
    }

    Write-Verbose $dryRunMessage

    # Add an auditMessage showing what will happen during enforcement
    if ($dryRun -eq $true) {
        Write-Warning "[dryrun] $($dryRunMessage)"
    }

    if (-not($dryRun -eq $true)) {
        switch ($action) {
            'Found' { 
                Write-Verbose "Disabling iLOQ account with accountReference: [$aRef]"

                $account.person.EmploymentEndDate = "$(Get-Date)"
                $account.person.Person_ID = $aRef
        
                $splatParams = @{
                    Uri         = "$($config.BaseUrl)/api/v2/Persons"
                    Method      = 'PUT'
                    Headers     = $headers
                    Body        = $account | ConvertTo-Json
                    ContentType = 'application/json; charset=utf-8'
                }

                $null = Invoke-RestMethod @splatParams

                #get keys for person
                $splatParams = @{
                    Uri         = "$($config.BaseUrl)/api/v2/Persons/$($aRef)/Keys"
                    Method      = 'GET'
                    Headers     = $headers
                    ContentType = 'application/json; charset=utf-8'
                }

                $keys = Invoke-RestMethod @splatParams

                if ($keys.keys.count -eq 0) {
                    $auditLogs.Add([PSCustomObject]@{
                            Message = "Account: $($aRef). Has no keys to return"
                            IsError = $false
                        })
                }
                else {
                    foreach ($key in $keys.keys) {
                        #Check if key can be returned $($key.FNKey_ID)
                        $splatParams = @{
                            Uri         = "$($config.BaseUrl)/api/v2/Keys/$($key.FNKey_ID)/CanReturn"
                            Method      = 'GET'
                            Headers     = $headers
                            ContentType = 'application/json; charset=utf-8'
                        }
        
                        $result = Invoke-RestMethod @splatParams 
                        switch ($result) {
                            0 { 
                                #return keys
                                $splatParams = @{
                                    Uri         = "$($config.BaseUrl)/api/v2/Keys/$($key.FNKey_ID)/Return"
                                    Method      = 'POST'
                                    Headers     = $headers
                                    Body        = $account | ConvertTo-Json
                                    ContentType = 'application/json; charset=utf-8'
                                }
                
                                $null = Invoke-RestMethod @splatParams 

                                $auditLogs.Add([PSCustomObject]@{
                                        Message = "Account: $($aRef). Revoke key [$($key.FNKey_ID)] was successfull"
                                        IsError = $false
                                    })
                            }
                            1 {
                                $auditLogs.Add([PSCustomObject]@{
                                        Message = "Account: $($aRef). Returning key [$($key.FNKey_ID)] requires iLOQ Manager + token."
                                        IsError = $true
                                    })
                            }
                            2 {
                                $auditLogs.Add([PSCustomObject]@{
                                        Message = "Account: $($aRef). Key [$($key.FNKey_ID)]  isn't a phone and can't be returned using public api."
                                        IsError = $true
                                    })
                            }
                            3 {
                                $auditLogs.Add([PSCustomObject]@{
                                        Message = "Account: $($aRef). Key [$($key.FNKey_ID)]  has never been programmed. It can't be returned before it's programmed. Call Delete endpoint instead."
                                        IsError = $true
                                    })
                            }
                            Default {
                                $auditLogs.Add([PSCustomObject]@{
                                        Message = "Unkown return type from 'CanReturn' please check the api reference: https://s5.iloq.com/iLOQPublicApiDoc#operation/Keys_CanReturnKey"
                                        IsError = $true
                                    })
                            }
                        }
                    }
                }
                $success = $true
                $auditLogs.Add([PSCustomObject]@{
                        Message = 'Disable account was successful'
                        IsError = $false
                    })
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
}
catch {
    $success = $false
    $ex = $PSItem
    if ($($ex.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') -or
        $($ex.Exception.GetType().FullName -eq 'System.Net.WebException')) {
        $errorObj = Resolve-IloqError -ErrorObject $ex
        $auditMessage = "Could not disable iLOQ account. Error: $($errorObj.FriendlyMessage)"
        Write-Verbose "Error at Line '$($errorObj.ScriptLineNumber)': $($errorObj.Line). Error: $($errorObj.ErrorDetails)"
    }
    else {
        $auditMessage = "Could not disable iLOQ account. Error: $($ex.Exception.Message)"
        Write-Verbose "Error at Line '$($ex.ScriptLineNumber)': $($ex.Line). Error: $($ex.Exception.Message)"
    }
    $auditLogs.Add([PSCustomObject]@{
            Message = $auditMessage
            IsError = $true
        })         
}
finally {
    $result = [PSCustomObject]@{
        Success   = $success
        Auditlogs = $auditLogs
    }
    Write-Output $result | ConvertTo-Json -Depth 10
}
