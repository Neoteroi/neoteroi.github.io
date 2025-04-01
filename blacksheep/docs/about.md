# About BlackSheep

BlackSheep is a web framework for Python asyncio designed to facilitate the
implementation of stateless APIs and general-purpose web applications. It is
inspired by [Flask](https://flask.palletsprojects.com/en/1.1.x/) and [ASP.NET
Core](https://docs.microsoft.com/en-us/aspnet/core/introduction-to-aspnet-core?view=aspnetcore-5.0);
it recreates several features from both these web frameworks. The concept of
automatic binding of request parameters by the request handler's signature and
dependency injection of required services (as it happens in ASP.NET Core) is
what makes BlackSheep unique today, in the context of Python web frameworks.

The project, like several other web frameworks for Python, is the fruit of the
creative ferment around Yury Selivanov’s work, and the article [uvloop: Blazing
fast Python
networking](https://magic.io/blog/uvloop-blazing-fast-python-networking/) from
2016.

The project originally included an implementation of [HTTP Server, but this was
removed](https://robertoprevato.github.io/Presenting-BlackSheep/), and the web
framework was abstracted from an exact HTTP Server and made compatible with
[ASGI HTTP Servers](https://asgi.readthedocs.io/en/latest/). This was a good
move because the effort on the project can stay focused on higher-level
features, while benefitting from the existing ecosystem and help from the
Python community in implementing HTTP Servers (e.g. support for HTTP2).

## The project's home
The project is hosted in [GitHub](https://github.com/Neoteroi/BlackSheep),
handled following DevOps good practices, features 100% code coverage, and is
published to [pypi.org](https://pypi.org/project/blacksheep/).

[![GitHub Stars](https://img.shields.io/github/stars/Neoteroi/BlackSheep?style=social)](https://github.com/Neoteroi/BlackSheep/stargazers)
[![Build](https://github.com/Neoteroi/BlackSheep/workflows/Main/badge.svg)](https://github.com/Neoteroi/BlackSheep/actions)
[![pypi](https://img.shields.io/pypi/v/BlackSheep.svg?color=blue)](https://pypi.org/project/BlackSheep/)
[![versions](https://img.shields.io/pypi/pyversions/blacksheep.svg)](https://github.com/Neoteroi/BlackSheep)
[![codecov](https://codecov.io/gh/Neoteroi/BlackSheep/branch/master/graph/badge.svg?token=Nzi29L0Eg1)](https://codecov.io/gh/Neoteroi/BlackSheep)

## Why the name BlackSheep
The name _BlackSheep_ was chosen for two reasons:

* to refer to the "black sheep" idiom, used to describe [_one who is unlike
  other members of a family, group, or organization, sometimes due to
  intentional
  rebelliousness_](https://idioms.thefreedictionary.com/the+black+sheep) -
  especially for the choice of giving so much importance to _dependency
  injection_ (which is not very popular in Python community, or _was not_
  popular when BlackSheep was started), asynchronous coding and type
  annotations (which are still debated upon in Python community, or _were_
  debated upon when BlackSheep was started), and for being a Python web
  framework inspired by ASP.NET&nbsp;Core.
* as a tribute to the song _The Sinking Belle (Black Sheep)_ of the album
  [_Altar_](https://en.wikipedia.org/wiki/Altar_(album)), by Boris and
  Sunn&nbsp;O))).
