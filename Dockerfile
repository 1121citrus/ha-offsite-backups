# syntax=docker/dockerfile:1

# An application specific service to rename Home Assistant backups and copy them off site.
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

FROM alpine:3.22

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
        cryptography==46.0.5 \
        urllib3==2.6.3 \
        zipp==3.23.0 \
    && apk del py3-pip \
    && mkdir -p /usr/local/include /usr/local/bin

COPY --chmod=644 ./src/include/common-functions /usr/local/include/
COPY --chmod=755 ./src/ha-offsite-backups ./src/healthcheck ./src/startup /usr/local/bin/

HEALTHCHECK --interval=60s --timeout=5s --retries=3 CMD ["/usr/local/bin/healthcheck"]

CMD [ "/usr/local/bin/startup" ]
