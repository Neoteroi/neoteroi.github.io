The `blacksheep.server.remotes` namespace provides classes and functions to
handle information related to remote proxies and clients. Web applications in production
environments are often hosted behind servers such as Apache, IIS, NGINX, or Kubernetes
ingress controllers. Proxy servers typically obscure some information from the original
web request before it reaches the web application.

For example:

- When TLS termination is used, meaning that HTTPS requests are proxied over HTTP, the
  original scheme (HTTPS) is lost.
- When an application receives a request from a proxy instead of its true
  source, the original client IP address must also be forwarded in a header.
- The path of web requests can be altered during proxying (e.g., NGINX
  configured to proxy requests from `/example` to the root `/` of a web
  application).

This information is often critical for request processing, such as in
redirects, authentication, link generation (when absolute URLs are required),
and client geolocation. This page documents how to configure BlackSheep to work
with proxy servers and load balancers, using the provided classes to handle:

- [X] Forcing HTTP scheme.
- [X] X-Forwarded headers.
- [X] Forwarded header.
- [X] Trusted hosts.
- [X] How to read information about the original clients in web requests.

For information on how to handle the prefix of routes when exposing a web
application behind a proxy, refer to the dedicated page
[_Behind Proxies_](./behind-proxies.md).

## Forcing HTTP scheme

In many cases, when web applications are exposed behind proxies that do TLS termination
(the proxy or ingress accepts HTTPS requests and proxies to the back-end listening on
HTTP), we simply need to instruct the web application to generate URLs to itself using
`https` scheme instead of `http`.

/// tab | Since version 2.4.4

Since version `2.4.4`, the framework includes built-in features to force the HTTP scheme
of generated URLs.

TODO: document env variables.

///

/// tab | Before version 2.4.4

Before `2.4.4`, the framework did not include any specific code to force the HTTP scheme
and it required applying a middleware.

TODO: like in FinOps API.

```python

```

///

## Handling X-Forwarded headers

`X-Forwarded` headers are the _de-facto_ standard headers to propagate
information about original web requests to web applications.

| Header            | Description                                                                                                                  |
| ----------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| X-Forwarded-For   | Used to identify the originating IP address of a client connecting to a web server through an HTTP proxy or a load balancer. |
| X-Forwarded-Host  | Used to identify the original host requested by the client in the Host HTTP request header                                   |
| X-Forwarded-Proto | Used to identify the protocol (HTTP or HTTPS) that a client used to connect to your proxy or load balancer.                  |

BlackSheep provides an `XForwardedHeadersMiddleware` class to handle these
headers, providing:

- Optional validation of trusted hosts.
- Optional validation of proxies count and IP addresses by known IPs or known
  networks.

To configure a BlackSheep web application to handle `X-Forwarded` headers and
configure incoming web requests to expose the correct information about source
protocol, client IP, and host:

```python
from blacksheep import Application
from blacksheep.server.remotes.forwarding import XForwardedHeadersMiddleware


app = Application()


@app.on_middlewares_configuration
def configure_forwarded_headers(app):
    app.middlewares.insert(
        0,
        XForwardedHeadersMiddleware(),
    )
```

Options of the `XForwardedHeadersMiddleware` class:

| Parameter      | Type, default                        | Description                                                                                                                                                                      |
| -------------- | ------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| allowed_hosts  | `Sequence[str] | None` = None       | Sequence of allowed hosts. If configured, requests that send a different host in the `Host` header or `X-Forwarded-Host` header are replied with Bad Request.                    |
| known_proxies  | Sequence[IPAddress] &#124; None = None | Sequence of allowed proxies IP addresses. If configured, requests that send different proxies IPs in the request scope or `X-Forwarded-For` header are replied with Bad Request. |
| known_networks | Sequence[IPNetwork] &#124; None = None | Sequence of allowed proxies networks. If configured, requests that send a foreign proxy IP in the request scope or `X-Forwarded-For` header are replied with Bad Request.        |
| forward_limit  | int = 1                              | Maximum number of allowed forwards, by default 1.                                                                                                                                |

When `known_proxies` is not provided, it is set by default to handle `localhost`:
`[ip_address("127.0.0.1")]`.

## Handling Forwarded header

The `Forwarded` header is a standard header to propagate information about
original web requests to web applications.

To configure a BlackSheep web application to handle `Forwarded` headers:


```python
from blacksheep import Application
from blacksheep.server.remotes.forwarding import ForwardedHeadersMiddleware


app = Application()


@app.on_middlewares_configuration
def configure_forwarded_headers(app):
    app.middlewares.insert(
        0,
        ForwardedHeadersMiddleware(),
    )
```

Options of the `ForwardedHeadersMiddleware` class:

| Parameter      | Type, default                        | Description                                                                                                                                                                |
| -------------- | ------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| allowed_hosts  | Sequence[str] &#124; None = None       | Sequence of allowed hosts. If configured, requests that send a different host in the `Host` header or `Forwarded` header are replied with Bad Request.                     |
| known_proxies  | Sequence[IPAddress] &#124; None = None | Sequence of allowed proxies IP addresses. If configured, requests that send different proxies IPs in the request scope or `Forwarded` header are replied with Bad Request. |
| known_networks | Sequence[IPNetwork] &#124; None = None | Sequence of allowed proxies networks. If configured, requests that send a foreign proxy IP in the request scope or `Forwarded` header are replied with Bad Request.        |
| forward_limit  | int = 1                              | Maximum number of allowed forwards, by default 1.                                                                                                                          |

When `known_proxies` is not provided, it is set by default to handle `localhost`:
`[ip_address("127.0.0.1")]`.

## Handling trusted hosts

When forwarded headers middlewares are not used, but it is necessary to
validate hosts, it is possible to use the `TrustedHostsMiddleware`:

```python
from blacksheep import Application
from blacksheep.server.remotes.hosts import TrustedHostsMiddleware


app = Application()


@app.on_middlewares_configuration
def configure_forwarded_headers(app):
    app.middlewares.insert(
        0,
        TrustedHostsMiddleware(["www.neoteroi.dev"]),
    )
```

## Reading information about the original clients in web requests

Web requests expose information about the original clients in the following
properties, that are updated by forwarded header middlewares:

```python
from blacksheep import Request

request: Request

request.host
request.scheme
request.original_client_ip

```

| Property           | Description                                                                                             |
| ------------------ | ------------------------------------------------------------------------------------------------------- |
| host               | Originating host.                                                                                       |
| scheme             | Originating scheme ("http" or "https").                                                                 |
| original_client_ip | Originating IP address of a client connecting to a web server through an HTTP proxy or a load balancer. |

## Obtaining the web request absolute URL
To obtain the original absolute URL of a web request, use the provided
`get_absolute_url_to_path` and `get_request_absolute_url` functions:

```python
from blacksheep.messages import get_absolute_url_to_path, get_request_absolute_url


# examples
absolute_url = get_request_absolute_url(request)

absolute_url_to_path = get_absolute_url_to_path(request, "/example")
```

## ASGI root_path

When the `ASGI` scope includes the `root_path` information, it is automatically
used for the request `base_path` property. For more information on this
subject, refer to the dedicated page [_Behind Proxies_](./behind-proxies.md).
