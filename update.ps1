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
        EmploymentEndDate = $p.PrimaryContract.EndDate
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
    Write-Verbose "Updating iLOQ account with accountReference: [$aRef]"
    
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
        Write-Verbose "Verifying if iLOQ account for [$($account.person.FirstName)] exists"
        $splatParams = @{
            Uri         = "$($config.BaseUrl)/api/v2/Persons/$($aRef)"
            Method      = 'GET'
            Headers     = $headers
            ContentType = 'application/json; charset=utf-8'
        }

        $responseUser = Invoke-RestMethod @splatParams
        $dryRunMessage = "Update iLOQ account for: [$($account.person.FirstName)] will be executed during enforcement"
    }
    catch {
        $dryRunMessage = "iLOQ account for: [$($account.person.FirstName)] not found. Possibly already deleted. Skipping action"
        $auditLogs.Add([PSCustomObject]@{
                Message = $dryRunMessage
                IsError = $false
            })
    }
    
    # Add an auditMessage showing what will happen during enforcement
    if ($dryRun -eq $true) {
        $auditLogs.Add([PSCustomObject]@{
                Message = "[dryrun] $($dryRunMessage)"
            })
    }

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

                $null = Invoke-RestMethod @splatParams
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
        $errorMessage = "Could not update iLOQ account. Error: $($errorObj.ErrorMessage)"
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