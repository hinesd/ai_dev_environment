FROM ghcr.io/openclaw/openclaw:latest

ARG APT_PACKAGES=""
RUN if [ -n "$APT_PACKAGES" ]; then \
      apt-get update && apt-get install -y $APT_PACKAGES && rm -rf /var/lib/apt/lists/*; \
    fi

ARG PIP_PACKAGES=""
RUN if [ -n "$PIP_PACKAGES" ]; then \
      python3 -m pip install --break-system-packages $PIP_PACKAGES; \
    fi
