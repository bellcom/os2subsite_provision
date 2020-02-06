# Drupal multisite server provision scripts set.

## Requirements.
* Drupal 7,8
* Apache web server

NOTE: This solution doesn't work with NGINX web server.

## Download and install.

Composer is recommended way to get files in your drupal project.
Just use command `composer require bellcom/os2subsites_provision`.

### Composer specific settings.
For composer based stack you will need to add specific settings to composer.json file.

#### 1. Override default installed path for composer installer. 
By default `bellcom/os2subsites_provision` will be installed as `drupal-module`.
Add extra line to your `composer.json` to override default path.

Add this line
```
"scripts/os2subsites_provision": ["bellcom/os2subsites_provision"],
```
above line define path for drupal modules
```
    "extra": {
        ...
        "installer-paths": {
            ...
            "scripts/os2subsites_provision": ["bellcom/os2subsites_provision"],
            "web/modules/contrib/{$name}": ["type:drupal-module"],
            ...
        }
        ...
    }
```
#### 2. Check local and config files.

Composer will keep os2subsite_provision code base updated and stable. It means that all
extra files will be removed from os2subsites_provision directory, includes config
and local files. To add files back after every composer install/update add
following command to composer.json `scripts` section. 

```
    "scripts": {
        ...
        "post-install-cmd": [
             ...
            "./scripts/os2subsites_provision/check_config.sh scripts/os2subsites_provision_config"
             ...
        ],
        "post-update-cmd": [
             ...
            "./scripts/os2subsites_provision/check_config.sh scripts/os2subsites_provision_config"
             ...
        ]
    },

```

To manage subsites there are drupal module that triggering server scripts.
See how to add module below.

### Allow web server run os2subsites_provision scripts.

To allow web server run scripts that will handle subsites you need to allow
apache user run this scripts with `sudo` rights without password.
To allow Apache user `www-data` run os2subsites scripts add following line
 to `/etc/sudoers.d/os2subiste_provision` file.
```
www-data   ALL=(root) NOPASSWD: /var/www/[your-project]/scripts/os2subsites_provision/subsite_add_domain.sh
www-data   ALL=(root) NOPASSWD: /var/www/[your-project]/scripts/os2subsites_provision/subsite_create.sh
www-data   ALL=(root) NOPASSWD: /var/www/[your-project]/scripts/os2subsites_provision/subsite_delete.sh
www-data   ALL=(root) NOPASSWD: /var/www/[your-project]/scripts/os2subsites_provision/subsite_remove_domain.sh
www-data   ALL=(root) NOPASSWD: /var/www/[your-project]/scripts/os2subsites_provision/reload.sh
```
Restart web server after adding to apply changes.

Check article [How to run sudo command without a password](https://www.cyberciti.biz/faq/linux-unix-running-sudo-command-without-a-password/)
if you need more info or just google it.


## Drupal 8 module.

To add module to your Drupal 8 installation create symlink to proper 8.x module
 as you can see in  example. It assumes that you have `web` as drupal root
 folder and `scripts/os2subsites_provision` as folder with os2subsites scripts.
```
mkdir -p ./web/modules/custom
cd ./web/modules/custom
ln -s ../../../scripts/os2subsites_provision/8.x/bc_subsites
```

See module [README.md](https://github.com/bellcom/os2subsite_provision/blob/develop/8.x/bc_subsites/README.md) file

## Drupal 7 module.

To add module to your Drupal 7 installation create symlink to proper 7.x module
 as you can see in  example. It assumes that you have `docroot` as drupal root
 folder and `scripts/os2subsites_provision` as folder with os2subsite_provision scripts.
```
mkdir -p ./web/sites/all/modules/custom
cd ./web/sites/all/modules/custom
ln -s ../../../../../scripts/os2subsites_provision/7.x/bc_subsites
```
See module [README.md](https://github.com/bellcom/os2subsite_provision/blob/develop/7.x/bc_subsites/README.md) file
