#!/bin/bash

set -e

cluster_name=$1

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source env.sh from the same directory
source "${SCRIPT_DIR}/env.sh" $cluster_name

echo "{\"result\": \"${ALIAS_VERSION}\"}"