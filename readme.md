# HelloID-Conn-Prov-Target-iloq

| :warning: Warning |
|:---------------------------|
| Note that this connector is "a work in progress" and therefore not ready to use in your production environment. |

| :information_source: Information |
|:---------------------------|
| This repository contains the connector and configuration code only. The implementer is responsible to acquire the connection details such as username, password, certificate, etc. You might even need to sign a contract or agreement with the supplier before implementing this connector. Please contact the client's application manager to coordinate the connector requirements. |

<p align="center">
  <img src="logo.png">
</p>

## Table of contents

- [HelloID-Conn-Prov-Target-iloq](#helloid-conn-prov-target-iloq)
  - [Table of contents](#table-of-contents)
  - [Introduction](#introduction)
  - [Getting started](#getting-started)
    - [Connection settings](#connection-settings)
    - [Prerequisites](#prerequisites)
      - [Creation / correlation process](#creation--correlation-process)
    - [Remarks](#remarks)
  - [Getting help](#getting-help)
  - [HelloID docs](#helloid-docs)
  
## Introduction

_HelloID-Conn-Prov-Target-iloq_ is a _target_ connector. iloq provides a set of REST API's that allow you to programmatically interact with its data. The HelloID connector uses the API endpoints listed in the table below.

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

## Getting started

### Connection settings

The following settings are required to connect to the API.

| Setting         | Description                             | Mandatory   |
| ------------    | -----------                             | ----------- |
| UserName        | The UserName to connect to the API      | Yes         |
| Password        | The Password to connect to the API      | Yes         |
| CustomerCode    | The CustomerCode to connect to the API  | Yes         |
| BaseUrl         | The URL to the API                      | Yes         |

### Prerequisites

Before using this connector, make sure you have the appropriate API key to connect to the API.

#### Creation / correlation process

A new functionality is the possibility to update the account in the target system during the correlation process. By default, this behavior is disabled. Meaning, the account will only be created or correlated.

You can change this behavior in the configuration by selecting the IsUpdatePerson field in the configuration.

> Be aware that this might have unexpected implications.

### Remarks

- There is no enable script.

- When a new user is created, the fields: `eMail, PersonCode, Address` are mandatory.
Typically, this data comes from an external system. However, the address field can stay empty.

- The ZoneId is hardcoded in the connector and needs to be added when creating a new user.<br>
To get all zoneId's you can use the code listed below. Note that, if there is only one zoneId make sure to use that. Otherwise, use zoneId with type 4 as this is used as the default zone.

```powershell
$splatParams = @{
    Uri         = "$($config.BaseUrl)/api/v2/Zones"
    Method      = 'GET'
    Headers     = $headers
    ContentType = 'application/json'
}
#if there's only one zone, use that otherwise use zone with type 4 as default 
$getAllZonesResponse = Invoke-RestMethod @splatParams

$account.ZoneIds += $getAllZonesResponse.Zone_ID
```

- Leave the `Person_ID` field empty this is generated via the create call in iLOQ

## Getting help

> _For more information on how to configure a HelloID PowerShell connector, please refer to our [documentation](https://docs.helloid.com/hc/en-us/articles/360012558020-Configure-a-custom-PowerShell-target-system) pages_

> _For more information on how to configure a iLOQ connector, please refer to the iLOQ [documentation](https://s5.iloq.com/iLOQPublicApiDoc) pages_

> _If you need help, feel free to ask questions on our [forum](https://forum.helloid.com)_

## HelloID docs

The official HelloID documentation can be found at: https://docs.helloid.com/
