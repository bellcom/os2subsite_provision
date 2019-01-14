# OS2Subsites Drupal 8 module

Subsites settings should be defined in settings.php file of Drupal installation with  `bc_subsites.settings` key for $config variable.

Setting keys:

* enabled - flag key to allow subsites feature on specific installation;
* domain_suffix - last common part of domain;
* script_dir - absolute path to subsites provision scripts. See https://github.com/bellcom/os2subsite_provision

Example:
```
$config['bc_subsites.settings'] = [
 'enabled' => TRUE,
 'domain_suffix' => 'example.com',
 'script_dir' => '/var/www/os2subsite_provision',
];
```
