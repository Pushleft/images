# Pushleft images

Database images that Pushleft runs. Each one is a pinned upstream image with only the security patches or extensions in its Dockerfile.

| Image | Tags | Change |
| --- | --- | --- |
| `ghcr.io/pushleft/postgres` | `18-<commit>`, `17-<commit>` | `gosu` rebuilt with a current Go, patched Alpine packages |
| `ghcr.io/pushleft/postgres` | `18-pgvector-<commit>`, `17-pgvector-<commit>` | The above, plus pgvector, pg_textsearch and PostGIS |
| `ghcr.io/pushleft/clickhouse` | `<commit>` | Patched `libssl3` |

Every image is built for amd64 and arm64. A build pushes nothing if Trivy finds a HIGH or CRITICAL vulnerability. Pin images by digest. The run summary lists the digests.
