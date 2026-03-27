# syntax=docker/dockerfile:1

# Yet another version of `rotate-backups` but this time applied to an AWS S3 backup archive bucket.
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

ARG PYTHON_VERSION=3.12
ARG ALPINE_VERSION=3.22
ARG VERSION=dev

FROM python:${PYTHON_VERSION}-alpine${ALPINE_VERSION}

# Re-declare build args after FROM so they are visible in the build stage.
ARG PYTHON_VERSION
ENV PYTHON_VERSION=${PYTHON_VERSION}

ARG ALPINE_VERSION
ENV ALPINE_VERSION=${ALPINE_VERSION}

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
RUN apk add --no-cache --no-interactive --upgrade \
        aws-cli=2.27.25-r0 \
        bash=5.2.37-r0 \
        coreutils=9.7-r1 \
        findutils=4.10.0-r0 \
        py3-cryptography=44.0.3-r0 \
        py3-pip=25.1.1-r0 \
        py3-urllib3=1.26.20-r1 \
        tzdata=2026a-r0 \
    && pip3 install --no-cache-dir --break-system-packages \
        -r /tmp/requirements.txt \
    && rm /tmp/requirements.txt \
    && apk del py3-pip \
    && mkdir -p /usr/local/include /usr/local/bin

# Create a non-privileged user and pre-create the crontabs directory so the
# service user can write its own crontab without root access.
ARG UID=10001
RUN adduser \
        --disabled-password --gecos "" --shell "/sbin/nologin" \
        --uid "${UID}" ha-offsite-backups \
    && install -d -m 0755 -o ha-offsite-backups /var/spool/cron/crontabs

COPY --chmod=644 ./src/include/common-functions /usr/local/include/
COPY --chmod=755 ./src/ha-offsite-backups ./src/healthcheck ./src/startup /usr/local/bin/

USER ha-offsite-backups

HEALTHCHECK --interval=60s --timeout=5s --retries=3 CMD ["/usr/local/bin/healthcheck"]

WORKDIR /

ENTRYPOINT ["/usr/local/bin/ha-offsite-backups"]
