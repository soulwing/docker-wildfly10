# Docker Image for Wildfly 10

This is a Docker image for Wildfly 10. It is based on @frol 
[alpine-oraclejdk8] (https://github.com/frol/docker-alpine-oraclejdk8) and
uses @just-containers [s6-overlay] (https://github.com/just-containers/s6-overlay) to run Wildfly.

## Build

```
docker build -t soulwing/wildfly10 .
```

## Environment Variables

This image sets two environment variables which may be helpful as you
create your downstream images.

### `WILDFLY_HOME` 

This is the location where Wildfly is installed in the container filesystem. 
It defaults to `/apps/wildfly` but could be specified as a different location
when the `soulwing/wildfly10` image is built.

Downstream images that need to install things into the Wildfly should use 
this variable. Examples of things you might want to install:

* Content for `$WILDFLY_HOME/welcome-content`.
* Custom modules in `$WILDFLY_HOME/modules`.
* Your own bootstrap configuration in `$WILDFLY_HOME/bin/standalone.conf`


### `WILDFLY_RUNTIME_BASE_DIR` 

In order to allow a container to run with a read-only root filesystem, when
this image is built it replaces `$WILDFLY_HOME/standalone` with a symbolic
link to the location specified by this variable. The location defaults to
`/var/run/wildfly` and is assumed to be on a writeable filesystem.

At container startup, the original standalone configuration (at path
`$WILDFLY_HOME/standalone.OEM`) is copied to this location and thus contains
the working configuration of Wildfly.

If you are writing your own `cont-init.d` scripts that run after 
`150-wildfly-config` and those scripts need to modify the configuration in 
some manner, you'll need to target `WILDFLY_RUNTIME_BASE_DIR` as the location
that contains the Wildfly directories `configuration`, `data`, `deployments`, 
`log`, etc.


## Configuring Wildfly at Startup

You can configure Wildfly when the image starts up in a few different ways.

### Replacing Configuration Files

You can place files in `/etc/summit` in an image based on this image. These 
files will copied to `$WILDFLY_HOME/standalone/configuration` when the image
is started up the first time. This is a good way to replace files such as

* `application-users.properties`
* `application-roles.properties`
* `logging.properties`

You can also use this approach to replace `standalone.xml`, but it isn't
recommended. Instead you should [use configuration snippets](#using-configuration-snippets)

### Using Configuration Snippets

The image includes an s6-overlay container initialization script in 
`/etc/cont-init.d`. The `150-wildfly-config` script uses the JBoss CLI 
(`jboss-cli.sh`) to apply zero or more ordered configuration snippets to 
the standalone server configuration. The script applies the configuration 
the first time the container is started; subsequent restarts of the same 
container will use the same configuration.

Configuration snippets should be placed in `/etc/wildfly/config.d`. The 
snippets are applied in lexical order, so start each snippet name with 
a number; e.g. `121-create-datasource`, and name them such that your 
configuration is applied in the right order. 

A snippet can be almost any CLI command (or sequence of commands). For example,
a snippet that creates a JDBC data source might be written as follows.

```121-create-datasource:```

```
data-source add --name=exampleDS \
  --jndi-name=java:/jdbc/datasources/exampleDS \
  --user-name=mysql \
  --password=pass4mysql \
  --driver-name=mysql.jar \
```

The previous data source command will need the `mysql.jar` JDBC driver to be 
deployed before it can execute successfully. You can do this using a 
lower-numbered snippet that uses the `deploy` command.

```120-install-jdbc-driver:```

```
deploy --name=mysql.jar /apps/artifacts/mysql-connector-java-5.1.33.jar
```

This assumes, of course, that your image contains the JAR file for the JDBC
driver to the path `/apps/artifacts/mysql-connector-java-5.1.33.jar`.

Each snippet is executed as a batch (using the CLI's `run-batch`) command. 
If the batch is executed successfully, the CLI prints a messaging indicating 
such. If a batch fails, the CLI prints an error, and configuration stops.

While you can place all configuration in a single snippet, it isn't 
recommended. Smaller snippets are more manageable, promote reuse, and allow 
you to build up complex configurations by layering on configuration snippets 
using Docker.

### Using `cont-init.d` Scripts

You can add your own scripts to `/etc/cont-init.d` which run before or after
`150-wildfly-config`. This is the best way to replace 
`$WILDFLY_HOME/bin/standalone.conf`. Scripts that you write should be designed
to run once, since the container may be restarted multiple times before it
is destroyed. See `150-wildfly-config` for an example of how you might
do this.

## Deploying Applications and Other Artifacts

The recommended practice here is to make a Docker image using this image as
a base, in which you COPY or ADD your artifacts to `/apps/artifacts` in the
image. 

Add configuration snippets (as described above), to deploy your artifacts
using the CLI's `deploy` command. The recommended practice is one deployment
per snippet. This allows you to easily manage the order of deployment using 
the lexical order in which snippets are applied, and allows complex 
deployment scenarios to be assembled using Docker layers.
