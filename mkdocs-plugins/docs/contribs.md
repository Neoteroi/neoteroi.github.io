The contribs extension provides a plugin to display information about contributors and
last commit time for each page. It works using the `git` CLI to obtain information from
the same repository where the MkDocs site is built. It doesn't require any communication
with third party services, but it requires running in a Git repository.

!!! danger "Git support only"
    This plugin works only with Git repositories, and since it obtains
    information from the git repository that contains the MkDocs site, it is
    designed for scenarios in which the documentation is built in CI/CD jobs.

This plugin doesn't require any markup code: it modifies each page to include
contributors' list and last commit time affecting the file, and it doesn't
require integration with any external API.

## How to use

Install using `pip install neoteroi-mkdocs`.
Edit your `mkdocs.yml` file to include the extra CSS file from Neoteroi
mkdocs-plugins and the `neoteroi.contribs` plugin for MkDocs:


```yaml
extra_css:
  - css/neoteroi-mkdocs.css
  ...

plugins:
  - search
  - neoteroi.contribs
```

## Information

The plugin displays the last modified time for each file (the last time a file
was modified in the Git repository), and the list of contributors, sorted by
commits count.

![Contribs example](/mkdocs-plugins/img/contribs-01.png)

## Options

| Name                  | Description                                                                                                                                 | Type                            | Default             |
| --------------------- | ------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------- | ------------------- |
| `contributors_label`  | The label text for contributors list.                                                                                                       | `str`                           | "Contributors"      |
| `contributors`        | Information about contributors, use to configure images for contributors.                                                                   | `list` of `contributor` objects | `[]`                |
| `enabled_by_env`      | When specified, the Git contributors plugin is only enabled if such variable exists and its value is in `{"1", "true"}` (case insensitive). | `str`                           | `""`                |
| `last_modified_label` | The label text for last modified time.                                                                                                      | `str`                           | "Last modified on"  |
| `last_modified_time`  | Whether to display the last modified time for each page.                                                                                    | `bool`                          | `True`              |
| `time_format`         | Format to be used for dates.                                                                                                                | `str`                           | "%Y-%m-%d %H:%M:%S" |

The plugin by default displays dots with the first two initials of each committer's name,
displaying pictures requires explicit configuration, described below.

/// admonition | Keep disabled during local development.
    type: warning

This plugin has a significant impact on the performance of `mkdocs serve` and
`mkdocs build`. It is recommended to keep it disabled during local development
and enable it only in the build job that generates the artifacts for publishing.

```yaml  {hl_lines="2"}
  - neoteroi.contribs:
      enabled_by_env: "GIT_CONTRIBS_ON"
```

```bash
GIT_CONTRIBS_ON=True mkdocs build
```

///

### Contributor object

The following table describes the objects that can be used to provide more
information about contributors.

| Property | Description                                  | Type  | Default |
| -------- | -------------------------------------------- | ----- | ------- |
| `email`  | Email address used to match a contributor.   | `str` | `n/a`   |
| `image`  | URL to be used as image for the contributor. | `str` | ""      |

### Including contributors' pictures

To configure images for contributors, use the `contributors` option like in the
following example:

```yaml
  - neoteroi.contribs:
      contributors:
        - email: roberto.prevato@gmail.com
          image: https://avatars.githubusercontent.com/u/2576032?s=400&u=d8d880e8ed05bb170877dd3d561d8301c4beeeed&v=4
```

Contributors are matched by email address, and the image is used if configured.

## Adding information with txt files

In some cases contributors information cannot be obtained from Git history:
for example following a history rewrite, or because contributors for a page
are not competent in Git, and contributed in ways that are not visible in the
commit history. For these situations, the contribs plugin supports adding more
information using `*.contribs.txt` files, with a structure like the following:

```
# Comment
Charlie Brown <charlie.brown@peanuts.com> (3)
Sally Brown <sally.brown@peanuts.com> (1)
Roberto Prevato <roberto.prevato@gmail.com> (10)
```

The name of the .txt files must match the name of the page:

- `example.md`
- `example.contribs.txt`

## Under the hood

This plugin works by using the following `git` commands, to obtain contributors
and the last modified time of a file:

```
git shortlog --summary --numbered --email "README.md"

git log -1 --pretty="format:%ci" "README.md"
```
