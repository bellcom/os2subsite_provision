<?php
/**
 * @file
 * bc_subsites.features.inc
 */

/**
 * Implements hook_node_info().
 */
function bc_subsites_node_info() {
  $items = array(
    'subsite' => array(
      'name' => t('Subsite'),
      'base' => 'node_content',
      'description' => '',
      'has_title' => '1',
      'title_label' => t('Navn'),
      'help' => t('Navnet på sitet fungerer også som internt subdomæne. Dette subdomæne vil ikke være offentligt tilgængeligt uden adgangskode.'),
    ),
  );
  drupal_alter('node_info', $items);
  return $items;
}
