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

if [ $# -ne 1 ]; then
  echo "ERROR: Usage: $0 <sitename>"
  exit 10
fi

SITENAME=$(echo "$1" | tr -d ' ')
DBNAME=${SITENAME//\./_}
DBNAME=${DBNAME//\-/_}
VHOST="/etc/apache2/sites-available/$SITENAME.conf"

# only allow root to run this script - because of special sudo rights and permissions
if [[ "$USER" != "root" ]]; then
  echo "ERROR: Run with sudo or as root"
  exit 10
fi


validate_sitename "$SITENAME"
init "$SITENAME"
delete_vhost
delete_dirs
delete_db "$DBNAME"
# TODO, also remove possible ServerAlias domains from the hosts file? Or do that from web?
remove_from_hosts "$SITENAME"
remove_from_crontab
remove_from_sites "$SITENAME"

# Print successful status in the end of the line.
echo "complete_status:{\"status\": 1}"
