Trying to wrap my head around docker-compose environment variables.

ref: https://docs.docker.com/compose/environment-variables/envvars-precedence/

The claimed precedence is, highest to lowest:

> 1. Set using `docker compose run -e` in the CLI
> 2. Substituted from your shell
> 3. Set using the `environment:` attribute in the Compose file
> 4. Use of the `--env-file` argument in the CLI
> 5. Use of the `env_file:` attribute in the Compose file
> 6. Set using an `.env` file placed at base of your project directory
> 7. Set in a container image in the `ENV` directive. Having any ARG or ENV setting in a Dockerfile evaluates only if there is no Docker Compose entry for environment, env_file or run --env.

But this is not explained well in the documentation, and listing the precedence in this order is misleading.

## Which environment are we talking about?

There are two important contexts / "environments" in play here and they are not the same:

- the **host** context, which is your shell where you are running `docker compose` commands.
- the **container** context, which is inside the docker process when a `docker compose run` command is running.

**host** envirnoment variables are available during `docker compose` setup, but _not_ from inside containers unless they are passed through to the **container** environment. This means they can be referred to from `environment:` attributes (`VAR: ${VAR}`) or inside `*.env` files named in the `env_file:` attribute (`VAR=$VAR`).

**container** environment variables can be seen and used by processes running inside containers.

"dotenv" files have different effects on these environments depending on how they are used:

- `.env` in the project root only affects the **host** environment and contriutes ENV vars which can be used on the right hand side of variable definitions in docker-compose.yml `environment:` attributes and in the files named in docker-compose.yml `env_file:` attributes.
- `docker compose --env-file arg.env` command line arguments also only affect the **host** environment. The variables in the named file can be used in docker-compose.yml evaluation, but _are not passed to the container_.
- `env_file: file.env` in docker-compose.yml affects the **container** environment, and contriutes ENV vars which can be used by processes running inside containers.

This means that docker compose's precedence of environment variables could be better explained by splitting it into two lists, one for each context.

#### host ENV vars

1. **host** shell context variables are available to docker compose commands
```console
$ export VAR=shell
$ docker compose run app

# or

$ VAR=shell docker compose run app
```

2) `docker compose --env-file file.env ...` sets **host** context variables from `file.env`.
3) `.env` file in project root sets **host** context variables.

> [!WARNING]
> **host** environment variables can be passed through to the container context **if and only if** they are used _ON THE RIGHT HAND SIDE_ of variable expressions in docker-compose.yml `environment:` attributes or `env_file:` files.

#### container ENV vars

1. `docker compose run -e VAR=cli` passes an environment variable into the running **container** context
2. an `environment:` attribute in docker-compose.yml will be evaluated in the **host** context and pass vars into the **container** context.
```yaml
services:
  myapp:
    environment:
      # passes VAR from host (on the right) to container (on the left)
      VAR: ${VAR}
```

3. an `env_file:` attribute in docker-compose.yml will be evaluated in the **host** context and pass env vars into the **container** context.
```sh
VAR=${VAR}
```
4. Set in a container image in the `ENV` directive. Having any ARG or ENV setting in a Dockerfile evaluates only if there is no Docker Compose attribute for `environment:`, `env_file:` or `run -e`.

> [!WARNING]
> `docker compose --env-file file.env` at the command line and `env_file: file.env` in docker-compose.yml **refer to two different environments** and are evaluated at two different times.

`env_file:` is for the **container** environment and `--env-file` is for the **host** environment.

If you see `VAR=$VAR` in an `env_file:` file, or `VAR: $VAR` in a docker-compose `environment:` attribute, you are seeing a **host** variable (on the right) being passed into a **container** env var (on the left).

## Report

Use `demo.sh` to generate this report.

```sh
./demo.sh
```

Each entry is four runs of `docker compose run` with the scenarios described by the arguments.

Use `DEBUG=true ./demo.sh` if you want to see the actual commands being run.

```sh
DEBUG=true ./demo.sh
```

```console
$ ./demo.sh

╔═════════════════════════════╗
║                             ║
║     Dockerfile with ENV     ║
║                             ║
╚═════════════════════════════╝

┌────────────────────┐
│                    │
│     myapp-none     │
│                    │
└────────────────────┘
  run                    Dockerfile
  --env-file run         Dockerfile
  run -e                 run -e
  --env-file run -e      run -e

┌───────────────────────┐
│                       │
│     myapp-envfile     │
│                       │
└───────────────────────┘
  run                    file.env
  --env-file run         file.env
  run -e                 run -e
  --env-file run -e      run -e

┌───────────────────────────┐
│                           │
│     myapp-environment     │
│                           │
└───────────────────────────┘
  run                    docker-compose.yml
  --env-file run         docker-compose.yml
  run -e                 run -e
  --env-file run -e      run -e

┌───────────────────────────────────────┐
│                                       │
│     myapp-environment-passthrough     │
│                                       │
└───────────────────────────────────────┘
  run                    .env
  --env-file run         arg.env
  run -e                 run -e
  --env-file run -e      run -e

┌───────────────────┐
│                   │
│     myapp-all     │
│                   │
└───────────────────┘
  run                    .env
  --env-file run         arg.env
  run -e                 run -e
  --env-file run -e      run -e


╔════════════════════════════════╗
║                                ║
║     Dockerfile without ENV     ║
║                                ║
╚════════════════════════════════╝

┌────────────────────┐
│                    │
│     myapp-none     │
│                    │
└────────────────────┘
  run                    undefined
  --env-file run         undefined
  run -e                 run -e
  --env-file run -e      run -e

┌───────────────────────┐
│                       │
│     myapp-envfile     │
│                       │
└───────────────────────┘
  run                    file.env
  --env-file run         file.env
  run -e                 run -e
  --env-file run -e      run -e

┌───────────────────────────┐
│                           │
│     myapp-environment     │
│                           │
└───────────────────────────┘
  run                    docker-compose.yml
  --env-file run         docker-compose.yml
  run -e                 run -e
  --env-file run -e      run -e

┌───────────────────────────────────────┐
│                                       │
│     myapp-environment-passthrough     │
│                                       │
└───────────────────────────────────────┘
  run                    .env
  --env-file run         arg.env
  run -e                 run -e
  --env-file run -e      run -e

┌───────────────────┐
│                   │
│     myapp-all     │
│                   │
└───────────────────┘
  run                    .env
  --env-file run         arg.env
  run -e                 run -e
  --env-file run -e      run -e
  ```