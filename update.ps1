#####################################################
# HelloID-Conn-Prov-Target-Iloq-update
#
# Version: 1.0.0
#####################################################
# Initialize default values
$config = $configuration | ConvertFrom-Json
$p = $person | ConvertFrom-Json
$aRef = $AccountReference | ConvertFrom-Json
$success = $false
$auditLogs = [System.Collections.Generic.List[PSCustomObject]]::new()

#Generation of the LastName combined with middleName
$middleName = $p.Name.familyNamePrefix
$lastName = $p.Name.familyName;
$middleNamePartner = $p.Name.familyNamePartnerPrefix
$lastNamePartner = $p.Name.familyNamePartner
$nameConvention = $p.Name.Convention

$LastnameFormatted = $null

switch ($nameConvention) {
    "B" {
        if (($null -eq $middleName) -Or ($middleName -eq "")){
            $LastnameFormatted = $lastName
        } else{
            $LastnameFormatted = $middleName + " " + $lastName
        }
    }
    "BP" {
        if (($null -eq $middleName) -Or ($middleName -eq "")){
            $LastnameFormatted = $lastName
        } else{
            $LastnameFormatted = $middleName + " " + $lastName
        }
        if (($null -eq $middleNamePartner) -Or ($middleNamePartner -eq "")){
            $LastnameFormatted = $LastnameFormatted + " - " + $lastNamePartner
        } else{
            $LastnameFormatted = $LastnameFormatted + " - " + $middleNamePartner + " " + $lastNamePartner
        }
    }
    "P" {
        if (($null -eq $middleNamePartner) -Or ($middleNamePartner -eq "")){
            $LastnameFormatted = $lastNamePartner
        } else{
            $LastnameFormatted = $middleNamePartner + " " + $lastNamePartner
        }
    }
    "PB" {
        if (($null -eq $middleNamePartner) -Or ($middleNamePartner -eq "")){
            $LastnameFormatted = $lastNamePartner
        } else{
            $LastnameFormatted = $middleNamePartner + " " + $lastNamePartner
        }
        if (($null -eq $middleName) -Or ($middleName -eq "")){
            $LastnameFormatted = $LastnameFormatted + " - " + $lastName
        } else{
            $LastnameFormatted = $LastnameFormatted + " - " + $middleName + " " + $lastName
        }
    }
    Default{
        if (($null -eq $middleName) -Or ($middleName -eq "")){
            $LastnameFormatted = $lastName
        } else{
            $LastnameFormatted = $middleName + " " + $lastName
        }
    }
}

#Formatting Phone1 (mobile phone, can be customer specific)
$ContactPhone = $p.Contact.Business.Phone.Mobile
If(-not ([string]::IsNullOrEmpty($ContactPhone))){
    $phone1 = $ContactPhone.Replace("-","")
    $phone1 = "+31" + [String]::Format('{0:#########}',[int]$phone1)
    $auditLogs.Add([PSCustomObject]@{
    Action = "UpdateAccount"; #Optionally specify a different action for this audit log
    Message = "Phone number successfully formatted";
    IsError = $False;
    });
}Else{
    $phone1 = $null
    $auditLogs.Add([PSCustomObject]@{
    Action = "UpdateAccount"; #Optionally specify a different action for this audit log
    Message = "Phone number not present in person object, set to NULL";
    IsError = $False;
    });
}


# Account mapping
$account = [PSCustomObject]@{
    person = @{
        CompanyName       = $p.PrimaryContract.Department.DisplayName
        ContactInfo       = ""
        Country           = ""
        Description       = ""
        EmploymentEndDate = if ($null -ne $p.PrimaryContract.EndDate) { '{0:yyyy-MM-ddThh:mm:ss}' -f ([datetime]$p.PrimaryContract.EndDate) } else { '' };
        ExternalCanEdit   = ""
        ExternalPersonId  = $p.ExternalId
        FirstName         = $p.Name.NickName
        LanguageCode      = "NL"
        LastName          = $LastnameFormatted
        Person_ID         = $aRef
        Phone1            = $phone1
        Phone2            = ""
        Phone3            = ""
        PostOffice        = ""
        State             = ""
        WorkTitle         = $p.PrimaryContract.Title.Name
        ZipCode           = ""

        # Mandatory fields
        eMail             = $p.Contact.Business.Email
        PersonCode        = $p.ExternalId
        Address           = ''
    }
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
        $response = Invoke-RestMethod @params -Verbose:$false
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
        $response = Invoke-RestMethod @params -Verbose:$false
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
        $response = Invoke-RestMethod @params -Verbose:$false
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
        $resolvedUrl = Invoke-RestMethod @splatParams -Verbose:$false

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

function Confirm-IloqAccessKeyEndDate {
    [CmdletBinding()]
    param(
        [string]
        [Parameter(Mandatory)]
        $PersonId,

        [Parameter(Mandatory)]
        $Headers,

        [Parameter()]
        [AllowNull()]
        $EndDate
    )
    try {
        Write-Verbose 'Verifying if an iLOQ account has access keys assigned'
        $splatParams = @{
            Uri         = "$($config.BaseUrl)/api/v2/Persons/$($PersonId)/Keys"
            Method      = 'GET'
            Headers     = $Headers
            ContentType = 'application/json; charset=utf-8'
        }
        $responseKeys = Invoke-RestMethod @splatParams -Verbose:$false

        if ($responseKeys.keys.Length -eq 0) {
            throw  "No Keys assigned to Person: [$($responseUser.PersonCode)] Aref: [$($PersonId)]"
        } else {
            Write-Verbose "Checking if the end date needs to be updated for the assigned access keys [$($responseKeys.Keys.Description -join ', ')]"
            foreach ($key in $responseKeys.Keys) {
                $splatIloqAccessKeyExpireDate = @{
                    Key     = $key
                    EndDate = $EndDate
                    Headers = $headers
                }
                Update-IloqAccessKeyExpireDate @splatIloqAccessKeyExpireDate

                $splatIloqAccessKeyTimeLimitSlot = @{
                    Key     = $key
                    EndDate = $EndDate
                    Headers = $headers
                }
                Update-IloqAccessKeyTimeLimitSlot @splatIloqAccessKeyTimeLimitSlot
            }
        }
    } catch {
        Write-Warning "Could not update AccessKey for person [$($PersonId)] Error: $($_)"
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

try {
    Write-Verbose "Updating iLOQ account with accountReference: [$aRef]"

    # First step is to get the correct url to use for the rest of the API calls.
    $null = Set-IloqResolvedURL -Config $config

    # Get the iLOQ sessionId
    $sessionId = Get-IloqSessionId -Config $config

    # Get the iLOQ lockGroupId
    $lockGroupId = Get-IloqLockGroupId -Config $config -SessionId $sessionId

    # Set the iLOQ lockGroup in order to make authenticated calls
    $null = Set-IloqLockGroup -Config $config -SessionId $sessionId -LockGroupId $lockGroupId

    Write-Verbose 'Adding authorization headers'
    $headers = [System.Collections.Generic.Dictionary[string, string]]::new()
    $headers.Add('Content-Type', 'application/json; charset=utf-8')
    $headers.Add('SessionId', $sessionId)

    if ($null -eq $aRef) {
        throw  'No account Reference found.'
    }

    try {
        Write-Verbose "Verifying if iLOQ account for [$($account.person.FirstName)] exists"
        $splatParams = @{
            Uri         = "$($config.BaseUrl)/api/v2/Persons/$($aRef)"
            Method      = 'GET'
            Headers     = $headers
            ContentType = 'application/json; charset=utf-8'
        }

        $responseUser = Invoke-RestMethod @splatParams -Verbose:$false
        $dryRunMessage = "Update iLOQ account for: [$($account.person.FirstName)] will be executed during enforcement"
    } catch {
        throw "iLOQ account for: [$($account.person.FirstName)] not found. Possibly already deleted."
    }

    # Add an auditMessage showing what will happen during enforcement
    if ($dryRun -eq $true) {
        $auditLogs.Add([PSCustomObject]@{
                Message = "[dryrun] $($dryRunMessage)"
            })
    }

    # Keeping the end date of the access key in sync is a separate process that does not update the person itself, but only the assigned access keys.
    # Therefore, this is encapsulated in a single function with its own dry-run and audit logging. When an exception occurs, only a warning is shown,
    # so it does not disrupt the account update process.
    $splatConfirmIloqAccessKey = @{
        PersonId = $aRef
        Headers  = $headers
        Enddate  = $p.PrimaryContract.Enddate
    }
    $null = Confirm-IloqAccessKeyEndDate @splatConfirmIloqAccessKey

    if (-not($dryRun -eq $true)) {
        if ($null -ne $responseUser) {
            # Verify if the account must be updated
            $splatCompareProperties = @{
                ReferenceObject  = @($responseUser.PSObject.Properties)
                DifferenceObject = @($account.person.PSObject.Properties)
            }
            $propertiesChanged = (Compare-Object @splatCompareProperties -PassThru).Where({ $_.SideIndicator -eq '=>' })
        }
        if ($propertiesChanged) {
            $action = 'Update'
        }
        else {
            $action = 'NoChanges'
        }

        switch ($action) {
            'Update' {
                $body = $account
                $splatParams = @{
                    Uri         = "$($config.BaseUrl)/api/v2/Persons"
                    Method      = 'PUT'
                    Headers     = $headers
                    Body        = $body | ConvertTo-Json
                    ContentType = 'application/json; charset=utf-8'
                }

                $null = Invoke-RestMethod @splatParams -Verbose:$false
                break
            }

            'NoChanges' {
                Write-Verbose "No changes to iLOQ account with accountReference: [$aRef]"
                break
            }
        }

        $success = $true
        $auditLogs.Add([PSCustomObject]@{
                Message = 'Update account was successful'
                IsError = $false
            })
    }
}
catch {
    $success = $false
    $ex = $PSItem
    if ($($ex.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') -or
        $($ex.Exception.GetType().FullName -eq 'System.Net.WebException')) {
        $errorObj = Resolve-IloqError -ErrorObject $ex
        $errorMessage = "Could not update iLOQ account. Error: $($errorObj.FriendlyMessage)"
    }
    else {
        $errorMessage = "Could not update iLOQ account. Error: $($ex.Exception.Message)"
    }
    Write-Verbose $errorMessage
    $auditLogs.Add([PSCustomObject]@{
            Message = $errorMessage
            IsError = $true
        })
}
finally {
    $result = [PSCustomObject]@{
        Success   = $success
        Account   = $account
        Auditlogs = $auditLogs
    }
    Write-Output $result | ConvertTo-Json -Depth 10
}