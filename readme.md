
# HelloID-Conn-Prov-Target-Iloq

> [!IMPORTANT]
> This repository contains the connector and configuration code only. The implementer is responsible to acquire the connection details such as username, password, certificate, etc. You might even need to sign a contract or agreement with the supplier before implementing this connector. Please contact the client's application manager to coordinate the connector requirements.

<p align="center">
  <img src="https://www.tools4ever.nl/connector-logos/iloq-logo.png">
</p>

## Table of contents

- [HelloID-Conn-Prov-Target-Iloq](#helloid-conn-prov-target-Iloq)
  - [Table of contents](#table-of-contents)
  - [Introduction](#introduction)
  - [Getting started](#getting-started)
    - [Provisioning PowerShell V2 connector](#provisioning-powershell-v2-connector)
     - [Field mapping](#field-mapping)
     - [Correlation configuration](#correlation-configuration)
    - [Connection settings](#connection-settings)
    - [Prerequisites](#prerequisites)
    - [Remarks](#remarks)
     - [Permission Remarkks](#permissions-remarks)
  - [Getting help](#getting-help)
  - [HelloID docs](#helloid-docs)

## Introduction

_HelloID-Conn-Prov-Target-Iloq_ is a _target_ connector. _Iloq_ provides a set of REST API's that allow you to programmatically interact with its data. The HelloID connector uses the API endpoints listed in the table below.
| Endpoint                                                    | Description                                           |
| ----------------------------------------------------------- | ----------------------------------------------------- |
| /api/v2/CreateSession                                       | Create session to make API requests                   |
| /api/v2/LockGroups                                          | Get lock groups needed to make API requests           |
| /api/v2/SetLockGroup                                        | Set lock groups needed to make API requests           |
| /api/v2/Persons/GetByExternalPersonIds/{externalPersonId}   | Get person by external person id                      |
| /api/v2/Persons/{personId}                                  | Get person by PersonId                                |
| /api/v2/Persons                                             | Create, update and delete persons                     |
| /api/v2/Persons/{personId}/Keys                             | Get keys for a specific person                        |
| /api/v2/Keys/{keyId}/CanReturn                              | Check if the key selected by key id can be returned   |
| /api/v2/Keys/{keyId}/Return                                 | Return key with specific key id                       |
| /api/v2/Persons/{personId}/CanDelete                        | Check if person selected by person id can be deleted  |

The following lifecycle actions are available:

| Action                 | Description                                      |
| ---------------------- | ------------------------------------------------ |
| create.ps1             | PowerShell _create_ lifecycle action             |
| delete.ps1             | PowerShell _delete_ lifecycle action             |
| disable.ps1            | PowerShell _disable_ lifecycle action            |
| enable.ps1             | <enable action not available>      |
| update.ps1             | PowerShell _update_ lifecycle action             |
| permissions/groups/grantPermission.ps1    | PowerShell _grant_ lifecycle action              |
| permissions/groups/revokePermission.ps1   | PowerShell _revoke_ lifecycle action             |
| permissions/groups/permissions.ps1        | PowerShell _permissions_ lifecycle action        |
| configuration.json     | Default _configuration.json_ |
| fieldMapping.json      | Default _fieldMapping.json_   |

## Getting started

### Provisioning PowerShell V2 connector

#### Field mapping

The field mapping can be imported by using the _fieldMapping.json_ file.

#### Correlation configuration

The correlation configuration is used to specify which properties will be used to match an existing account within _Iloq_ to a person in _HelloID_.

To properly setup the correlation:

1. Open the `Correlation` tab.

2. Specify the following configuration:

    | Setting                   | Value                             |
    | ------------------------- | --------------------------------- |
    | Enable correlation        | `True`                            |
    | Person correlation field  | `ExternalId`                      |
    | Account correlation field | `ExternalPersonId`                |


> [!TIP]
> _For more information on correlation, please refer to our correlation [documentation](https://docs.helloid.com/en/provisioning/target-systems/powershell-v2-target-systems/correlation.html) pages_.



### Connection settings

The following settings are required to connect to the API.

| Setting         | Description                             | Mandatory   |
| ------------    | -----------                             | ----------- |
| UserName        | The UserName to connect to the API      | Yes         |
| Password        | The Password to connect to the API      | Yes         |
| CustomerCode    | The CustomerCode to connect to the API  | Yes         |
| BaseUrl         | The URL to the API                      | Yes         |
| Default ZoneID type| The type of the zoneID a new user is created in. e.g. 4 or 14 | Yes

### Prerequisites

 - The API requires an additional API iLOQ license, make sure you have the correct License.
 - Please make sure that the API user has the correct rights, the user must be able to read all the data from all the userzones.

 - Ensure that the Concurrent Action limit is set to one, as the grant or revoke process for a single user cannot be performed simultaneously. It can result in occasional instances where permissions are not granted.

### Remarks


- There is no enable script. This is because the disable script does effectively remove the accesskeys from the account, and the re-assigment is a manual process. Note that although there is no action in the target system associated with the "Account access" HelloId entitlement, this entitlement still must be granted, as the trigger for the disable action is the revocation of this entitlement.
- When a new user is created, the fields: `eMail and PersonCode are mandatory. The field Person_ID is not specified in the HelloID field mapping, because it is automatically generated in the script, and stored as account reference. The other fields can be empty strings, but cannot be omitted. This is also the case for the update script.
- Keep in mind when revoking Access Keys of type Phone you cannot monitor the status of phone when returning it, for example when the phone is in flight mode
- The ZoneId is mandatory when creating a new person. The ZoneIdType of the ZoneId used as default when creating a user is specified in the configuration. This type may differ per Iloq environment. (e.g 4 or 14)), the actual ZoneId from iLOQ is fetched in function: 'Get-IloqZoneId'.


- The Enddate of the AccessKey is kept in sync with the person's primary contract enddate to ensure that it is always up-to-date. An additional check is run in some sort of extra process in the following HelloId Actions: **Create, Update, Grant, and Revoke**. This check verifies if the accessKey enddate differs from the enddate of the primary contract, and if so, it updates the enddate on the access key. This is done on all the access keys assigned to the person. Because this process is slightly different from the normal Account LifeCycle or managing permissions, it does not throw termination errors but instead adds a warning to the process logging. (Of course, this can be changed.)
- Please note that after updating the security access on the key with HelloID, the security accesses are granted in the system but are not directly synced to the actual key. This programming happens either by passing through an online reader (for example, an active door reader capable of syncing the latest changes) or by programming with a physical programming key.
- There are two types of end dates that can be updated on an AccessKey. There is an ExpireDate and a Timelimit Slot. The ExpireDate is only an informational value, while the Timelimit slot actually prevents access whenever the end date is expired. The connector keeps both dates in sync with the primary contract end date, as already mentioned above.


#### Permissions Remarks
>  :information_source: Information
> The Order action has not been fully tested yet because it requires an actual programming key, which we don't have available in our test environment. But the 'Order' code is Dry-coded create and should be working as the documentation described.

The permissions of an access key system vary between vendors. For iLOQ, it is implemented as follows: a person is linked to an access key, and the permissions (security accesses) are granted to the access key itself. Additionally, a person's link to an access key is a one-to-many relationship, meaning that a single person can have multiple access keys assigned.
The connector process for managing access keys involves the creation of user accounts and the management of permissions using HelloId. However, establishing the link between a person and their access key(s) cannot be automated, and requires a manual handover of the key to the employee. Consequently, it is recommended to introduce a period of time between the creation of the user account and the granting of permissions by implementing HelloId Business Rules.

- To grant permission, the grant script checks if an access key has been assigned to the person. If an access key is not found, the script stops will retry each enforcement until an access key is assigned to the person. This ensures that the "issue" is resolved automatically.
 - The permissions script retrieves the available Security Accesses, which are the permissions that can be assigned to the access key. *(Currently, the SecurityAccesses are filtered on Type 3, as not all types function as expected. However, this filtering approach may vary depending on the specific environment.)*
 - The grant or revoke permissions process will update only the specified permission and leave all other existing permissions unchanged. Therefore, no additional synchronization will be performed to ensure that the SecurityAccesses on multiple keys remain in sync with each other.
 - In addition, of the previous remark. In cases where an additional, lost, stolen, or otherwise replaced key is handed over to an employee, the granted SecurityAccesses must be **manually copied from the previous key** to ensure that it can be used directly.
 - The grant or revoke permissions process is created to set the specified permissions for all access keys assigned to a user.
 - When a person has multiple keys assigned, the granted permissions for each key are displayed as sub-permissions in the entitlement overview.
 - After each change in Security Access permissions, the key needs to be ordered in order to make the new permission set available for ordering [More info Here](https://s5.iloq.com/iLOQPublicApiDoc/use_cases/iLOQ_ManageKeysSecurityAccessesRemotely.html). This can cause inconvenience whenever a permission is revoked and the CanOrder action fails. The webservice has already deleted the permission, so in the retry, the permission is already removed according to the API. This means that the key should always be ordered in the revoke action, even if the API indicates that the permission has already been removed.
 - The connector does support only locking systems that have zone functionality On




## Getting help

> [!TIP]
> _For more information on how to configure a HelloID PowerShell connector, please refer to our [documentation](https://docs.helloid.com/hc/en-us/articles/360012558020-Configure-a-custom-PowerShell-target-system) pages_

> _For more information on how to configure a iLOQ connector, please refer to the iLOQ [documentation](https://s5.iloq.com/iLOQPublicApiDoc) pages_

> _If you need help, feel free to ask questions on our [forum](https://forum.helloid.com/forum/helloid-connectors/provisioning/1210-helloid-provisioning-target-iloq)_

## HelloID docs

The official HelloID documentation can be found at: https://docs.helloid.com/
