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
        EmploymentEndDate = $p.PrimaryContract.EndDate
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
            $config.BaseUrl =  $resolvedUrl
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
#endregion

# Begin
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
        Write-Verbose $($userObject) -verbose
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
                Write-Verbose 'Updating and correlating iLOQ account'*
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