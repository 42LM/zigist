[![cron](https://github.com/lmllrjr/zigist/actions/workflows/cron.yaml/badge.svg)](https://github.com/lmllrjr/zigist/actions/workflows/cron.yaml)

# zigist - update a gist with a random dev joke docker action
Nothing fancy here. This is just a simple github action to update a gist with a random dev joke using [Zig ⚡️](https://github.com/ziglang/zig).

## Consider trying it out?
### Inputs
#### `gh-token` (🚨 required)
The GitHub [Personal Access Token](https://docs.github.com/en/enterprise-server@3.9/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens).

> [!IMPORTANT]
> ⚠️ The GitHub Token needs to be placed as a repository secret in the repository that uses this action:

#### `gist-id` (🚨 required)
The id of the gist that should be updated.

### Example usage
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
          gist-id: 'd0313228583992554c58c626b7df7f2f'
```

## Local environment setup
The following two environment variables need to be set up:
1. `GH_TOKEN`: Create a github token that has access to gists.
2. `GIST_ID`: Create a gist.

Copy `.envrc.example` to `.envrc` and edit values. Load this environment into your shell, for example with [direnv](https://direnv.net/).
```sh
cp .envrc.example .envrc
```

### Run regulat
```sh
zig build run
```

### Docker
```sh
docker build -t ziglang/static .
```

```sh
docker run --name zigist ziglang/static $GH_TOKEN $GIST_ID
```
