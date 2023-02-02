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
 - The API requires an additional API iLOQ license, make sure you have the correct License.
 - Please make sure that the API user has the correct right, the user must be able to read all the data from all the userzones.
 - Before using this connector, make sure you have the appropriate API key to connect to the API.


#### Creation / correlation process

A new functionality is the possibility to update the account in the target system during the correlation process. By default, this behavior is disabled. Meaning, the account will only be created or correlated.

You can change this behavior in the configuration by selecting the IsUpdatePerson field in the configuration.

> Be aware that this might have unexpected implications.

### Remarks

- There is no enable script. don't forget to give out the account_access entitlement otherwise you can't disable the user
- When a new user is created, the fields: `eMail, PersonCode, Address` are mandatory.
  Typically, this data comes from an external system. However, the address field can stay empty.
- Keep in mind when revoke Access Keys of type Phone you cannot monitor the status of phone when returning it, for example when the phone is in flight mode
- The ZoneId is mandatory when creating a new person. The ZoneId of Type 4 is marked as default, the correct ZoneId from ILOQ is fetched in function: 'Get-IloqZoneId'.
- Leave the `Person_ID` field empty. The Guid for this is generated in the Create-Correlate

## Getting help

> _For more information on how to configure a HelloID PowerShell connector, please refer to our [documentation](https://docs.helloid.com/hc/en-us/articles/360012558020-Configure-a-custom-PowerShell-target-system) pages_

> _For more information on how to configure a iLOQ connector, please refer to the iLOQ [documentation](https://s5.iloq.com/iLOQPublicApiDoc) pages_

> _If you need help, feel free to ask questions on our [forum](https://forum.helloid.com)_

## HelloID docs

The official HelloID documentation can be found at: https://docs.helloid.com/
