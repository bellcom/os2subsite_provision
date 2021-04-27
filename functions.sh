if [ -f "$SCRIPTDIR"/local_function.sh ]; then
	source "$SCRIPTDIR"/local_function.sh
fi

MYSQL_ROOT="mysql -h$DBHOST"

if [ -z "${DB_ROOT_PASSWORD+x}" ]; then
  echo "Using mysql connection without password"
else
  if [ -z "${DB_ROOT_USER+x}" ]; then
    echo "Using 'root' as mysql user for db connection"
    DB_ROOT_USER=root
  fi
  MYSQL_ROOT="$MYSQL_ROOT -u$DB_ROOT_USER -p$DB_ROOT_PASSWORD"
fi

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
	if [[ ! "$EMAIL" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,4}$ ]]; then
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
  local DBNAME=${SITENAME//\./_}
  local DBNAME=${DBNAME//\-/_}
  EXISTS=$(mysql -ss $MYSQL_ROOT -e "SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA  WHERE SCHEMA_NAME = \"$DBNAME\";")
  if [ -n "$EXISTS" ]
  then
    echo "ERROR: Database, $DBNAME already exists"
    exit 10
  fi

  # Check if database user already exists
  local DBNAME=${SITENAME//\./_}
  local DBNAME=${DBNAME//\-/_}
  DBUSER=$(echo "$DBNAME" | cut -c 1-16)
  EXISTS=$(mysql -ss $MYSQL_ROOT -e "SELECT EXISTS(SELECT 1 FROM mysql.user WHERE user = \"$DBUSER\");")

  if [ -n "$EXISTS" ]
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
  EXISTS=$(mysql -ss $MYSQL_ROOT -e "SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA  WHERE SCHEMA_NAME = \"$DBNAME\";")
  if [ -z "$EXISTS" ]
  then
    echo "ERROR: Database, $DBNAME doesn't exists"
    exit 10
  fi
}

check_existence_add() {
	debug "Checking if site exists ($SITENAME)"
	# Check if site dir already exists
	if [ ! -d "$MULTISITE/sites/$SITENAME" ]; then
		echo "ERROR: Sitedir, $MULTISITE/sites/$SITENAME doesn't exists"
		exit 10
	fi

	# Check if site vhost exists
	if [ ! -f "$VHOST" ]; then
		echo "ERROR: Vhost, $VHOST doesn't exists"
		exit 10
	fi

	debug "Checking if the new domain already exists ($NEWDOMAIN)"
	# Check if new domain already exists
	egrep -q "ServerName $NEWDOMAIN" /etc/apache2/sites-enabled/* && EXISTSSERVERNAME=$? || EXISTSSERVERNAME=$?
	egrep -q "ServerAlias $NEWDOMAIN" /etc/apache2/sites-enabled/* && EXISTSSERVERALIAS=$? || EXISTSSERVERALIAS=$?
	if [[ "$EXISTSSERVERALIAS" -eq 0 || $EXISTSSERVERNAME -eq 0 ]]; then
		echo "ERROR: Domain, $NEWDOMAIN already exists in a vhost"
		exit 10
	fi
}

check_existence_remove() {
	debug "Checking if site exists ($SITENAME)"
	# Check if site dir already exists
	if [ ! -d "$MULTISITE/sites/$SITENAME" ]; then
		echo "ERROR: Sitedir, $MULTISITE/sites/$SITENAME doesn't exists"
		exit 10
	fi

	# Check if site vhost exists
	if [ ! -f "$VHOST" ]; then
		echo "ERROR: Vhost, $VHOST doesn't exists"
		exit 10
	fi

	debug "Checking if the domain exists ($REMOVEDOMAIN)"
	# Check if new domain exists
	EXISTSSERVERALIAS=$(egrep -c "ServerAlias $REMOVEDOMAIN" "/etc/apache2/sites-enabled/$SITENAME" || true)
	if [[ "$EXISTSSERVERALIAS" -eq 0 ]]; then
		echo "ERROR: Vhost, $REMOVEDOMAIN doesn't exists in the vhost for $SITENAME"
		exit 10
	fi
}

add_to_hosts() {
	local DOMAIN="$1"
	debug "Adding $DOMAIN to /etc/hosts"
	echo "$SERVERIP $DOMAIN" >>/etc/hosts
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
  /usr/bin/$MYSQL_ROOT -e "CREATE DATABASE $DBNAME;"
  if [ -z "$DBUSER_HOST" ]
  then
    DBUSER_HOST="localhost"
  fi
  /usr/bin/$MYSQL_ROOT -e "GRANT ALL ON $1.* TO $DBUSER@\"$DBUSER_HOST\" IDENTIFIED BY \"$DBPASS\"";
}

create_dirs() {
	debug "Creating dirs"
	TMPDIR="$TMPDIRBASE/$SITENAME"
	LOGDIR="$LOGDIRBASE/$SITENAME"
	SESSIONDIR="$SESSIONDIRBASE/$SITENAME"
	mkdir -p "$TMPDIR"
	mkdir -p "$LOGDIR"
	mkdir -p "$SESSIONDIR"

	if [ -n "$(type -t ${FUNCNAME[0]}_local)" ] && [ "$(type -t ${FUNCNAME[0]}_local)" = function ]; then
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
		apachectl graceful
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

	if [ -n "$(type -t ${FUNCNAME[0]}_local)" ] && [ "$(type -t ${FUNCNAME[0]}_local)" = function ]; then
		${FUNCNAME[0]}_local
	fi
}

install_drupal8() {
	debug "starting install Drupal"
	# Preparing site folder
	mkdir -p "$MULTISITE/sites/$SITENAME"
	cp $MULTISITE/sites/default/default.settings.php $MULTISITE/sites/$SITENAME/settings.php
	if [ $(echo ${PROFILE} | cut -d"=" -f1) == '--existing-config' ]; then
		CONFIG_DIR=$(echo ${PROFILE} | cut -d"=" -f2)
		PROFILE=$(echo ${PROFILE} | cut -d"=" -f1)
	else
		CONFIG_DIR=$BASEDIR/config/$SITENAME/sync
		mkdir -p $CONFIG_DIR
	fi

	echo "\$settings['config_sync_directory'] = \"$CONFIG_DIR\";" >>$MULTISITE/sites/$SITENAME/settings.php
	echo "\$settings['file_temp_path'] = \"$TMPDIR\";" >>$MULTISITE/sites/$SITENAME/settings.php

	# Do a drush site install
	$DRUSH -y -r $MULTISITE site-install $PROFILE --locale=da --db-url="mysql://$DBUSER:$DBPASS@$DBHOST/$DBNAME" --sites-subdir="$SITENAME" --account-mail="$EMAIL" --site-mail="$EMAIL" --site-name="$SITENAME" --account-pass="$ADMINPASS" $INSTALL_OPTIONS
	debug "Drupal install phase succesfuly finished"

	# Set tmp
	$DRUSH -q -y -r "$MULTISITE" --uri="$SITENAME" config-set system.file path.temporary "$TMPDIR"

	# Do some drupal setup here. Could also be done in the install profile.
	$DRUSH -q -y -r "$MULTISITE" --uri="$SITENAME" cset user.settings register admin_only
	$DRUSH -q -y -r "$MULTISITE" --uri="$SITENAME" cset system.logging error_level some
	$DRUSH -q -y -r "$MULTISITE" --uri="$SITENAME" config-set system.performance css.preprocess 1
	$DRUSH -q -y -r "$MULTISITE" --uri="$SITENAME" config-set system.performance js.preprocess 1
	$DRUSH -q -y -r "$MULTISITE" --uri="$SITENAME" config-set system.performance cache.max.age 10800
	$DRUSH -q -y -r "$MULTISITE" --uri="$SITENAME" pm:uninstall update

	debug "Update translations"
	$DRUSH -q -y -r "$MULTISITE" --uri="$SITENAME" locale-check
	$DRUSH -q -y -r "$MULTISITE" --uri="$SITENAME" locale-update

	if [ -n "$(type -t ${FUNCNAME[0]}_local)" ] && [ "$(type -t ${FUNCNAME[0]}_local)" = function ]; then
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

	if [ -n "$(type -t ${FUNCNAME[0]}_local)" ] && [ "$(type -t ${FUNCNAME[0]}_local)" = function ]; then
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
	(
		/usr/bin/crontab -u $APACHEUSER -l
		echo "$CRONLINE"
	) | /usr/bin/crontab -u $APACHEUSER -
}

set_crontab8() {
	CRONLINE="$CRONMINUTE */2 * * * $DRUSH --root=$MULTISITE --uri=$SITENAME cron -q"
	(
		/usr/bin/crontab -u $APACHEUSER -l
		echo "$CRONLINE"
	) | /usr/bin/crontab -u $APACHEUSER -
}

mail_status() {
	debug "Sending statusmail ($SITENAME)"
}

add_subsiteadmin() {
	debug "Create subsiteadmin user with email ($USEREMAIL)"
	# This function compatible with Drupal 7/8
	# Create user with email specified in subsitecreator.
	$DRUSH -q -y -r "$MULTISITE" --uri="$SITENAME" user-create subsiteadmin --mail="$USEREMAIL"
	# Add the role "Administrator"
	$DRUSH -q -y -r "$MULTISITE" --uri="$SITENAME" user-add-role subsiteadmin subsiteadmin
	# Send single-use login link.
	$DRUSH -q -y -r "$MULTISITE" --uri="$SITENAME" ev "_user_mail_notify('password_reset', user_load_by_mail('$USEREMAIL'));"

	if [ -n "$(type -t ${FUNCNAME[0]}_local)" ] && [ "$(type -t ${FUNCNAME[0]}_local)" = function ]; then
		${FUNCNAME[0]}_local
	fi
}

delete_vhost() {
	debug "Disabling and deleting $SITENAME vhost"
	#a2dissite "$SITENAME" >/dev/null
	rm -f "/etc/apache2/sites-enabled/$SITENAME.conf"
	rm -f "/etc/apache2/sites-available/$SITENAME.conf"
	debug "Reloading Apache2"
	if [ -f /etc/init.d/apache2 ]; then
		/etc/init.d/apache2 reload >/dev/null
	else
		apachectl graceful
	fi
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
  #/usr/local/sbin/mysql_backup.sh "$DBNAME"
  /usr/bin/$MYSQL_ROOT -e "DROP DATABASE $DBNAME;"

  if [ -z "$DBUSER_HOST" ]
  then
    DBUSER_HOST="localhost"
  fi
  /usr/bin/$MYSQL_ROOT -e "DROP USER $DBUSER@\"$DBUSER_HOST\"";
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
	if [ -d "$BASEDIR/config/$SITENAME" ]; then
		rm -rf "$BASEDIR/config/$SITENAME"
	fi

	if [ -n "$(type -t ${FUNCNAME[0]}_local)" ] && [ "$(type -t ${FUNCNAME[0]}_local)" = function ]; then
		${FUNCNAME[0]}_local
	fi
}

remove_from_crontab() {
	debug "Removing Drupal cron.php from $APACHEUSER crontab ($SITENAME)"
	crontab -u $APACHEUSER -l | sed "/$SITENAME/d" | crontab -u $APACHEUSER -
}

add_to_vhost() {
	debug "Adding $NEWDOMAIN to vhost for $SITENAME"
	/usr/bin/perl -p -i -e "s/ServerName $SITENAME/ServerName $SITENAME\n    ServerAlias $NEWDOMAIN/g" "$VHOST"
	debug "Reloading Apache2"
	if [ -f /etc/init.d/apache2 ]; then
		/etc/init.d/apache2 reload >/dev/null
	else
		apachectl graceful
	fi
}

add_to_sites() {
	debug "Adding $NEWDOMAIN to sites.php"
	echo "\$sites['$NEWDOMAIN'] = '$SITENAME';" >>$SITESFILE

	if [ -n "$(type -t ${FUNCNAME[0]}_local)" ] && [ "$(type -t ${FUNCNAME[0]}_local)" = function ]; then
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
