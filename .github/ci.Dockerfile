# CI image: Swift 6 + Go 1.23 (matches test-examples-publish-signing workflow).
# Use with: docker compose -f docker-compose.ci.yml run --rm ci
FROM swift:6.2.4-jammy

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    lsof \
    make \
    openssl \
    zip \
    && rm -rf /var/lib/apt/lists/*

# Go 1.23 (workflow uses go-version "1.23")
ARG GO_VERSION=1.23.2
RUN curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-$(dpkg --print-architecture).tar.gz" -o /tmp/go.tar.gz \
    && rm -rf /usr/local/go \
    && tar -C /usr/local -xzf /tmp/go.tar.gz \
    && rm /tmp/go.tar.gz
ENV PATH="/usr/local/go/bin:${PATH}"

WORKDIR /workspace
