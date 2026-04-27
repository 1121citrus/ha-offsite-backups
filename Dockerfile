# syntax=docker/dockerfile:1

# Rename Home Assistant backups to ISO-datetime order and sync them to S3.
# Copyright (C) 2025 James Hanlon [mailto:jim@hanlonsoftware.com]
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

ARG BASE_IMAGE=1121citrus/aws-backup-base:latest
ARG PYTHON_VERSION=3.12
ARG VERSION=dev

# hadolint ignore=DL3006
FROM ${BASE_IMAGE}

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Re-declare build args after FROM so they are visible in the build stage.
ARG PYTHON_VERSION
ENV PYTHON_VERSION=${PYTHON_VERSION}

ARG VERSION
ENV VERSION=${VERSION}

ARG HA_OFFSITE_BACKUPS_VERSION
ENV HA_OFFSITE_BACKUPS_VERSION=${HA_OFFSITE_BACKUPS_VERSION}

ARG GIT_COMMIT=unknown
ARG BUILD_DATE=unknown

LABEL org.opencontainers.image.title="ha-offsite-backups" \
      org.opencontainers.image.description="Rename Home Assistant backups and copy them off site to AWS S3" \
      org.opencontainers.image.url="https://github.com/1121citrus/ha-offsite-backups" \
      org.opencontainers.image.source="https://github.com/1121citrus/ha-offsite-backups" \
      org.opencontainers.image.vendor="1121 Citrus Avenue" \
      org.opencontainers.image.authors="James Hanlon <jim@hanlonsoftware.com>" \
      org.opencontainers.image.licenses="AGPL-3.0-or-later" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.revision="${GIT_COMMIT}" \
      org.opencontainers.image.created="${BUILD_DATE}"

COPY requirements.txt /tmp/
# hadolint ignore=DL3041
RUN echo "[INFO] start installing ha-offsite-backups" \
    && dnf install -y --quiet \
            findutils \
            python${PYTHON_VERSION} \
            python${PYTHON_VERSION}-pip \
            tzdata \
    && echo "[INFO] patching vulnerable transitive dependencies" \
    && python${PYTHON_VERSION} -m pip install --no-cache-dir -r /tmp/requirements.txt \
    && rm /tmp/requirements.txt \
    && install -d -m 755 \
            /usr/local/share/ha-offsite-backups \
            /var/log/ha-offsite-backups \
    && touch /var/log/ha-offsite-backups/ha-offsite-backups.log \
    && printf '%s\n' "${VERSION}" \
            > /usr/local/share/ha-offsite-backups/version \
    && dnf clean all \
    && rm -rf /var/cache/dnf \
    && echo "[INFO] completed installing ha-offsite-backups"

# Create a non-privileged user and pre-create the crontabs directory so the
# service user can write its own crontab without root access.
ARG UID=10001
RUN useradd \
        --create-home --shell /sbin/nologin \
        --uid "${UID}" ha-offsite-backups \
    && install -d -m 755 /var/spool/cron \
    && install -d -m 0755 -o ha-offsite-backups /var/spool/cron/crontabs \
    && chown ha-offsite-backups \
           /var/log/ha-offsite-backups \
           /var/log/ha-offsite-backups/ha-offsite-backups.log

COPY --chmod=644 ./src/include/common-functions /usr/local/include/
COPY --chmod=755 ./src/ha-offsite-backups ./src/healthcheck ./src/startup /usr/local/bin/
RUN mkdir -p /usr/local/share/ha-offsite-backups
COPY --chmod=644 version.txt /usr/local/share/ha-offsite-backups/version

USER ha-offsite-backups

HEALTHCHECK --interval=60s --timeout=5s --retries=3 CMD ["/usr/local/bin/healthcheck"]

WORKDIR /

ENTRYPOINT ["/usr/local/bin/ha-offsite-backups"]
