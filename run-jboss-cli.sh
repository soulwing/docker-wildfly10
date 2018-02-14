#!/usr/bin/with-contenv /bin/sh

ctrl_address=$(cat ${WILDFLY_MGMT_BIND_ADDRESS})
if [ "$ctrl_address" = "0.0.0.0" ]; then
  ctrl_address=127.0.0.1
fi

exec s6-setuidgid ${WILDFLY_USER} ${WILDFLY_HOME}/bin/jboss-cli.sh \
     --connect --controller=${ctrl_address}:9990 "$@"
