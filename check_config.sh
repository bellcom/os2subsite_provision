#!/bin/bash
set -o errexit
set -o nounset

# Script that helps os2subsite solution manage local files after
# composer installed/updated os2subsite codebase.

if [ $# -ne 1 ]; then
  echo "ERROR: Usage: $0 <path to local files>"
  exit 10
fi

SCRIPTDIR="$(dirname "$0")"
SOURCE_DIR="$(pwd)/$1"
if [ ! -d "$SOURCE_DIR" ]; then
  echo "ERROR: os2subsite config directory do not exist."
  exit 10
fi
# Declare an array with files to copy.
declare -a FILES=("config.sh" "local_functions.sh")

# Loop through the files and copy them to os2subsite directory.
for i in "${FILES[@]}"
do
  if [ -f "$SOURCE_DIR/$i" ]; then
    cp $SOURCE_DIR/$i $SCRIPTDIR/
  fi
done

if [ ! -f "$SCRIPTDIR"/config.sh ]; then
  echo "ERROR: please create a config.sh file"
  exit 10
fi
