# Docker Image for Wildfly 10

This is a Docker image for Wildfly 10. It is based on the Alpine variant of the official [OpenJDK container image](https://hub.docker.com/_/openjdk/) and uses @just-containers [s6-overlay](https://github.com/just-containers/s6-overlay) to run Wildfly.

## Build

```
docker image build -t soulwing/wildfly10 .
```

## Environment Variables

This image sets two environment variables which may be helpful as you
create your downstream images.

### `WILDFLY_USER`

This identifies the user and group name that will be used to run Wildfly
in the container. Because the container uses _s6-overlay_ for process 
supervision, you cannot run the entire container as a non-root user. However,
the Wildfly process itself (as well as the CLI process described in
[Running the JBoss CLI](#running-the-jboss-cli)) run as the user specified
by this environment variable.

Note that you **cannot change the user without rebuilding the container
image**. The user and group named by `WILDFLY_USER` are created as part of
the image building process.

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


### `WILDFLY_HA`

When set to `true`, Wildfly is run using the `standalone-ha.xml` configuration
as the base which is subsequently configured.


### `WILDFLY_BIND_INTERFACE`

Identifies the container interface to which Wildfly's public, private, and 
(optionally) management interfaces will be bound. When running in a container, 
Wildfly's default behavior of binding the private and management interfaces 
to localhost isn't very useful, so the `run-wildfly` script binds all 
interfaces to a common interface.

The default value is `eth0` (the container's virtual ethernet interface) 
which is usually what you want if you're using the default _bridge_ network 
mode. If your Docker network set up is more elaborate, you may want to 
specify a different interface.  

* You can specify the interface name to which to bind; e.g. `eth1`. 
* You can also specify a network prefix assigned to a docker network; e.g. `172.19.0.0/16`
* You can also specify `any` to allow Wildfly to bind using address 0.0.0.0. 
  **Note that this is not supported when running Wildfly in high-availability 
  mode** (`WILDFLY_HA`) because of a limitation of the JGroups component used 
  by Wildfly to support cluster node discovery and communication.

If you want even more control over how network interfaces are bound by wildfly, 
replace `${WILDFLY_HOME}/bin/run-wildfly` or install your own script and run 
it as the CMD in an image that extends this image.

### WILDFLY_MGMT_BIND_INTERFACE

Identifies the container interface to which Wildfly's management interface
will be bound. Allows the interface name or address to be specified in the
same ways as the `WILDFLY_BIND_INTERFACE` variable. 

If not specified, the default is to use the value of `WILDFLY_BIND_INTERFACE`.

## Configuring Wildfly at Startup

You can configure Wildfly when the image starts up in a few different ways.

### Replacing Configuration Files

You can place configuration files in `/etc/wildfly` in an image based on this 
image. These files will copied to `$WILDFLY_HOME/standalone/configuration` 
when the image is started up the first time. Note that only files are copied;
not directories.

This is a good way to replace files such as

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

`121-create-datasource:`
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

`120-install-jdbc-driver:`
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

## Running the JBoss CLI

The image provides an easy way to run the JBoss CLI (`jboss-cli.sh`) inside
of your container. This is especially handy if you're binding the Wildfly
socket listeners to your container's ethernet interface, needed for 
Wildfly high-availability -- the provided script takes care of using the 
correct address for Wildfly's management controller.

Get the Docker ID of your running container using `docker ps`, then run the
following command.

```
docker exec -ti {container-id} cli
```

You'll be dropped into the CLI prompt for the running Wildfly instance.
