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

FROM 1121citrus/ha-bash-base:latest

COPY --chmod=755 ./src/ha-offsite-backups ./src/healthcheck ./src/startup /usr/local/bin/

# HEALTHCHECK --interval=30s --timeout=3s --retries=3 CMD /usr/local/bin/healthcheck

CMD [ "/usr/local/bin/startup" ]


