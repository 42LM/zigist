# Zigist - Update a gist with a random dev joke
[![test](https://github.com/lmllrjr/zigist/actions/workflows/test.yaml/badge.svg)](https://github.com/lmllrjr/zigist/actions/workflows/test.yaml) [![cron](https://github.com/lmllrjr/zigist/actions/workflows/cron.yaml/badge.svg)](https://github.com/lmllrjr/zigist/actions/workflows/cron.yaml)

Nothing fancy here. This is just a simple github action to update a gist with a random dev joke using [Zig ⚡️](https://github.com/ziglang/zig).

## Quick start
```yaml
uses: lmllrjr/zigist@v1
with:
  gh-token: ${{ secrets.GH_TOKEN }}
  gist-id: from_gist_url
```

## Inputs
|Input Name|Description|Required|
| --- | --- | :---: |
|`gh-token`|The GitHub [Personal Access Token](https://docs.github.com/en/enterprise-server@3.9/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens) with *gist* access|☑️|
|`gist-id`|The GitHub public gist id|☑️|


> [!IMPORTANT]
> #### `gh-token`: The GitHub Token needs to be created as a repository secret in the repository that uses this action.[^1]
> #### `gist-id`: The GitHub gist needs to be created with the file name `NEWS.md`.[^2]


## Example usage
Setup a secret in the repository you want to use this action in.

```yaml
on: [push]

jobs:
  zigist-update-gist:
    runs-on: ubuntu-latest
    name: A job update a gist with a random dev joke
    steps:
      - name: Update gist action step
        id: zigist
        uses: lmllrjr/zigist@v1
        with:
          gh-token: ${{ secrets.GH_TOKEN }}
          gist-id: d0313228583992554c58c626b7df7f2f
```

## Local environment setup
The following two environment variables need to be set up:
1. `GH_TOKEN`: Create a github token that has access to gists.
2. `GIST_ID`: Create a gist.

Copy `.envrc.example` to `.envrc` and edit values. Load this environment into your shell, for example with [direnv](https://direnv.net/).
```sh
cp .envrc.example .envrc
```

### Zig
```sh
zig build run
```

```sh
zig build test --summary all
```

### Docker
```sh
docker build -t ziglang/static-v0.11.0 .
```

```sh
docker run --name zigist ziglang/static-v0.11.0 $GH_TOKEN $GIST_ID
```

[^1]: Place repository secret: ![Screenshot 2024-03-17 at 23 54 25](https://github.com/lmllrjr/zigist/assets/93522910/667ad7a8-bc4e-4115-85bf-61945095f1dc)
[^2]: Create github gist with filename `NEWS.md`: ![Screenshot 2024-03-17 at 23 30 13](https://github.com/lmllrjr/zigist/assets/93522910/e0b614d2-131f-480e-9203-0c08f1b77a7e)
