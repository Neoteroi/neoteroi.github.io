# Sessions

BlackSheep implements built-in support for sessions, which are handled through
digitally signed cookies. This page describes how to use sessions with the
built-in classes.

## Enabling sessions
To enable sessions, use the `app.use_sessions` method as in the example below:

```python
from blacksheep import Application, Request, get, text

app = Application()


app.use_sessions("<SIGNING_KEY>")


@get("/")
def home(request: Request):
    session = request.session

    session["example"] = "Lorem ipsum"

    return text(session["example"])
```

The `use_sessions` method accepts the following parameters:

| Name            | Description                                                                           | Defaults to                           |
| --------------- | ------------------------------------------------------------------------------------- | ------------------------------------- |
| secret_key      | required secret key used for signing                                                  | N/A                                   |
| session_cookie  | optional session cookie name                                                          | "session"                             |
| serializer      | optional `blacksheep.sessions.Serializer` to serialize and deserialize session values | `blacksheep.sessions.JSONSerializer`  |
| signer          | optional `itsdangerous.Serializer` to sign and encrypt the session cookie             | `itsdangerous.URLSafeTimedSerializer` |
| session_max_age | Optional session max age, in **seconds**                                              | `None`                                |

```python
    def use_sessions(
        self,
        secret_key: str,
        *,
        session_cookie: str = "session",
        serializer: Optional[SessionSerializer] = None,
        signer: Optional[Signer] = None,
        session_max_age: Optional[int] = None,
    ) -> None:
        ...
```

The built-in sessions middleware uses
[`itsdangerous`](https://itsdangerous.palletsprojects.com/en/1.1.x/) to sign,
encrypt, and verify session cookies. Refer to [data
protection](../dataprotection/) for more information on how tokens are signed
and encrypted.

## Using sessions

When sessions are enabled, they are always populated for the `request` object,
and can be accessed through the `request.session` property.

The sessions middleware takes care of setting a response cookie whenever the
session is modified, session cookies are signed and encrypted by default.

```python
@get("/")
def home(request: Request):
    session = request.session

    # setting a value
    session["example"] = "Lorem ipsum"

    # getting a value
    foo = session.get("foo")

    # getting a value with default
    foo = session.get("foo", 100)

    # getting a value (can produce KeyError)
    foo = session["foo"]

    # checking if a key is set
    if "something" in session:
        ...

    # deleting a key
    del session["something"]

    # update with many values
    session.update({"a": 1, "b": 2})

    return text(session["example"])
```
