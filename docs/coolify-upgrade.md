# Upgrading OpenProject on Coolify

Production is Coolify application `openproject` (compose file `/coolify.compose.yml`, branch
`stable-17-plugin`). Coolify builds `Dockerfile.app` on the server at deploy time. Migrations run
in `op-seeder` and only go forward: rolling back means restoring the database, not switching images.

## 1. Bump the version in git

Pin an exact patch tag (never a floating `17-slim`) in all of these, in one commit:

| File | Line |
|---|---|
| `Dockerfile.app` | `ARG TAG=<x.y.z>-slim` |
| `coolify.compose.yml` | `x-op-image` build arg + `image:` default, `op-hocuspocus` image |
| `docker-compose.yml` | same three |
| `docker-compose.dev.yml` | `op-dev` image default |
| `.env.example` | `TAG=` |

Read the release notes for migration warnings, then rehearse locally: build the old and new image,
start the old one with test data, stop writers, record row counts, switch to the new tag, and let the
seeder migrate. Compare counts table by table and smoke-test every plugin page.

## 2. Coolify environment

The Coolify env var `TAG` overrides the compose default. Either delete it (the version then lives
only in git) or set it to the same `<x.y.z>-slim` before deploying.

## 3. Deploy

Data lives in bind mounts `/srv/appdata/openproject/{pgdata,assets}`. Coolify has no backup job for it.

1. `pg_dump -Fc` from `op-db` into `~/backups/openproject/`; record counts of `work_packages`,
   `users`, `journals`.
2. Stop `op-worker`, `op-cron`, `op-web`, then `op-db`; cold-copy `pgdata` (`cp -a`) next to it.
3. `docker tag openproject-custom:<old-tag> openproject-custom:<old-version>-rollback`.
4. Point Coolify at the new commit SHA (not HEAD) and deploy. Watch the `op-seeder` logs.
5. Smoke-test login, work packages, each plugin page, team planner, collaborative editing. Compare counts.

## Rollback

Stop the stack, restore `pgdata` from the cold copy (the dump is the second line of defence), set
`TAG` back to the old version, and redeploy the previous commit. Never start the new image's seeder
against restored data.
