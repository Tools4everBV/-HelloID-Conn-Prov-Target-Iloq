
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

- [Introduction](#Introduction)
- [Getting started](#Getting-started)
  + [Connection settings](#Connection-settings)
  + [Prerequisites](#Prerequisites)
  + [Remarks](#Remarks)
- [Setup the connector](@Setup-The-Connector)
- [Getting help](#Getting-help)
- [HelloID Docs](#HelloID-docs)

## Introduction

_HelloID-Conn-Prov-Target-iloq_ is a _target_ connector. iloq provides a set of REST API's that allow you to programmatically interact with it's data. The HelloID connector uses the API endpoints listed in the table below.

| Endpoint     | Description |
| ------------ | ----------- |
|              |             |

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

You can change this behavior in the configuration by selecting the IsUpdatePerson field in the configuration

> Be aware that this might have unexpected implications.

### Remarks

- There is no enable script.

- When a new user is created, the fields: `eMail, PersonCode, Address` are mandatory. 
Typically, this data comes from an external system and will be used within iLOQ to connector these fields to groups. However the address field can stay empty

- ZoneId is hardcoded in the connector and needs to be added when creating a user for automization get all zoneId's with the call below if there is only one zoneId suse that otherwise use zoneId with type 4 because that is used as the default zone

- Leave the `Person_ID` field empty this is genereted via the create call in iLOQ 

```powershell
$splatParams = @{
    Uri         = "$($config.BaseUrl)/api/v2/Zones"
    Method      = 'GET'
    Headers     = $headers
    ContentType = 'application/json'
}
#if only one zone use that otherwise use zone with type 4 as default
$getAllZonesResponse = Invoke-RestMethod @splatParams

$account.ZoneIds += $getAllZonesResponse.Zone_ID
```


## Getting help

> _For more information on how to configure a HelloID PowerShell connector, please refer to our [documentation](https://docs.helloid.com/hc/en-us/articles/360012558020-Configure-a-custom-PowerShell-target-system) pages_

> _For more information on how to configure a iLOQ connector, please refer to the iLOQ [documentation](https://s5.iloq.com/iLOQPublicApiDoc) pages_

> _If you need help, feel free to ask questions on our [forum](https://forum.helloid.com)_

## HelloID docs

The official HelloID documentation can be found at: https://docs.helloid.com/
