# OS2Subsites Drupal 8 module

Subsites settings should be defined in settings.php file of Drupal installation with  `bc_subsites.settings` key for $config variable.

Setting keys:

* enabled - flag key to allow subsites feature on specific installation;
* domain_suffix - last common part of domain;
* script_dir - absolute path to subsites provision scripts. See https://github.com/bellcom/os2subsite_provision;
* subsites_config_dir - path to general directory with sites configuration files;
* base_subsite_config_dir - path to base subsite configuration files for option to install from an exsisting configuration;
* allowed_install_profiles - array with allowed profiles to select for subsite;
* default_profile - default value for installation profile.
* external_db_provisioning - external db provisioning flag for activates two phases provisioning.

Example:
```
$config['bc_subsites.settings'] = [
  'enabled' => TRUE,
  'domain_suffix' => 'example.com',
  'script_dir' => '/var/www/.os2subsite_provision',
  'subsites_config_dir' => '../config',
  'base_subsite_config_dir' => '../config/base.subsite/sync',
  'allowed_install_profiles' => [
    'standard',
    'minimal',
  ],
  'default_profile' => 'base_config',
  'external_db_provisioning' => FALSE,
];
```
