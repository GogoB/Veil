#!/bin/sh
set -eu

VeilServer migrate --yes
exec VeilServer serve --hostname 0.0.0.0 --port 8080
