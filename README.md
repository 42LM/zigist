# zigist
Nothing fancy here. This is just a simple cron job to update a gist using [Zig ⚡️](https://github.com/ziglang/zig).

## Local environment setup
The following two environment variables need to be set up:
1. `GH_TOKEN`: Create a github token that has access to gists.
2. `GIST_ID`: Create a gist.

Copy `.envrc.example` to `.envrc` and edit values. Load this environment into your shell, for example with [direnv](https://direnv.net/).
```sh
cp .envrc.example .envrc
```

```sh
zig build run
```
