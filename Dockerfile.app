# Dockerfile.app
# Extends the official OpenProject 17-slim image with our custom plugins.
# Build locally / in CI and push to a registry; the 2-vCore server only pulls.
#
#   docker compose build web   (or: docker build -f Dockerfile.app -t openproject-custom:17 .)
#
# The TAG ARG must match docker-compose.yml (default 17-slim).

ARG TAG=17-slim
FROM openproject/openproject:${TAG}

# ── Plugin sources ───────────────────────────────────────────────────────────
# Copy all plugins at once. OP's Gemfile auto-loads /app/Gemfile.plugins, and the
# relative `path:` entries there resolve against /app (so /app/plugins/<dir>).
COPY plugins/        /app/plugins/
COPY Gemfile.plugins /app/Gemfile.plugins

# ── Gem installation ─────────────────────────────────────────────────────────
# The slim image sets bundler `deployment: true` (frozen-equivalent) in
# /app/.bundle/config. Adding path-gems + the omniauth gems changes the dependency
# set, so a deployment/frozen install ABORTS ("the lockfile is frozen"). Unset
# both so bundler can re-resolve and update Gemfile.lock. build-essential is
# installed for any native extensions (ruby-saml/omniauth pull pure-ruby + nokogiri
# which is already present, but keep the toolchain to be safe).
USER root
WORKDIR /app
# Adding our path-gems + omniauth needs a bundler re-resolve, which requires
# deployment/frozen OFF. After re-resolve, runtime bundler "converges" the locked
# specs on boot and calls load_spec_files on EVERY git source — including dev/test
# git gems like `pry` — even though those groups are excluded from loading. So those
# git checkouts must physically EXIST on disk or boot crashes with Bundler::PathError.
# Two things the slim image lacks for that:
#   1. `git` is NOT installed in the runtime image -> bundler can't clone git gems.
#   2. BUNDLE_WITHOUT=development:test skips installing them.
# Fix: install git (+ build-essential for native exts) AND install ALL groups
# (BUNDLE_WITHOUT="") so the dev/test git gems are checked out. Runtime still
# EXCLUDES dev/test from loading via the image's BUNDLE_WITHOUT env.
RUN apt-get update \
    && apt-get install -y --no-install-recommends build-essential git \
    && rm -rf /var/lib/apt/lists/* \
    && bundle config unset --local deployment \
    && bundle config unset --local frozen \
    && bundle config set --local path '/app/vendor/bundle' \
    && BUNDLE_WITHOUT="" bundle install --jobs 4 --retry 3 \
    && chown -R app:app /app/vendor/bundle /app/Gemfile.lock /app/plugins 2>/dev/null || true

# Restore the non-root runtime user from the base image.
USER app

# Entrypoint and CMD are inherited from the base image — no changes needed.
# Plugin DB migrations run via the existing seeder service on `docker compose up`.
