# Docker Image for Wildfly 10

This is a Docker image for Wildfly 10. It is based on @frol 
[alpine-oraclejdk8] (https://github.com/frol/docker-alpine-oraclejdk8) and
uses @just-containers [s6-overlay] (https://github.com/just-containers/s6-overlay) to run Wildfly.

## Build

```
docker build -t soulwing/wildfly10 .
```

## Configuring Wildfly at Startup

The image includes an s6-overlay container initialization script in `/etc/cont-init.d`. The `150-wildfly-config` script uses the JBoss CLI (`jboss-cli.sh`) to apply zero or more ordered configuration snippets to an embedded instance of the server.

Configuration snippets should be placed in `/etc/wildfly/config.d`. The snippets are applied in lexical order, so start each snippet name with a number; e.g. `120-create-datasources`, and name them such that your configuration is applied in the right order.

Each snippet is executed as a batch (using the CLI's `run-batch`) command. If the batch is executed successfully, the CLI prints a messaging indicating such. If a batch fails, the CLI prints an error, and configuration stops.

While you can place all configuration in a single snippet, it isn't recommended. Smaller snippets are more manageable, promote reuse, and allow you to build up complex configurations by layering on configuration snippets using Docker.

## Deploying Applications and Other Artifacts

The recommended practice here is to make a Docker image using this image as
a base, in which you COPY or ADD your artifacts to `/apps/artifacts` in the
image. 

Add configuration snippets (as described above), to deploy your artifacts
using the CLI's `deploy` command. The recommended practice is one deployment
per snippet. This allows you to easily manage the order of deployment using the lexical order in which snippets are applied, and allows complex deployment scenarios to be assembled using Docker layers.
