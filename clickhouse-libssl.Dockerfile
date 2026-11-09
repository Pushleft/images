# Unpromoted candidate. Preserve the exact engine/entrypoint and Ubuntu package
# inventory; update only the vulnerable distro library from signed repositories.
# Pinning the exact package version prevents silently pulling a different patch.
FROM clickhouse/clickhouse-server@sha256:bdb5c911a23d92fd364e246ab20b5a0a485f00112f3663fa626b083fb46c146b
ARG LIBSSL_VERSION=3.0.2-0ubuntu1.30
# apt: the fix for CVE-2026-109518 (scanned 2026-11-09). The vulnerable apt installs
# the fix, so its install runs with no retries.
ARG APT_VERSION=2.4.15ubuntu0.1
RUN apt-get update --error-on=any && \
    apt-get -o Acquire::Retries=0 install --yes --no-install-recommends --only-upgrade "libssl3=${LIBSSL_VERSION}" "apt=${APT_VERSION}" "libapt-pkg6.0=${APT_VERSION}" && \
    test "$(dpkg-query -W -f='${Version}' libssl3)" = "${LIBSSL_VERSION}" && \
    test "$(dpkg-query -W -f='${Version}' apt)" = "${APT_VERSION}" && \
    rm -rf /var/lib/apt/lists/*
LABEL org.opencontainers.image.title="Pushleft ClickHouse libssl security candidate" \
      dev.pushleft.clickhouse.version="26.9.19.9" \
      dev.pushleft.libssl.version="3.0.2-0ubuntu1.30"
# Upstream root bootstrap is required for root-owned bind data/users/logs and
# root-only file secrets. The unchanged entrypoint drops to clickhouse; the
# image fixture verifies daemon UID/GID, zero capabilities and NoNewPrivs.
# Candidate-only bootstrap risk must be reviewed before registry publication.
# The path-scoped DS002 exception expires 2026-11-15; it does not suppress CVEs.
# nosemgrep: dockerfile.security.last-user-is-root.last-user-is-root
USER root
