FROM alpine:latest

RUN apk add --no-cache openssh rsyslog

RUN ssh-keygen -A && \
    echo "root:password123" | chpasswd && \
    sed -i 's/#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config

# Copie depuis le dossier config/client/
COPY config/client/rsyslog-client.conf /etc/rsyslog.conf
COPY config/client/entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]