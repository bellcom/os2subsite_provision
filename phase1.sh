#!/bin/bash
set -o errexit
set -o nounset

DEBUG=true

SCRIPTDIR="$(dirname "$0")"

if [ -v USE_ENV_CONFIG ]; then
  echo "Using environment configuration. Make sure that all variables from config.sh are set in .env file of proper environment settings."
else
  if [ -f "$SCRIPTDIR"/config.sh ]; then
    echo "Using configuration from file"
    source "$SCRIPTDIR"/config.sh
  else
    echo "ERROR: please create a config.sh file"
    exit 10
  fi
fi

if [ -f "$SCRIPTDIR"/functions.sh ]; then
  source "$SCRIPTDIR"/functions.sh
else
  echo "ERROR: functions.sh missing"
  exit 10
fi

if [ $# -ne 2 ] && [ $# -ne 3 ]; then
  echo "ERROR: Usage: $0 <sitename> <email>"
  exit 10
fi

SITENAME=$(echo "$1" | tr -d ' ')
USEREMAIL=$(echo "$2" | tr -d ' ')
DBNAME=${SITENAME//\./_}
DBNAME=${DBNAME//\-/_}
VHOST="/etc/apache2/sites-available/$SITENAME.conf"

# only allow root to run this script - because of special sudo rights and permissions
if [[ "$USER" != "root" ]]; then
  echo "ERROR: Run with sudo or as root"
  exit 10
fi

phase_1 $SITENAME

# Print successful status in the end of the line.
echo "complete_status:{\"provisioning_state\": \"phase2\", \"status\": 1}"
