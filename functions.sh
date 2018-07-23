debug() {
  if [[ "$DEBUG" == true ]]; then
    echo "DEBUG: $1"
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

check_existence_create() {
  debug "Checking if site already exists ($SITENAME)"
  # Check if site dir already exists
  if [ -d "$MULTISITE/sites/$SITENAME" ]
  then
    echo "ERROR: Sitedir, $MULTISITE/sites/$SITENAME already exists"
    exit 10
  fi

  # Check if site vhost alias already exists
  if [ -f "$VHOST" ]
  then
    echo "ERROR: Vhost, $VHOST already exists"
    exit 10
  fi

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

  # Check if database already exists
  if [ ! -d "$DBDIR/$DBNAME" ]
  then
    echo "ERROR: Database, $DBDIR/$DBNAME doesn't exists"
    exit 10
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
  debug "Creating database ($DBNAME) and database user ($DBUSER)"
  # check for pwgen
  command -v pwgen >/dev/null 2>&1 || { echo >&2 "ERROR: pwgen is required but not installed. Aborting."; exit 20; }
  DBPASS=$(pwgen -s 10 1)
  # this requires a /root/.my.cnf with password set
  /usr/bin/mysql -u root -e "CREATE DATABASE $DBNAME;"
  /usr/bin/mysql -u root -e "GRANT ALL ON $1.* TO $DBUSER@localhost IDENTIFIED BY \"$DBPASS\"";
}

create_dirs() {
  TMPDIR="$TMPDIRBASE/$SITENAME"
  LOGDIR="$LOGDIRBASE/$SITENAME"
  SESSIONDIR="$SESSIONDIRBASE/$SITENAME"
  mkdir -p "$TMPDIR"
  mkdir -p "$LOGDIR"
  mkdir -p "$SESSIONDIR"
}

create_vhost() {
  debug "Adding and enabling $SITENAME vhost"
  cp "$VHOSTTEMPLATE" "/etc/apache2/sites-available/$SITENAME.conf"
  perl -p -i -e "s/\[basedir\]/$BASEDIR/g" "/etc/apache2/sites-available/$SITENAME.conf"
  perl -p -i -e "s/\[domain\]/$SITENAME/g" "/etc/apache2/sites-available/$SITENAME.conf"
  a2ensite "$SITENAME" >/dev/null
  debug "Reloading Apache2"
  /etc/init.d/apache2 reload >/dev/null
}

install_drupal() {
  debug "Installing drupal ($SITENAME)"
  install_drupal$DRUPAL
}

install_drupal7() {
  # Do a drush site install
  /usr/bin/drush -q -y -r $MULTISITE site-install $PROFILE --locale=da --db-url="mysql://$DBUSER:$DBPASS@localhost/$DBNAME" --sites-subdir="$SITENAME" --account-mail="$EMAIL" --site-mail="$EMAIL" --site-name="$SITENAME" --account-pass="$ADMINPASS"

  # Set tmp
  /usr/bin/drush -q -y -r "$MULTISITE" --uri="$SITENAME" vset file_temporary_path "$TMPDIR"

  # Do some drupal setup here. Could also be done in the install profile.
  /usr/bin/drush -q -y -r "$MULTISITE" --uri="$SITENAME" vset user_register 0
  /usr/bin/drush -q -y -r "$MULTISITE" --uri="$SITENAME" vset error_level 1
  /usr/bin/drush -q -y -r "$MULTISITE" --uri="$SITENAME" vset preprocess_css 1
  /usr/bin/drush -q -y -r "$MULTISITE" --uri="$SITENAME" vset preprocess_js 1
  #/usr/bin/drush -q -y -r "$MULTISITE" --uri="$SITENAME" vset cache 1
  /usr/bin/drush -q -y -r "$MULTISITE" --uri="$SITENAME" vset page_cache_maximum_age 10800
  # translation updates - takes a long time
  #/usr/bin/drush -q -y -r "$MULTISITE" --uri="$SITENAME" l10n-update-refresh
  #/usr/bin/drush -q -y -r "$MULTISITE" --uri="$SITENAME" l10n-update
  /usr/bin/drush -q -y -r "$MULTISITE" --uri="$SITENAME" dis update
}

install_drupal8() {
  # Do a drush site install
  /usr/bin/drush -q -y -r $MULTISITE site-install $PROFILE --locale=da --db-url="mysql://$DBUSER:$DBPASS@localhost/$DBNAME" --sites-subdir="$SITENAME" --account-mail="$EMAIL" --site-mail="$EMAIL" --site-name="$SITENAME" --account-pass="$ADMINPASS"

  # Set tmp
  /usr/bin/drush -q -y -r "$MULTISITE" --uri="$SITENAME" config-set system.file path.temporary "$TMPDIR"

  # Do some drupal setup here. Could also be done in the install profile.
  /usr/bin/drush -q -y -r "$MULTISITE" --uri="$SITENAME" cset user.settings register admin_only
  /usr/bin/drush -q -y -r "$MULTISITE" --uri="$SITENAME" cset system.logging error_level some
  /usr/bin/drush -q -y -r "$MULTISITE" --uri="$SITENAME" config-set system.performance css.preprocess 1
  /usr/bin/drush -q -y -r "$MULTISITE" --uri="$SITENAME" config-set system.performance js.preprocess 1
  /usr/bin/drush -q -y -r "$MULTISITE" --uri="$SITENAME" config-set system.performance cache.max.age 10800
  /usr/bin/drush -q -y -r "$MULTISITE" --uri="$SITENAME" pm:uninstall update
}

set_permissions() {
  debug "Setting correct permissions"

  # this is needed to trigger tmp file creation
  wget -q $SITENAME -O /dev/null
  /bin/chgrp -R www-data "$MULTISITE/sites/$SITENAME"
  /bin/chmod -R g+rwX "$MULTISITE/sites/$SITENAME"
  /bin/chmod g-w "$MULTISITE/sites/$SITENAME" "$MULTISITE/sites/$SITENAME/settings.php"
  /bin/chown -R www-data "$TMPDIR"
  /bin/chmod -R g+rwX "$TMPDIR"
}

add_to_crontab() {
  debug "Adding Drupal cron.php to www-data crontab"
  # if shuf is available, then run cron at random minutes
  if [ -x "/usr/bin/shuf" ]; then
    CRONMINUTE=$(shuf -i 0-59 -n 1)
  else
    CRONMINUTE=0
  fi
  get_cron_key$DRUPAL
}

set_crontab7() {
  CRONKEY=$(/usr/bin/drush -r "$MULTISITE" --uri="$SITENAME" vget cron_key | cut -d \' -f 2)
  CRONLINE="$CRONMINUTE */2 * * * /usr/bin/wget -O - -q -t 1 http://$SITENAME/cron.php?cron_key=$CRONKEY"
  (/usr/bin/crontab -u www-data -l; echo "$CRONLINE") | /usr/bin/crontab -u www-data -
}

set_crontab8() {
  debug "@TODO set_crontab8"
}

mail_status() {
  debug "Sending statusmail ($SITENAME)"
}

add_subsiteadmin() {
  debug "Create subsiteadmin user with email ($USEREMAIL)"
  # This function compatible with Drupal 7/8
  # Create user with email specified in subsitecreator.
  /usr/bin/drush -q -y -r "$MULTISITE" --uri="$SITENAME" user-create subsiteadmin --mail="$USEREMAIL"
  # Add the role "Administrator"
  /usr/bin/drush -q -y -r "$MULTISITE" --uri="$SITENAME" user-add-role subsiteadmin subsiteadmin
  # Send single-use login link.
  /usr/bin/drush -q -y -r "$MULTISITE" --uri="$SITENAME" ev "_user_mail_notify('password_reset', user_load_by_mail('$USEREMAIL'));"
}

delete_vhost() {
  debug "Disabling and deleting $SITENAME vhost"
  a2dissite "$SITENAME" >/dev/null
  rm -f "/etc/apache2/sites-available/$SITENAME.conf"
  debug "Reloading Apache2"
  /etc/init.d/apache2 reload >/dev/null
}

delete_db() {
  if [ -z "$1" ]; then
    echo "ERROR: delete_db called without an argument"
    exit 10
  fi
  local DBNAME=$1
  DBUSER=$(echo "$DBNAME" | cut -c 1-16)
  debug "Backing up, then deleting database ($DBNAME) and database user ($DBUSER)"
  # backup first, just in case
  /usr/local/sbin/mysql_backup.sh "$DBNAME"
  /usr/bin/mysql -u root -e "DROP DATABASE $DBNAME;"
  /usr/bin/mysql -u root -e "DROP USER $DBUSER@localhost";
}

delete_dirs() {
  TMPDIR="$TMPDIRBASE/$SITENAME"
  LOGDIR="$LOGDIRBASE/$SITENAME"
  SESSIONDIR="$SESSIONDIRBASE/$SITENAME"
  SITEDIR="$MULTISITE/sites/$SITENAME"
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
}

remove_from_crontab() {
  debug "Removing Drupal cron.php from www-data crontab ($SITENAME)"
  crontab -u www-data -l | sed "/$SITENAME\/cron.php/d" | crontab -u www-data -
}

add_to_vhost() {
  debug "Adding $NEWDOMAIN to vhost for $SITENAME"
  /usr/bin/perl -p -i -e "s/ServerName $SITENAME/ServerName $SITENAME\n    ServerAlias $NEWDOMAIN/g" "$VHOST"
  debug "Reloading Apache2"
  /etc/init.d/apache2 reload >/dev/null
}

add_to_sites() {
  debug "Adding $NEWDOMAIN to sites.php"
  echo "\$sites['$NEWDOMAIN'] = '$SITENAME';" >> $SITESFILE
}

remove_from_vhost() {
  debug "Removing $REMOVEDOMAIN from vhost for $SITENAME"
  sed -i "/ServerAlias\ $REMOVEDOMAIN\$/d" "$VHOST"
  debug "Reloading Apache2"
  /etc/init.d/apache2 reload >/dev/null
}
