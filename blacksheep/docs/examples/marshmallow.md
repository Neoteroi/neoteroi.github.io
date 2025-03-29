The following example describes how
[`Marshmallow`](https://marshmallow.readthedocs.io/en/stable/) can be used to
implement validation of input bodies from the client. For the sake of
simplicity, the example shows a case in which an array of items is validated
(the marshmallow scheme is validated using `(many=True)`). A similar approach
can be used with [`msgspec`](https://jcristharif.com/msgspec/)

Implementing a generic solution to validate input and produce user-friendly
error messages is not in the scope of BlackSheep, but the framework offers ways
to integrate with other libraries.

This is possible by defining a couple of custom binders, a custom exception,
and a custom exception handler like in the example below.

```python
from typing import Any, TypeVar

from marshmallow import Schema, ValidationError, fields

from blacksheep import Application
from blacksheep.messages import Request
from blacksheep.server.bindings import Binder, BoundValue
from blacksheep.server.responses import pretty_json

SchemaType = TypeVar("SchemaType", bound=Schema)


class InvalidBodyError(Exception):
    """
    Kind of BadRequest exception that includes error details as complex objects.
    """

    def __init__(self, data: Any):
        super().__init__("Invalid payload")
        self.details = data


# Example Marshmallow schema, from the marshmallow documentation
class BandMemberSchema(Schema):
    name = fields.String(required=True)
    email = fields.Email()


# Example binding for a Marshmallow schema, to be used to obtain a list of objects
class FromMultiSchema(BoundValue[SchemaType]):
    """
    Custom bound value that can be used to describe a list of objects validated using a
    Marshmallow schema.
    """


class MultiSchemaBinder(Binder):
    """
    Binder that handles a FromMultiSchema, returning a list of objects from a
    Marshmallow schema.
    """

    handle = FromMultiSchema

    async def get_value(self, request: Request) -> Any:
        data = await request.json()
        try:
            return self.expected_type(many=True).load(data)
        except ValidationError as err:
            raise InvalidBodyError(err.messages)


app = Application()


@app.exception_handler(InvalidBodyError)
async def invalid_body_handler(app, request, exc: InvalidBodyError):
    return pretty_json(exc.details, 400)


@router.post("/")
def example(data: FromMultiSchema[BandMemberSchema]):
    return pretty_json(data.value)


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, port=44555, lifespan="on")

```

```bash
curl -X POST http://127.0.0.1:44555 -H "Content-Type: application/json" -d '[{"id": 1, "name": "foo", "permissions": []}]'
{
    "0": {
        "permissions": [
            "Unknown field."
        ],
        "id": [
            "Unknown field."
        ]
    }
}

curl -X POST http://127.0.0.1:44555 -H "Content-Type: application/json" -d '[{"id": 1, "name": "foo", "email": "wrong-value"}]'
{
    "0": {
        "email": [
            "Not a valid email address."
        ],
        "id": [
            "Unknown field."
        ]
    }
}
```
