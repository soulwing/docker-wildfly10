#!/usr/bin/with-contenv /bin/sh

bind_address=$(cat ${WILDFLY_BIND_ADDRESS})
exec s6-setuidgid ${WILDFLY_USER} ${WILDFLY_HOME}/bin/standalone.sh \
     -b $bind_address \
     -bprivate $bind_address \
     -bmanagement $bind_address \
     -Djboss.as.management.blocking.timeout=600 \
     "$@"
