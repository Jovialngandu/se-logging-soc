#!/bin/sh
TARGET_IP=${SYSLOG_SERVER_IP:-rsyslog-central}
sed -i "s/__SYSLOG_SERVER_IP__/${TARGET_IP}/g" /etc/rsyslog.conf

rsyslogd
sleep 1

logger -t client_init "System logging initialized for target ${TARGET_IP}"

# gio monitor surveille le fichier et envoie directement l'événement
gio monitor /etc/passwd | while read -r line; do
    logger -t fim_event "alerte_fim: $line"
done &

exec /usr/sbin/sshd -D