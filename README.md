# Zigist - Update a gist with a random dev joke
[![test](https://github.com/lmllrjr/zigist/actions/workflows/test.yaml/badge.svg)](https://github.com/lmllrjr/zigist/actions/workflows/test.yaml) [![cron](https://github.com/lmllrjr/zigist/actions/workflows/cron.yaml/badge.svg)](https://github.com/lmllrjr/zigist/actions/workflows/cron.yaml)

Nothing fancy here. This is just a simple github action to update a gist with a random dev joke using [Zig ⚡️](https://github.com/ziglang/zig).

## Quick start
```yaml
uses: 42LM/zigist@v1
with:
  gh-token: ${{ secrets.GH_TOKEN }}
  gist-id: e35b7dfc8ec2c958a7f8f0c9938ffd60
```

> [!TIP]
> Pin the gist in your profile:  
> <br>
> <img width="466" alt="Screenshot 2024-03-18 at 01 00 19" src="https://github.com/lmllrjr/zigist/assets/93522910/a5ea6d0e-fdd0-442d-9375-5b9d6876d89b">
> <br>
> [See it in ~action~ the wild](https://github.com/lmllrjr)

## Inputs
|Input Name|Description|Required|
| --- | --- | :---: |
|`gh-token`|The GitHub [Personal Access Token](https://docs.github.com/en/enterprise-server@3.9/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens) with *gist* access|☑️|
|`gist-id`|The GitHub public gist id|☑️|

> [!IMPORTANT]
> #### `gh-token`: The GitHub Token needs to be created as a repository secret in the repository that uses this action.[^1]
> #### `gist-id`: The GitHub gist needs to be created with the file name `NEWS.md`.[^2]

## Example usage
https://github.com/lmllrjr/zigist/blob/d37412dd9250a000898ba2ba1313edefadf19204/.github/workflows/cron.yaml#L1-L16

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
