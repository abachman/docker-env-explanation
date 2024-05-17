- [Multiple docker compose configurations](#multiple-docker-compose-configurations)
  * [Problem 1 - Order of Config Files with `-f`](#problem-1---order-of-config-files-with--f)
  * [Problem 2 - Environment Bleed](#problem-2---environment-bleed)
  * [Problem 3 - Automatic .env failure](#problem-3---automatic-env-failure)
- [SOLUTIONS](#solutions)
  * [Solution 1: Absolute Paths for `env_file`](#solution-1-absolute-paths-for-env_file)
  * [Solution 2: Top-level docker-compose.yml with `include` keys](#solution-2-top-level-docker-composeyml-with-include-keys)

# Multiple docker compose configurations

This project illustrates two problems with running a single docker compose project by loading `docker-compose.yml` files from multiple directories.

There are three projects: **client**, **server**, and **parters**.

The projects are configured as follows:

```yaml
# client/docker-compose.yml
services:
  client:
    image: 'alpine:latest'
    command: /bin/sh -c "echo \"clientage! VAR=$${VAR}\"" 
    env_file: docker.env

# partners/docker-compose.yml
services:
  partners:
    image: 'alpine:latest'
    command: /bin/sh -c "echo \"partnership! VAR=$${VAR}\"" 
    env_file: docker-development.env

# server/docker-compose.yml
services:
  server:
    image: 'alpine:latest'
    command: /bin/sh -c "echo \"service! VAR=$${VAR}\"" 
    environment: 
      VAR: ${FOR_BUILD:-unset}
```

## Problem 1 - Order of Config Files with `-f`

When a service defined in a `docker-compose.yml` file includes an `env_file` key, calling order of the config files with `-f config/file/path.yml` arguments is important.

In this example project, the `client` service in `client/docker-compose.yml` includes an `env_file` key. If client is listed before server, every command fails.

```console
$ docker compose  -f server/docker-compose.yml -f client/docker-compose.yml config
env file .../server/docker.env not found: stat .../server/docker.env: no such file or directory
```

With only two `docker-compose.yml` files involved, you can work around this by listing the `server` service first.

```console
$ docker compose -f client/docker-compose.yml -f server/docker-compose.yml config

```

But every version of this command fails when multiple `docker-compose.yml` files include services with `env_file` defined.

```sh
server_path=server/docker-compose.yml
client_path=client/docker-compose.yml
partners_path=partners/docker-compose.yml

docker compose -f ${client_path} -f ${partners_path} -f ${server_path} config
# env file .../client/docker-development.env not found

docker compose -f ${client_path} -f ${server_path} -f ${partners_path} config
# env file .../client/docker-development.env not found

docker compose -f ${partners_path} -f ${client_path} -f ${server_path} config
# env file .../partners/docker.env not found

docker compose -f ${partners_path} -f ${server_path} -f ${client_path} config
# env file .../partners/docker.env not found

docker compose -f ${server_path} -f ${partners_path} -f ${client_path} config
# env file .../server/docker.env not found

docker compose -f ${server_path} -f ${client_path} -f ${partners_path} config
# env file .../server/docker-development.env not found
```

All fail with a similar error.

## Problem 2 - Environment Bleed

Let's say you notice this and decide each project directory should have an `env_file` named `docker.env`. 

In `partners-2/docker-compose.yml`, you change the `env_file` key to `docker.env`.

```yaml
  partners-2:
    image: 'alpine:latest'
    command: /bin/sh -c "echo \"partnership-2! VAR=$${VAR}\"" 
    env_file: docker.env
```

And update docker.env for `partners`'s env vars to set the `VAR2` variable.

```sh
VAR2=partnership-2
```

Now `docker compose` commands combining `client` and `partners-2` work, but `environment` bleeds between services. If we list client/ first:

```console
$ docker compose -f client/docker-compose.yml -f partners-2/docker-compose.yml config

services:
  client:
    environment:
      VAR: clientage
  partners-2:
    environment:
      VAR: clientage  # <--- This should be 'VAR2: partnership-2'!
```

And if we list partners-2/ first:

```console
$ docker compose -f partners-2/docker-compose.yml -f client/docker-compose.yml config

services:
  client:
    environment:
      VAR2: partnership-2  # <--- This should be 'VAR: clientage'!
  partners-2:
    environment:
      VAR2: partnership-2
```

If client depends on `VAR` being set when `docker compose {up,run,exec}` is called, it will fail in the second case.

## Problem 3 - Automatic .env failure

`docker compose` automatically uses a file named `.env` in the same directory to populate the service environment, if it exists.

```console
$ docker compose -f server/docker-compose.yml config

services:
  server:
    environment:
      VAR: .env
```

But if we include an additional `docker-compose.yml` file, `.env` is never loaded. The only good news is that we don't seem to see environment bleed (Problem 2) between `client` and `server`.

```console
$ docker compose  -f client/docker-compose.yml -f server/docker-compose.yml config

services:
  client:
    environment:
      VAR: clientage
  server:
    environment:
      VAR: unset
```

# SOLUTIONS

## Solution 1: Absolute Paths for `env_file`

The solution to all three problems is to use absolute paths for `env_file` keys in `docker-compose.yml` files.

```yaml
# in client/docker-compose.yml
  client: 
    env_file: ${CLIENT_ROOT_PATH}/docker.env

# in partners/docker-compose.yml
  partners:
    env_file: ${PARTNERS_ROOT_PATH}/docker-development.env

# in partners-2/docker-compose.yml
  partners-2:
    env_file: ${PARTNERS2_ROOT_PATH}/docker.env
```

Then, set the `*_ROOT_PATH` environment variables in the shell before running `docker compose`.

```console
$ CLIENT_ROOT_PATH=$(pwd)/client PARTNERS_ROOT_PATH=$(pwd)/partners PARTNERS2_ROOT_PATH=$(pwd)/partners-2 \
  docker compose \
    -f server/docker-compose.yml \
    -f client/docker-compose.yml \
    -f partners/docker-compose.yml \
    -f partners-2/docker-compose.yml \
    config
```

This fixes the named `env_file` problem (Problem 1) and environment bleed (Problem 2) between services, but doesn't fix the automatic `.env` file problem (Problem 3).

## Solution 2: Top-level docker-compose.yml with `include` keys

An alternative solution is to create a top-level `docker-compose.yml` file that includes the other `docker-compose.yml` files and sets `project_directory` for each explicitly, relative to itself. [This feature of docker compose is documented here](https://docs.docker.com/compose/compose-file/14-include/#env_file).

```yaml
# docker-compose.combined.yml
version: '2.3'

include: 
  - path: ./client/docker-compose.yml
    project_directory: ./client
  - path: ./partners/docker-compose.yml
    project_directory: ./partners
  - path: ./partners-2/docker-compose.yml
    project_directory: ./partners-2
  - path: ./server/docker-compose.yml
    project_directory: ./server
```

```console
$ docker compose -f docker-compose.combined.yml config

services:
  client:
    environment:
      VAR: clientage
  partners:
    environment:
      VAR: partnership
  partners-2:
    environment:
      VAR: partnership-2
  server:
    environment:
      VAR: .env
```

And running every service, we see the same output as if we ran them separately.

```console
$ docker compose -f docker-compose.combined.yml up

partners-1    | partnership! VAR=partnership
partners-2-1  | partnership-2! VAR=partnership-2
server-1      | service! VAR=.env
client-1      | clientage! VAR=clientage
```