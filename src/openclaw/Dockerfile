FROM ghcr.io/openclaw/openclaw:2026.6.11
COPY patches/ /etc/openclaw/patches/
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh
ENTRYPOINT ["docker-entrypoint.sh"]
