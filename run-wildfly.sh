#!/usr/bin/with-contenv /bin/sh

bind_address=$(cat ${WILDFLY_BIND_ADDRESS})
exec /apps/wildfly/bin/standalone.sh \
     -b $bind_address \
     -bprivate $bind_address \
     -bmanagement $bind_address \
     -Djboss.as.management.blocking.timeout=600 \
     "$@"
