As explained in [_Getting Started_](./getting-started.md), Rodi's objective is to
simplify constructing objects based on constructors and class properties.
Support for async resolution is intentionally out of the scope of the library because
constructing objects should be lightweight.

This page provides guidelines for working with objects that require asynchronous
initialization or disposal.

## A common example

A common example of objects requiring asynchronous disposal are objects that
handle TCP/IP connection pooling, such as `HTTP` clients and database clients.
These objects are typically implemented as *context managers* in Python because
they need to manage connection pooling and gracefully close TCP connections
upon disposal.

Python provides [`asynchronous` context managers](https://peps.python.org/pep-0492/#asynchronous-context-managers-and-async-with) for this kind of scenario.

Consider the following example, of a `SendGrid` API client to send emails using the
SendGrid API, with asynchronous code and using [`httpx`](https://www.python-httpx.org/async/).

```python {linenums="1"}
# domain/emails.py
from abc import ABC, abstractmethod
from dataclasses import dataclass


# TODO: use Pydantic for the Email object.
@dataclass
class Email:
    recipients: list[str]
    sender: str
    sender_name: str
    subject: str
    body: str
    cc: list[str] = None
    bcc: list[str] = None


class EmailHandler(ABC):  # interface
    @abstractmethod
    async def send(self, email: Email) -> None:
        pass
```

```python  {linenums="1", hl_lines="24 32"}
# data/apis/sendgrid.py
import os
from dataclasses import dataclass

import httpx

from domain.emails import Email, EmailHandler


@dataclass
class SendGridClientSettings:
    api_key: str

    @classmethod
    def from_env(cls):
        api_key = os.environ.get("SENDGRID_API_KEY")
        if not api_key:
            raise ValueError("SENDGRID_API_KEY environment variable is required")
        return cls(api_key=api_key)


class SendGridClient(EmailHandler):
    def __init__(
        self, settings: SendGridClientSettings, http_client: httpx.AsyncClient
    ):
        if not settings.api_key:
            raise ValueError("API key is required")
        self.http_client = http_client
        self.api_key = settings.api_key

    async def send(self, email: Email) -> None:
        response = await self.http_client.post(
            "https://api.sendgrid.com/v3/mail/send",
            headers={
                "Authorization": f"Bearer {self.api_key}",
                "Content-Type": "application/json",
            },
            json=self.get_body(email),
        )
        # TODO: in case of error, log response.text
        response.raise_for_status()  # Raise an error for bad responses

    def get_body(self, email: Email) -> dict:
        return {
            "personalizations": [
                {
                    "to": [{"email": recipient} for recipient in email.recipients],
                    "subject": email.subject,
                    "cc": [{"email": cc} for cc in email.cc] if email.cc else None,
                    "bcc": [{"email": bcc} for bcc in email.bcc] if email.bcc else None,
                }
            ],
            "from": {"email": email.sender, "name": email.sender_name},
            "content": [{"type": "text/html", "value": email.body}],
        }
```

/// details | The official SendGrid Python SDK does not support async.
    type: danger

At the time of this writing, the official SendGrid Python SDK does not support `async`.
Its documentation provides a wrong example for `async` code (see [_issue #988_](https://github.com/sendgrid/sendgrid-python/issues/988)).
The SendGrid REST API is very well documented and comfortable to use! Use a class like
the one shown on this page to send emails using SendGrid in async code.
///

The **SendGridClient** depends on an instance of `SendGridClientSettings` (providing a
SendGrid API Key), and on an instance of `httpx.AsyncClient` to make async HTTP requests.

The code below shows how to register the object that requires asynchronous
initialization and use it across the lifetime of your application.

```python {linenums="1", hl_lines="12-20 25 40-41 44-46 48"}
# main.py
import asyncio
from contextlib import asynccontextmanager

import httpx
from rodi import Container

from data.apis.sendgrid import SendGridClient, SendGridClientSettings
from domain.emails import EmailHandler


@asynccontextmanager
async def register_http_client(container: Container):

    async with httpx.AsyncClient() as http_client:
        print("HTTP client initialized")
        container.add_instance(http_client)
        yield

    print("HTTP client disposed")


async def application_runtime(container: Container):
    # Entry point for what your application does
    email_handler = container.resolve(EmailHandler)
    assert isinstance(email_handler, SendGridClient)
    assert isinstance(email_handler.http_client, httpx.AsyncClient)

    # We can use the HTTP Client during the lifetime of the Application
    print("All is good! ✨")


def sendgrid_settings_factory() -> SendGridClientSettings:
    return SendGridClientSettings.from_env()


async def main():
    # Bootstrap code for the application
    container = Container()
    container.add_singleton_by_factory(sendgrid_settings_factory)
    container.add_singleton(EmailHandler, SendGridClient)

    async with register_http_client(container) as http_client:
        container.add_instance(
            http_client
        )  # <-- Configure the HTTP client as singleton

        await application_runtime(container)


if __name__ == "__main__":
    asyncio.run(main())
```

The above code displays the following:

```bash
$ SENDGRID_API_KEY="***" python main.py

HTTP client initialized
All is good! ✨
HTTP client disposed
```

## Considerations

- It is not Rodi's responsibility to administer the lifecycle of the
  application. It is the responsibility of the code that bootstraps the
  application, to handle objects that require asynchronous initialization and
  disposal.
- Python's `asynccontextmanager` is convenient for these scenarios.
- In the example above, the HTTP Client is configured as singleton to benefit from TCP
  connection pooling. It would also be possible to configure it as transient or scoped
  service, as long as all instances share the same connection pool. In the case of
  `httpx`,  you can read on this subject here: [Why use a Client?](https://www.python-httpx.org/advanced/clients/#why-use-a-client).
- Dependency Injection likes custom classes to describe _settings_ for types,
  because registering simple types (`str`, `int`, `float`, etc.) in the container does
  not scale and should be avoided.

The next page explains how Rodi handles [context managers](./context-managers.md).
