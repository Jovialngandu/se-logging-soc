#!/bin/sh
TARGET_IP=${SYSLOG_SERVER_IP:-rsyslog-central}
sed -i "s/__SYSLOG_SERVER_IP__/${TARGET_IP}/g" /etc/rsyslog.conf

rsyslogd
exec /usr/sbin/sshd -D