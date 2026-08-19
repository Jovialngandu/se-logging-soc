FROM alpine:latest

# Installation de glib (fournit gio)
RUN apk add --no-cache openssh rsyslog glib nano

RUN ssh-keygen -A && \
    echo "root:password123" | chpasswd && \
    sed -i 's/#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config

COPY config/client/rsyslog-client.conf /etc/rsyslog.conf
COPY config/client/entrypoint.sh /entrypoint.sh

RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]