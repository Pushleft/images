# PostgreSQL with pgvector (gap 8, 2026-10-26), pg_textsearch and PostGIS
# (2026-11-06, Waseem): the pinned upstream image plus these extensions built
# from checksummed releases, nothing else changed. Build per major with BASE
# set to that major's pinned digest from deploy/images.lock.env, then scan
# both architectures and pin the result (gap 12) before it replaces
# PUSHLEFT_POSTGRES_IMAGE.
#
#   docker build -f deploy/images/postgres-pgvector.Dockerfile \
#     --build-arg BASE=postgres@sha256:77f585114c32fbca283dc835b0596f4e52b51b4c6662d7810b2f4084f60a1873 .
ARG BASE=postgres@sha256:77f585114c32fbca283dc835b0596f4e52b51b4c6662d7810b2f4084f60a1873

FROM ${BASE} AS build
RUN apk add --no-cache --virtual .build build-base perl geos-dev proj-dev json-c-dev protobuf-c-dev libxml2-dev pcre2-dev
ADD --checksum=sha256:cac0b10c360f05b2d521200105ba3697e773d4cd3731f5a915a7e37ebe0bea85 https://codeload.github.com/pgvector/pgvector/tar.gz/refs/tags/v0.8.7 /tmp/pgvector.tar.gz
ADD --checksum=sha256:2e7fb76ed96176afc6d16cc5d095ced2cb233ff27fbeaa8c7bfffc82e02f7498 https://codeload.github.com/timescale/pg_textsearch/tar.gz/refs/tags/v1.5.1 /tmp/pg_textsearch.tar.gz
ADD --checksum=sha256:ed8dc6679f1e06f7b113592b04cde2a7e00f1b1e681294c8ca2204058990cec6 https://download.osgeo.org/postgis/source/postgis-3.6.4.tar.gz /tmp/postgis.tar.gz
RUN for name in pgvector pg_textsearch postgis; do \
      mkdir -p /src/$name && tar -xzf /tmp/$name.tar.gz -C /src/$name --strip-components=1; \
    done
# Portable code (no -march=native: the image runs on other hosts than the
# builder) and no JIT bitcode (with_llvm=no: the image's clang is not here).
RUN cd /src/pgvector && make OPTFLAGS="" with_llvm=no && make install with_llvm=no DESTDIR=/out
# pg_textsearch (Tiger Data, PostgreSQL licence): BM25 indexes. It must be
# preloaded; the label below tells the agent so.
RUN cd /src/pg_textsearch && make with_llvm=no && make install with_llvm=no DESTDIR=/out
# PostGIS without raster: raster pulls in GDAL and its dependency tree, the
# largest CVE surface of the lot. Geometry, geography, topology and vector
# tiles (protobuf) stay.
# ponytail: no raster; build it with gdal-dev when a tenant needs postgis_raster.
RUN cd /src/postgis && ./configure --without-raster --without-gui \
 && make with_llvm=no && make install with_llvm=no DESTDIR=/out

FROM ${BASE}
# PostGIS's shared libraries (Alpine's signed packages, the same release as BASE).
RUN apk add --no-cache geos proj json-c protobuf-c libxml2 pcre2
COPY --from=build /out/usr/local/lib/postgresql/ /usr/local/lib/postgresql/
COPY --from=build /out/usr/local/share/postgresql/ /usr/local/share/postgresql/
COPY --from=build /src/pgvector/LICENSE /usr/share/licenses/pgvector/LICENSE
COPY --from=build /src/pg_textsearch/LICENSE /usr/share/licenses/pg_textsearch/LICENSE
COPY --from=build /src/postgis/COPYING /usr/share/licenses/postgis/COPYING
# dev.pushleft.postgres.preload: libraries the agent adds to
# shared_preload_libraries for containers of this image (POSTGRES_PRELOADABLE).
LABEL org.opencontainers.image.title="Pushleft PostgreSQL with pgvector, pg_textsearch and PostGIS" \
      dev.pushleft.pgvector.version="0.8.7" \
      dev.pushleft.pg_textsearch.version="1.5.1" \
      dev.pushleft.postgis.version="3.6.4" \
      dev.pushleft.postgres.preload="pg_textsearch"
# Upstream's root bootstrap, unchanged (see postgres-gosu.Dockerfile).
# nosemgrep: dockerfile.security.last-user-is-root.last-user-is-root
USER root
