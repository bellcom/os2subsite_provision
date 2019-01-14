<?php
/**
 * @file
 * os2sub_uses_and_tools.features.user_role.inc
 */

/**
 * Implements hook_user_default_roles().
 */
function bc_subsites_user_default_roles() {
  $roles = array();

  // Exported role: subsiteadmin.
  $roles['subsiteadmin'] = array(
    'name' => 'subsiteadmin',
    'weight' => 2,
  );

  return $roles;
}
