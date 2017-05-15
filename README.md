# Docker image for mysql 5.0 legacy projects
This docker image is intended to work as a replacement for old legacy projects, running on old server.

The entrypoint was partially taken from https://github.com/docker-library/mysql and easyfied/adapted.

To avoid permission issues, it's recommended to let the server be run with the uid of your current user. A sample `docker-composer.yml` block could look like this.

```yml
services:
    db:
        build:
            context: ./docker/mysql
            args:
                # This sets uids with fallback of user 1000
                # Can be overwritten with a custom .ENV file
                uid: "${USER_UID:-1000}"
                gid: "${USER_GID:-1000}"
        ports:
            - "${DB_PORT:-3307}:3306"
        environment:
            MYSQL_ROOT_PASSWORD: "${DB_ROOT_PW:-root}"
            MYSQL_ROOT_HOST: "${DB_ROOT_HOST:-%}"
            MYSQL_DATABASE: "mydatabase"
            MYSQL_USER: "${DB_USER:-myuser}"
            MYSQL_PASSWORD: "${DB_PASSWORD:-mypassword}"
        volumes:
            - ./docker/mysql/data:/mysql/data
```

*NOTE*: It's hardly recommended to add the data folder to your .dockerignore file. Otherwise your whole database is sent to the docker daemon upon building the image.

It's recommended to use your own user mapping, by creating a project-specific layer looking like this. This will consume the `uid` and `gid` from the `docker-compose.yml` upon build.
```Dockerfile
FROM kuborgh/mysql-5.0

ARG uid=1001
ARG gid=1001

# ensure user exists
RUN addgroup --gid $gid --system mysql \
	&& adduser --uid $uid --disabled-password --system --gid $gid mysql
```
