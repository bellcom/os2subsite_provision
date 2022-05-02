if [ -f "$SCRIPTDIR"/local_function.sh ]; then
  source "$SCRIPTDIR"/local_function.sh
fi

debug() {
  if [[ "$DEBUG" == true ]]; then
    echo "DEBUG: $1"
  fi
}

init() {
  local SITENAME="$1"
  TMPDIR="$TMPDIRBASE/$SITENAME"
  LOGDIR="$LOGDIRBASE/$SITENAME"
  SESSIONDIR="$SESSIONDIRBASE/$SITENAME"
  SITEDIR="$MULTISITE/sites/$SITENAME"
}

# Runs first phase of subsite creation.
phase_1 () {
  init "$SITENAME"
  validate_sitename "$SITENAME"
  validate_email "$USEREMAIL"
  check_existence_create "$SITENAME"
  create_db "$DBNAME"
  create_dirs
  create_vhost
  add_to_hosts "$SITENAME"
  create_creadentials_source "$SITENAME"
}

# Pick ups credentials from source file and continuing subsite creation.
phase_2 () {
  read_creadentials_source "$SITENAME"
  init "$SITENAME"
  install_drupal
  set_permissions
  add_to_crontab
  add_subsiteadmin
}

# Creates credentials source file for external provisioning usage.
create_creadentials_source () {
  local SITENAME="$1"
  if [ -v EXTERNAL_DB_PROVISIONING ]
  then
    # Checking if credentials sources path is defined
    check SOURCES_PATH_EXISTS
    echo "SITENAME=${SITENAME}
DBNAME=${DBNAME}
DBUSER=${DBUSER}
DBPASS=${DBPASS}" > $PROVISIONING_SOURCES_PATH/$SITENAME
    chown $APACHEUSER:$APACHEUSER $PROVISIONING_SOURCES_PATH/$SITENAME
  else
    echo "NOTICE: Internal DB provisioning. No need for credentials sources file."
  fi
}

# Read credentials from source file.
read_creadentials_source () {
  local SITENAME="$1"
  if [ -v EXTERNAL_DB_PROVISIONING ]
  then
    # Checking if credentials sources path is defined
    check CREDENTIALS_SOURCES
    source $PROVISIONING_SOURCES_PATH/$SITENAME
  else
    echo "NOTICE: Internal DB provisioning. No need to read credentials sources file."
  fi
}

validate_sitename() {
  local SITENAME="$1"
  debug "Checking site name ($SITENAME)"
  if [[ ! $SITENAME =~ (([a-zA-Z](-?[a-zA-Z0-9])*)\.)*[a-zA-Z](-?[a-zA-Z0-9])+\.[a-zA-Z]{2,}$ ]]; then
    echo "ERROR: Domain not valid"
    exit 10
  fi
}

validate_domainname() {
  local DOMAIN="$1"
  debug "Checking domain name ($DOMAIN)"
  if [[ ! $DOMAIN =~ (([a-zA-Z](-?[a-zA-Z0-9])*)\.)*[a-zA-Z](-?[a-zA-Z0-9])+\.[a-zA-Z]{2,}$ ]]; then
    echo "ERROR: Domain not valid"
    exit 10
  fi
}

validate_email() {
  local EMAIL="$1"
  debug "Checking email address ($EMAIL)"
  if [[ ! "$EMAIL" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,4}$ ]]
  then
    echo "ERROR: Email $EMAIL not valid"
    exit 10
  fi
}

# Generic check function.
# Example of using check [check_type]
check() {
  local CHECK_TYPE="$1"

  case $CHECK_TYPE in

    SITE_DIR_EXISTS)
      if [ -d "$MULTISITE/sites/$SITENAME" ]
      then
        echo "Sitedir, $MULTISITE/sites/$SITENAME already exists"
        exit 10
      fi
      ;;

    VHOST_EXISTS)
      if [ -f "$VHOST" ]
      then
        echo "ERROR: Vhost, $VHOST already exists"
        exit 10
      fi
      ;;

    DB_CONNECTION)
      ERROR=$(mysql -u$DBUSER -p$DBPASS $DBNAME -h$DBHOST -e ";")
      if ! [ -z "$ERROR" ]
      then
        echo $ERROR
        exit 10
      fi
      ;;

    SOURCES_PATH_EXISTS)
      if ! [ -v PROVISIONING_SOURCES_PATH ]
      then
        echo "ERROR: Credentials sources directory is not defined"
        exit 10
      else
        mkdir -p $PROVISIONING_SOURCES_PATH
        if ! [ -d "$PROVISIONING_SOURCES_PATH" ]
        then
          echo "ERROR: Credentials sources directory doesn't exist and can not be created."
          exit 10
        fi
      fi
      ;;

    CREDENTIALS_SOURCES)
      check SOURCES_PATH_EXISTS
      if ! [ -f "$PROVISIONING_SOURCES_PATH/$SITENAME" ]
      then
        echo "ERROR: Credentials sources file is not exists"
        exit 10
      fi
      ;;

  esac

}

check_existence_create() {
  debug "Checking if site already exists ($SITENAME)"
  # Check if site dir already exists
  check SITE_DIR_EXISTS

  # Check if site vhost alias already exists
  check VHOST_EXISTS

  if  [ -v EXTERNAL_DB_PROVISIONING ]
  then
    echo "NOTICE: External DB provisioning is used. Can not check if database or database user exists."
  else
    # Check if database already exists
    if [ -d "$DBDIR/$DBNAME" ]
    then
      echo "ERROR: Database, $DBDIR/$DBNAME already exists"
      exit 10
    fi

    # Check if database user already exists
    local DBNAME=${SITENAME//\./_}
    local DBNAME=${DBNAME//\-/_}
    DBUSER=$(echo "$DBNAME" | cut -c 1-16)
    EXISTS=$(mysql -ss mysql -e "SELECT EXISTS(SELECT 1 FROM mysql.user WHERE user = \"$DBUSER\");")

    if [ $EXISTS -ne 0 ]
    then
      echo "ERROR: Database user, $DBUSER already exists"
      exit 10
    fi
  fi
}

check_existence_delete() {
  debug "Checking if site exists ($SITENAME)"
  # Check if site dir already exists
  if [ ! -d "$MULTISITE/sites/$SITENAME" ]
  then
    echo "ERROR: Sitedir, $MULTISITE/sites/$SITENAME doesn't exists"
    exit 10
  fi

  # Check if site vhost alias already exists
  if [ ! -f "$VHOST" ]
  then
    echo "ERROR: Vhost, $VHOST doesn't exists"
    exit 10
  fi

  if  [ -v EXTERNAL_DB_PROVISIONING ]
  then
    echo "NOTICE: External DB provisioning is used. Can not check if database or database user exists."
  else
    # Check if database already exists
    if [ ! -d "$DBDIR/$DBNAME" ]
    then
      echo "ERROR: Database, $DBDIR/$DBNAME doesn't exists"
      exit 10
    fi
  fi
}

check_existence_add() {
  debug "Checking if site exists ($SITENAME)"
  # Check if site dir already exists
  if [ ! -d "$MULTISITE/sites/$SITENAME" ]
  then
    echo "ERROR: Sitedir, $MULTISITE/sites/$SITENAME doesn't exists"
    exit 10
  fi

  # Check if site vhost exists
  if [ ! -f "$VHOST" ]
  then
    echo "ERROR: Vhost, $VHOST doesn't exists"
    exit 10
  fi

  debug "Checking if the new domain already exists ($NEWDOMAIN)"
  # Check if new domain already exists
  egrep -q "ServerName $NEWDOMAIN" /etc/apache2/sites-enabled/* && EXISTSSERVERNAME=$? || EXISTSSERVERNAME=$?
  egrep -q "ServerAlias $NEWDOMAIN" /etc/apache2/sites-enabled/* && EXISTSSERVERALIAS=$? || EXISTSSERVERALIAS=$?
  if [[ "$EXISTSSERVERALIAS" -eq 0 || $EXISTSSERVERNAME -eq 0 ]]
  then
    echo "ERROR: Domain, $NEWDOMAIN already exists in a vhost"
    exit 10
  fi
}


check_existence_remove() {
  debug "Checking if site exists ($SITENAME)"
  # Check if site dir already exists
  if [ ! -d "$MULTISITE/sites/$SITENAME" ]
  then
    echo "ERROR: Sitedir, $MULTISITE/sites/$SITENAME doesn't exists"
    exit 10
  fi

  # Check if site vhost exists
  if [ ! -f "$VHOST" ]
  then
    echo "ERROR: Vhost, $VHOST doesn't exists"
    exit 10
  fi

  debug "Checking if the domain exists ($REMOVEDOMAIN)"
  # Check if new domain exists
  EXISTSSERVERALIAS=$(egrep -c "ServerAlias $REMOVEDOMAIN" "/etc/apache2/sites-enabled/$SITENAME" || true)
  if [[ "$EXISTSSERVERALIAS" -eq 0 ]]
  then
    echo "ERROR: Vhost, $REMOVEDOMAIN doesn't exists in the vhost for $SITENAME"
    exit 10
  fi
}

add_to_hosts() {
  local DOMAIN="$1"
  debug "Adding $DOMAIN to /etc/hosts"
  echo "$SERVERIP $DOMAIN" >> /etc/hosts
}

remove_from_hosts() {
  local DOMAIN="$1"
# TODO, also remove all ServerAlias lines?
  debug "Removing $DOMAIN from /etc/hosts"
  sed -i "/$SERVERIP $DOMAIN/d" /etc/hosts
}

remove_from_sites() {
  local DOMAIN="$1"
  debug "Removing $DOMAIN from $SITESFILE"
  sed -i "/'$DOMAIN'/d" $SITESFILE
}

create_db() {
  local DBNAME=$1
  DBUSER=$(echo "$DBNAME" | cut -c 1-16)
  # check for pwgen
  command -v pwgen >/dev/null 2>&1 || { echo >&2 "ERROR: pwgen is required but not installed. Aborting."; exit 20; }
  DBPASS=$(pwgen -s 10 1)

  if  [ -v EXTERNAL_DB_PROVISIONING ]
  then
    echo "NOTICE: External DB provisioning is used. The file with DB credentials would be created.."
  else
    debug "Creating database ($DBNAME) and database user ($DBUSER)"
    # this requires a /root/.my.cnf with password set
    /usr/bin/mysql -u root -e "CREATE DATABASE $DBNAME;"
    /usr/bin/mysql -u root -e "GRANT ALL ON $1.* TO $DBUSER@localhost IDENTIFIED BY \"$DBPASS\"";
  fi
}

create_dirs() {
  debug "Creating dirs"
  mkdir -p "$TMPDIR"
  mkdir -p "$LOGDIR"
  mkdir -p "$SESSIONDIR"

  if [ -n "$(type -t ${FUNCNAME[0]}_local)" ] && [ "$(type -t  ${FUNCNAME[0]}_local)" = function ]; then
   ${FUNCNAME[0]}_local
  fi
}

create_vhost() {
  debug "Adding and enabling $SITENAME vhost"
  cp "$VHOSTTEMPLATE" "/etc/apache2/sites-available/$SITENAME.conf"
  perl -p -i -e "s~\[basedir\]~$BASEDIR~g" "/etc/apache2/sites-available/$SITENAME.conf"
  perl -p -i -e "s/\[domain\]/$SITENAME/g" "/etc/apache2/sites-available/$SITENAME.conf"
  #a2ensite "$SITENAME" >/dev/null
  ln -s /etc/apache2/sites-available/$SITENAME.conf /etc/apache2/sites-enabled/$SITENAME.conf
  debug "Reloading Apache2..."
  if [ -f /etc/init.d/apache2 ]; then
    /etc/init.d/apache2 reload >/dev/null
  else
    echo "apachectl graceful"
  fi

  debug "Done!"
}

install_drupal() {
  debug "Installing drupal ($SITENAME)"
  install_drupal$DRUPAL
}

install_drupal7() {
  # Do a drush site install
  $DRUSH -q -y -r $MULTISITE site-install $PROFILE --locale=da --db-url="mysql://$DBUSER:$DBPASS@$DBHOST/$DBNAME" --sites-subdir="$SITENAME" --account-mail="$EMAIL" --site-mail="$EMAIL" --site-name="$SITENAME" --account-pass="$ADMINPASS"

  # Set tmp
  $DRUSH -q -y -r "$MULTISITE" --uri="$SITENAME" vset file_temporary_path "$TMPDIR"

  # Do some drupal setup here. Could also be done in the install profile.
  $DRUSH -q -y -r "$MULTISITE" --uri="$SITENAME" vset user_register 0
  $DRUSH -q -y -r "$MULTISITE" --uri="$SITENAME" vset error_level 1
  $DRUSH -q -y -r "$MULTISITE" --uri="$SITENAME" vset preprocess_css 1
  $DRUSH -q -y -r "$MULTISITE" --uri="$SITENAME" vset preprocess_js 1
  #$DRUSH -q -y -r "$MULTISITE" --uri="$SITENAME" vset cache 1
  $DRUSH -q -y -r "$MULTISITE" --uri="$SITENAME" vset page_cache_maximum_age 10800
  # translation updates - takes a long time
  #$DRUSH -q -y -r "$MULTISITE" --uri="$SITENAME" l10n-update-refresh
  #$DRUSH -q -y -r "$MULTISITE" --uri="$SITENAME" l10n-update
  $DRUSH -q -y -r "$MULTISITE" --uri="$SITENAME" dis update

  if [ -n "$(type -t ${FUNCNAME[0]}_local)" ] && [ "$(type -t  ${FUNCNAME[0]}_local)" = function ]; then
    ${FUNCNAME[0]}_local
  fi
}

install_drupal8() {
  debug "Checking db connection before staring installation process."
  check DB_CONNECTION

  debug "Starting install Drupal"
  # Preparing site folder
  mkdir -p "$MULTISITE/sites/$SITENAME"
  cp $MULTISITE/sites/default/default.settings.php  $MULTISITE/sites/$SITENAME/settings.php
  if [ $(echo ${PROFILE} | cut -d"=" -f1) == '--existing-config' ]; then
    CONFIG_DIR=$(echo ${PROFILE} | cut -d"=" -f2)
    PROFILE=$(echo ${PROFILE} | cut -d"=" -f1)
  else
    CONFIG_DIR=$BASEDIR/config/$SITENAME/sync
    mkdir -p $CONFIG_DIR
  fi

  echo "\$settings['config_sync_directory'] = \"$CONFIG_DIR\";" >> $MULTISITE/sites/$SITENAME/settings.php
  echo "\$settings['file_temp_path'] = \"$TMPDIR\";" >> $MULTISITE/sites/$SITENAME/settings.php

  # Do a drush site install
  $DRUSH -y -r $MULTISITE site-install $PROFILE --locale=da --db-url="mysql://$DBUSER:$DBPASS@$DBHOST/$DBNAME" --sites-subdir="$SITENAME" --account-mail="$EMAIL" --site-mail="$EMAIL" --site-name="$SITENAME" --account-pass="$ADMINPASS" $INSTALL_OPTIONS
  debug "Drupal install phase succesfuly finished"

  # Set tmp
  $DRUSH -y -r "$MULTISITE" --uri="$SITENAME" config-set system.file path.temporary "$TMPDIR"

  # Do some drupal setup here. Could also be done in the install profile.
  $DRUSH -y -r "$MULTISITE" --uri="$SITENAME" cset user.settings register admin_only
  $DRUSH -y -r "$MULTISITE" --uri="$SITENAME" cset system.logging error_level some
  $DRUSH -y -r "$MULTISITE" --uri="$SITENAME" config-set system.performance css.preprocess 1
  $DRUSH -y -r "$MULTISITE" --uri="$SITENAME" config-set system.performance js.preprocess 1
  $DRUSH -y -r "$MULTISITE" --uri="$SITENAME" config-set system.performance cache.max.age 10800
  $DRUSH -y -r "$MULTISITE" --uri="$SITENAME" pm:uninstall update

  debug "Update translations"
  $DRUSH -y -r "$MULTISITE" --uri="$SITENAME" locale-check
  $DRUSH -y -r "$MULTISITE" --uri="$SITENAME" locale-update

  if [ -n "$(type -t ${FUNCNAME[0]}_local)" ] && [ "$(type -t  ${FUNCNAME[0]}_local)" = function ]; then
    ${FUNCNAME[0]}_local
  fi
}

set_permissions() {
  debug "Setting correct permissions"
  /bin/chgrp -R $APACHEUSER "$MULTISITE/sites/$SITENAME"
  /bin/chmod -R g+rwX "$MULTISITE/sites/$SITENAME"
  /bin/chmod g-w "$MULTISITE/sites/$SITENAME" "$MULTISITE/sites/$SITENAME/settings.php"
  /bin/chown -R $APACHEUSER "$TMPDIR"
  /bin/chmod -R g+rwX "$TMPDIR"
  /bin/chown -R $APACHEUSER "$BASEDIR/config"
  /bin/chmod -R g+rwX "$BASEDIR/config"

  if [ -n "$(type -t ${FUNCNAME[0]}_local)" ] && [ "$(type -t  ${FUNCNAME[0]}_local)" = function ]; then
    ${FUNCNAME[0]}_local
  fi
}

add_to_crontab() {
  debug "Adding Drupal cron.php to $APACHEUSER crontab"
  # if shuf is available, then run cron at random minutes
  if [ -x "/usr/bin/shuf" ]; then
    CRONMINUTE=$(shuf -i 0-59 -n 1)
  else
    CRONMINUTE=0
  fi
  set_crontab$DRUPAL
}

set_crontab7() {
  CRONKEY=$($DRUSH -r "$MULTISITE" --uri="$SITENAME" vget cron_key | cut -d \' -f 2)
  CRONLINE="$CRONMINUTE */2 * * * /usr/bin/wget -O - -q -t 1 http://$SITENAME/cron.php?cron_key=$CRONKEY"
  if [ -n "$(type -t ${FUNCNAME[0]}_local)" ] && [ "$(type -t  ${FUNCNAME[0]}_local)" = function ]; then
    ${FUNCNAME[0]}_local
  fi
  (/usr/bin/crontab -u $APACHEUSER -l; echo "$CRONLINE") | /usr/bin/crontab -u $APACHEUSER -
}

set_crontab8() {
  CRONLINE="$CRONMINUTE */2 * * * $DRUSH --root=$MULTISITE --uri=$SITENAME cron -q"
  if [ -n "$(type -t ${FUNCNAME[0]}_local)" ] && [ "$(type -t  ${FUNCNAME[0]}_local)" = function ]; then
    ${FUNCNAME[0]}_local
  fi
  (/usr/bin/crontab -u $APACHEUSER -l; echo "$CRONLINE") | /usr/bin/crontab -u $APACHEUSER -
}

mail_status() {
  debug "Sending statusmail ($SITENAME)"
}

add_subsiteadmin() {
  debug "Create subsiteadmin user with email ($USEREMAIL)"
  # This function compatible with Drupal 7/8
  # Create user with email specified in subsitecreator.
  $DRUSH -y -r "$MULTISITE" --uri="$SITENAME" user-create subsiteadmin --mail="$USEREMAIL"
  # Add the role "subsiteadmin"
  if [ -z "$(${DRUSH} -r "$MULTISITE" --uri="$SITENAME" role:list | grep subsiteadmin)" ]; then
    debug "Role subsiteadmin is not created yet. You have to create it manually."
  else
    debug "Add the role subsiteadmin"
    $DRUSH -y -r "$MULTISITE" --uri="$SITENAME" user-add-role subsiteadmin subsiteadmin
  fi
  # Send single-use login link.
  $DRUSH -y -r "$MULTISITE" --uri="$SITENAME" ev "_user_mail_notify('password_reset', user_load_by_mail('$USEREMAIL'));"

  if [ -n "$(type -t ${FUNCNAME[0]}_local)" ] && [ "$(type -t  ${FUNCNAME[0]}_local)" = function ]; then
    ${FUNCNAME[0]}_local
  fi
}

delete_vhost() {
  debug "Disabling and deleting $SITENAME vhost files if present"
  if [ -f "/etc/apache2/sites-enabled/$SITENAME.conf" ]
  then
    rm -f "/etc/apache2/sites-enabled/$SITENAME.conf"
  fi

  if [ -f "/etc/apache2/sites-available/$SITENAME.conf" ]
  then
    rm -f "/etc/apache2/sites-available/$SITENAME.conf"
  fi

  debug "Reloading Apache2"
  if [ -f /etc/init.d/apache2 ]; then
    /etc/init.d/apache2 reload >/dev/null
  else
    echo "apachectl graceful"
  fi
}

delete_db() {
  if [ -z "$1" ]; then
    echo "ERROR: delete_db called without an argument"
    exit 10
  fi

  if  [ -v EXTERNAL_DB_PROVISIONING ]
  then
    echo "NOTICE: External DB provisioning is used. Can not check if database or database user exists."
  else
    local DBNAME=$1
    DBUSER=$(echo "$DBNAME" | cut -c 1-16)
    debug "Backing up, then deleting database ($DBNAME) and database user ($DBUSER)"
    # backup first, just in case
    #/usr/local/sbin/mysql_backup.sh "$DBNAME"
    /usr/bin/mysql -u root -e "DROP DATABASE $DBNAME;"
    /usr/bin/mysql -u root -e "DROP USER $DBUSER@$DBHOST";
  fi
}

delete_dirs() {
  if [ -d "$TMPDIR" ]; then
    rm -rf "$TMPDIR"
  fi
  if [ -d "$LOGDIR" ]; then
    rm -rf "$LOGDIR"
  fi
  if [ -d "$SESSIONDIR" ]; then
    rm -rf "$SESSIONDIR"
  fi
  if [ -d "$SITEDIR" ]; then
    rm -rf "$SITEDIR"
  fi
  if [ -d "$BASEDIR/config/$SITENAME" ]; then
    rm -rf "$BASEDIR/config/$SITENAME"
  fi

  if [ -n "$(type -t ${FUNCNAME[0]}_local)" ] && [ "$(type -t  ${FUNCNAME[0]}_local)" = function ]; then
    ${FUNCNAME[0]}_local
  fi
}

remove_from_crontab() {
  debug "Removing Drupal cron.php from $APACHEUSER crontab ($SITENAME) if present"
  crontab -u $APACHEUSER -l | sed "/$SITENAME/d" | crontab -u $APACHEUSER -
}

add_to_vhost() {
  debug "Adding $NEWDOMAIN to vhost for $SITENAME"
  /usr/bin/perl -p -i -e "s/ServerName $SITENAME/ServerName $SITENAME\n    ServerAlias $NEWDOMAIN/g" "$VHOST"
  debug "Reloading Apache2"
  if [ -f /etc/init.d/apache2 ]; then
    /etc/init.d/apache2 reload >/dev/null
  else
    echo "apachectl graceful"
  fi
}

add_to_sites() {
  debug "Adding $NEWDOMAIN to sites.php"
  echo "\$sites['$NEWDOMAIN'] = '$SITENAME';" >> $SITESFILE

  if [ -n "$(type -t ${FUNCNAME[0]}_local)" ] && [ "$(type -t  ${FUNCNAME[0]}_local)" = function ]; then
    ${FUNCNAME[0]}_local
  fi
}

remove_from_vhost() {
  debug "Removing $REMOVEDOMAIN from vhost for $SITENAME"
  sed -i "/ServerAlias\ $REMOVEDOMAIN\$/d" "$VHOST"
  debug "Reloading Apache2"
  if [ -f /etc/init.d/apache2 ]; then
    /etc/init.d/apache2 reload >/dev/null
  else
    apachectl graceful
  fi
}
