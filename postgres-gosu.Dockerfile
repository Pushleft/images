# Candidate only: do not promote without both architecture scans, live engine
# tests and restore/upgrade verification. PostgreSQL and its entrypoint stay
# byte-for-byte from the existing pinned upstream image.
# Root bootstrap is required to chown the agent's root-owned bind PGDATA and
# read its root-only password file. The unchanged upstream entrypoint execs
# non-root postgres. The image-probe fixture attests all postgres UID/GID,
# zero capabilities and NoNewPrivs before/after restart under bounded caps.
# This exception is only for bootstrap, expires for re-review, and does not
# suppress package vulnerabilities or authorize image promotion.
# BASE: the pinned upstream PostgreSQL of one major (deploy/images.lock.env).
ARG BASE=postgres@sha256:b0f9560a2de083e2cc7382e75f808c7381a32852a7ec49117deedb300e552b24
FROM golang:1.27.3-alpine3.24@sha256:d200d2dd76b03a99b52651fd1325aff7dcd35422c35c01bac56571b0507f3deb AS gosu
ARG TARGETARCH
ENV CGO_ENABLED=0 GOTOOLCHAIN=local
ADD --checksum=sha256:33d7537d588ea49458b9509bcf4554bdf5ceacc66da71e5caa1058ea3b689c3b https://codeload.github.com/tianon/gosu/tar.gz/6456aaa0f3c854d199d0f037f068eb97515b7513 /tmp/gosu.tar.gz
RUN mkdir /src && tar -xzf /tmp/gosu.tar.gz -C /src --strip-components=1
WORKDIR /src
RUN test "$(go env GOVERSION)" = go1.27.3 && \
    GOARCH="$TARGETARCH" go build -mod=readonly -trimpath -buildvcs=false -ldflags '-d -w' -o /out/gosu . && \
    go version -m /out/gosu

FROM ${BASE}
COPY --from=gosu --chmod=0755 /out/gosu /usr/local/bin/gosu
COPY --from=gosu /src/LICENSE /usr/share/licenses/gosu/LICENSE
COPY --from=gosu /usr/local/go/LICENSE /usr/share/licenses/gosu/GO-LICENSE
LABEL org.opencontainers.image.title="Pushleft PostgreSQL gosu security candidate" \
      dev.pushleft.gosu.source="6456aaa0f3c854d199d0f037f068eb97515b7513" \
      dev.pushleft.gosu.toolchain="go1.27.3"
RUN gosu --version && test "$(gosu postgres id -u)" = "$(id -u postgres)"
# Alpine packages whose fixes are newer than the pinned upstream digest
# (scanned 2026-10-30); only what the scan names, nothing else changes.
RUN apk upgrade --no-cache brotli-libs libcurl
# Explicitly preserve upstream root bootstrap; see the compensating controls
# and process-level fixture evidence above. Do not extend this to daemon UIDs.
# Trivy's matching path-scoped exception is in deploy/security/trivy-exceptions.yaml.
# nosemgrep: dockerfile.security.last-user-is-root.last-user-is-root
USER root
