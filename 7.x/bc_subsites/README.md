# Bellcom Subsites module

This module allows a user with the sufficient permissions to create new
subsites in the drupal multisite.

## Usage

When enabled the module will add a menu link to the admin menu, "Subsites".
From here the user can create, edit and delete subsites. Subsites are saved in
drupal as nodes of the "subsite". The node contains info about the site-name,
what domains it is associated to, who and when the subsite was created.

The domain suffix must be specified in settings.php as:

```php
$conf['bc_subsites_domain_suffix'] = '.svendborg.bellcom.dk';
$conf['bc_subsites_script_dir'] = '/var/www/subsites.svendborg.dk/scripts/';
```

## Logging

All command output is sent to `watchdog()` and the php error-log.
