<?php
/**
 * @file
 * bc_subsites.features.field_instance.inc
 */

/**
 * Implements hook_field_default_field_instances().
 */
function bc_subsites_field_default_field_instances() {
  $field_instances = array();

  // Exported field_instance: 'node-subsite-field_admin_mail'
  $field_instances['node-subsite-field_admin_mail'] = array(
    'bundle' => 'subsite',
    'default_value' => NULL,
    'deleted' => 0,
    'description' => '',
    'display' => array(
      'default' => array(
        'label' => 'above',
        'module' => 'text',
        'settings' => array(),
        'type' => 'text_default',
        'weight' => 1,
      ),
      'teaser' => array(
        'label' => 'above',
        'settings' => array(),
        'type' => 'hidden',
        'weight' => 0,
      ),
    ),
    'entity_type' => 'node',
    'field_name' => 'field_admin_mail',
    'label' => 'Admin e-mail',
    'required' => 1,
    'settings' => array(
      'text_processing' => 0,
      'user_register_form' => FALSE,
    ),
    'widget' => array(
      'active' => 1,
      'module' => 'text',
      'settings' => array(
        'size' => 60,
      ),
      'type' => 'text_textfield',
      'weight' => -3,
    ),
  );

  // Exported field_instance: 'node-subsite-field_domains'
  $field_instances['node-subsite-field_domains'] = array(
    'bundle' => 'subsite',
    'default_value' => NULL,
    'deleted' => 0,
    'description' => '<p>Her skal du angive hvilke offentlige domæner sitet skal svare på. f.eks. "svendborg-havn.dk" og "www.svendborg-havn.dk".</p>
<p>Hvis ikke du angiver noget her. Vil sitet ikke være offentligt tilgængeligt.</p>',
    'display' => array(
      'default' => array(
        'label' => 'above',
        'module' => 'text',
        'settings' => array(),
        'type' => 'text_default',
        'weight' => 0,
      ),
      'teaser' => array(
        'label' => 'above',
        'settings' => array(),
        'type' => 'hidden',
        'weight' => 0,
      ),
    ),
    'entity_type' => 'node',
    'field_name' => 'field_domains',
    'label' => 'Domæner',
    'required' => 0,
    'settings' => array(
      'text_processing' => 0,
      'user_register_form' => FALSE,
    ),
    'widget' => array(
      'active' => 1,
      'module' => 'text',
      'settings' => array(
        'size' => 60,
      ),
      'type' => 'text_textfield',
      'weight' => -4,
    ),
  );

  // Translatables
  // Included for use with string extractors like potx.
  t('<p>Her skal du angive hvilke offentlige domæner sitet skal svare på. f.eks. "svendborg-havn.dk" og "www.svendborg-havn.dk".</p>
<p>Hvis ikke du angiver noget her. Vil sitet ikke være offentligt tilgængeligt.</p>');
  t('Admin e-mail');
  t('Domæner');

  return $field_instances;
}
