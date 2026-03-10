# About GuardPost

GuardPost was born from the need for a **framework-agnostic, reusable
authentication and authorization layer** for Python applications. Rather than
tying auth logic to a specific web framework, GuardPost provides a clean,
composable API that works with any async Python application.

The design is inspired by **ASP.NET Core's authorization policies** — the idea
that authorization rules should be expressed as discrete, named policies made
up of composable requirements, rather than hard-coded role checks scattered
throughout the codebase.

GuardPost powers the authentication and authorization system in the
[BlackSheep](/blacksheep/) web framework, where it underpins features such as
JWT bearer authentication, policy-based authorization, and OIDC integration.

## Tested identity providers

GuardPost has been tested with the following identity providers:

- [Auth0](https://auth0.com/)
- [Azure Active Directory](https://azure.microsoft.com/en-us/products/active-directory)
- [Azure Active Directory B2C](https://azure.microsoft.com/en-us/products/active-directory/external-identities/b2c)
- [Okta](https://www.okta.com/)

## The project's home

The project is hosted in
[GitHub :fontawesome-brands-github:](https://github.com/Neoteroi/guardpost),
maintained following DevOps good practices, and published to
[PyPI](https://pypi.org/project/guardpost/).
