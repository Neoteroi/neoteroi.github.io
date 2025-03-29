# Data protection

Web applications often need to protect data, so that it can be stored in
cookies or other types of storage. BlackSheep uses [`itsdangerous`](https://pypi.org/project/itsdangerous/) to sign and encrypt
information, for example when storing `claims` obtained from `id_token`s when
using an integration with an identity provider using [OpenID
Connect](../authentication/#oidc), or when handling [session cookies](../sessions/).

This page documents:

- [X] How to handle secrets
- [X] Example use of data protection

## How to handle secrets

Symmetric encryption is used to sign and encrypt information in several
scenarios. This means that BlackSheep applications _need_ secrets to protect
sensitive data in some circumstances. When keys are not specified, they are
generated automatically in memory when the application starts, for the best
user experience.

!!! danger
    This means that keys are <strong>not persisted</strong> when applications
    restart, and are not consistent when multiple instances of the same
    application are deployed across regions, or within the same server. This is
    acceptable during local development, but should not be the case in
    production environments.

To use consistent keys, configure one or more environment variables like the
following:

* APP_SECRET_1="***"
* APP_SECRET_2="***"
* APP_SECRET_3="***"

Keys can be configured in a host environment, or fetched from a dedicated
service such as `AWS Secrets Manager` or `Azure Key Vault` at application
start-up, and configured as environment settings for the application.
<strong>DO NOT</strong> store secrets that are meant to be used in production
under source control.

## Example

```python
from blacksheep.server.dataprotection import get_serializer


serializer = get_serializer(purpose="example")

token = serializer.dumps({"id": 1, "message": "This will be kept secret"})

print(token)

data = serializer.loads(token)

print(data)
```
