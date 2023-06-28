####################################################
# HelloID-Conn-Prov-Target-Iloq-Create
#
# Version: 1.0.0
#####################################################
# Initialize default values
$config = $configuration | ConvertFrom-Json
$p = $person | ConvertFrom-Json
$success = $false
$auditLogs = [System.Collections.Generic.List[PSCustomObject]]::new()

$ZoneID = $config.defaultZoneId

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

#Formatting Phone1 (mobile)
$ContactPhone = $p.Contact.Business.Phone.Mobile
If(-not ([string]::IsNullOrEmpty($ContactPhone))){
    $phone1 = $ContactPhone.Replace("-","")
    $phone1 = "+31" + [String]::Format('{0:#########}',[int]$phone1)
    $auditLogs.Add([PSCustomObject]@{
    Action = "CreateAccount"; #Optionally specify a different action for this audit log
    Message = "Phone number successfully formatted";
    IsError = $False;
    });
}Else{
    $phone1 = $null
    $auditLogs.Add([PSCustomObject]@{
    Action = "CreateAccount"; #Optionally specify a different action for this audit log
    Message = "Phone number not present in person object, set to NULL";
    IsError = $False;
    });
}

# Account mapping
$account = [PSCustomObject]@{
    person  = @{
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
        Person_ID         = "" #leave empty, a guid will be generated when none exists
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
        Address           = ""
    }

    # The ZoneIds are mandatory when creating a new person.
    # The ZoneId Type 4 is added in the script below. (Get-IloqZoneId)
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
        $getAllZonesResponse = Invoke-RestMethod @splatParams
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
        $response = Invoke-RestMethod @params
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
        Write-Verbose 'Verifying if an Iloq account has access keys assigned'
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
            Uri     = "$($config.BaseUrl)/api/v2/Keys/$($Key.FNKey_ID)//TimeLimitTitles?mode=0"
            Method  = 'GET'
            Headers = $Headers
        }
        $TimeLimitTitles = Invoke-RestMethod @splatParams -Verbose:$false
        $endDateObject = $TimeLimitTitles.KeyTimeLimitSlots | Where-Object { $_.slotNo -eq 1 }
        $currentEndDate = $null
        if ($null -ne $endDateObject ) {
            $currentEndDate = $endDateObject.LimitDateLg
        }
        $newEndDate = Confirm-UpdateRequiredEndDateKey -NewEndDate $EndDate -CurrentEndDate $currentEndDate
        if (-not [string]::IsNullOrWhiteSpace($newEndDate)) {
            Write-Verbose "EndDate Update required of AccessKey [$($Key.Description)]"
            if ($dryRun -eq $true) {
                Write-Warning "[DryRun] Update EndDate AccessKey: [$($Key.Description)] will be executed during enforcement"
                Write-Verbose "Current EndDate [$($Key.ExpireDate)] New EndDate: [$($newEndDate)]"
            }
            Write-Verbose "Update TimeLimit of AccessKey: [$($Key.Description)]. New EndDate is [$($newEndDate)]"
            $body = @{
                TimeLimitSlot = @{
                    LimitDateLg   = $newEndDate
                    SlotNo        = 1
                    TimeLimitData = @()
                }
            }
            if (-not($dryRun -eq $true)) {
                $splatParams = @{
                    Uri         = "$($config.BaseUrl)/api/v2/Keys/$($Key.FNKey_ID)/TimeLimitTitles"
                    Method      = 'POST'
                    Headers     = $Headers
                    Body        = ($body | ConvertTo-Json)
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

function Confirm-UpdateRequiredEndDateKey {
    [CmdletBinding()]
    param(
        [Parameter()]
        $NewEndDate,

        [Parameter()]
        $CurrentEndDate
    )
    if ($NewEndDate -eq $CurrentEndDate -or ($CurrentEndDate -eq '9999-01-01T00:00:00' -and [string]::IsNullOrEmpty($NewEndDate))) {
        Write-Verbose 'No EndDate Update update required'
    } else {
        if ([string]::IsNullOrEmpty($NewEndDate)) {
            $NewEndDate = '9999-01-01T00:00:00'
        }
        Write-Output $NewEndDate
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
    # First step is to get the correct url to use for the rest of the API calls.
    $null = Set-IloqResolvedURL -Config $config

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

    # Verify if a user must be either [created and correlated], [updated and correlated] or just [correlated]
    Write-Verbose "Verifying if iLOQ account for [$($p.DisplayName)] must be created or correlated"
    try {
        $splatParams = @{
            Uri         = "$($config.BaseUrl)/api/v2/Persons/GetByExternalPersonIds?externalPersonIds=$($account.person.ExternalPersonId)"
            Method      = 'GET'
            Headers     = $headers
            ContentType = 'application/json'
        }
        $userObject = Invoke-RestMethod @splatParams
    } catch {
        $userObject = $null
    }

    if (-not($userObject)) {
        $action = 'Create-Correlate'
    } elseif ($($config.IsUpdatePerson) -eq 'True') {
        $action = 'Update-Correlate'
    } else {
        $action = 'Correlate'
    }

    # Add a warning message showing what will happen during enforcement
    if ($dryRun -eq $true) {
        Write-Warning "[DryRun] $action iLOQ account for: [$($p.DisplayName)], will be executed during enforcement"
    }

    # Process
    if (-not($dryRun -eq $True)) {
        switch ($action) {
            'Create-Correlate' {
                Write-Verbose 'Creating and correlating iLOQ account'
                $account.person.Person_ID = [guid]::NewGuid()
                $resolveZoneID = Get-IloqZoneId -Config $config -SessionId $sessionId -ZoneIdType $ZoneID
                $account.ZoneIds += $resolveZoneID.Zone_ID

                $splatParams = @{
                    Uri         = "$($config.BaseUrl)/api/v2/Persons"
                    Method      = 'POST'
                    Headers     = $headers
                    Body        = $account | ConvertTo-Json
                    ContentType = 'application/json; charset=utf-8'
                }

                $createUserResponse = Invoke-RestMethod @splatParams
                $accountReference = $createUserResponse.PersonIds | Select-Object first 1
                break
            }

            'Update-Correlate' {
                Write-Verbose 'Updating and correlating iLOQ account'
                $account.person.Person_ID = $userObject.Person_ID
                $splatParams = @{
                    Uri         = "$($config.BaseUrl)/api/v2/Persons"
                    Method      = 'PUT'
                    Headers     = $headers
                    Body        = $account | ConvertTo-Json
                    ContentType = 'application/json; charset=utf-8'
                }
                $null = Invoke-RestMethod @splatParams

                $accountReference = $userObject.Person_ID
                # Updating the end date of the access key is a separate process that does not update the person itself, but only the assigned access keys.
                # Therefore, this is encapsulated in a single function with its own audit logging. When an exception occurs, only a warning is shown,
                # so it does not disrupt the account update process.
                # Note that a preview run is not possible, because there is an account reference required!
                $splatConfirmIloqAccessKey = @{
                    PersonId = $accountReference
                    Headers  = $headers
                    Enddate  = $account.person.EmploymentEndDate
                }
                $null = Confirm-IloqAccessKeyEndDate @splatConfirmIloqAccessKey
                break
            }

            'Correlate' {
                Write-Verbose 'Correlating iLOQ account'
                $accountReference = $userObject.Person_ID
                break
            }
        }

        $success = $true
        $auditLogs.Add([PSCustomObject]@{
                Message = "$action account was successful. AccountReference is: [$accountReference]"
                IsError = $false
            })
    }
} catch {
    $success = $false
    $ex = $PSItem
    if ($($ex.Exception.GetType().FullName -eq 'Microsoft.PowerShell.Commands.HttpResponseException') -or
        $($ex.Exception.GetType().FullName -eq 'System.Net.WebException')) {
        $errorObj = Resolve-IloqError -ErrorObject $ex
        $auditMessage = "Could not $action iLOQ account. Error: $($errorObj.FriendlyMessage)"
        Write-Verbose "Error at Line '$($errorObj.ScriptLineNumber)': $($errorObj.Line). Error: $($errorObj.ErrorDetails)"
    } else {
        $auditMessage = "Could not $action iLOQ account. Error: $($ex.Exception.Message)"
        Write-Verbose "Error at Line '$($ex.ScriptLineNumber)': $($ex.Line). Error: $($ex.Exception.Message)"
    }
    $auditLogs.Add([PSCustomObject]@{
            Message = $auditMessage
            IsError = $true
        })
    # End
} finally {
    $result = [PSCustomObject]@{
        Success          = $success
        AccountReference = $accountReference
        Auditlogs        = $auditLogs
        Account          = $account
    }
    Write-Output $result | ConvertTo-Json -Depth 10
}