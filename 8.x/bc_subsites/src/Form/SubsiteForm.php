<?php

namespace Drupal\bc_subsites\Form;

use Drupal\bc_subsites\Entity\Subsite;
use Drupal\Core\Entity\ContentEntityForm;
use Drupal\Core\Form\FormStateInterface;
use Drupal\Core\Link;
use Drupal\Core\Url;

/**
 * Form controller for the bc_subsites entity edit forms.
 *
 * @ingroup bc_subsites
 */
class SubsiteForm extends ContentEntityForm {

  /**
   * {@inheritdoc}
   */
  public function buildForm(array $form, FormStateInterface $form_state) {
    $entity = $this->getEntity();
    if (empty($entity->getConfigValue('domain_suffix'))) {
      \Drupal::messenger()->addMessage(t('bc_subsites module is not configured. See README.md.'));
      return $form;
    }

    /* @var $entity \Drupal\bc_subsites\Entity\Subsite */
    $form = parent::buildForm($form, $form_state);
    $entity = $this->getEntity();
    // Suffix domain to form.
    $form['name']['widget'][0]['value']['#children'] = '.' . $entity->getConfigValue('domain_suffix');
    $form['name']['widget'][0]['value']['#size'] = 20;
    if (!empty($entity->name->value)) {
      $form['name']['widget'][0]['value']['#disabled'] = TRUE;
    }

    $form['#validate'][] = '::validateSubsite';

    $provisioning_state = $entity->getProvisioningState();
    if ($entity->isNew() && $entity->getConfigValue('external_db_provisioning')) {
        $provisioning_state = 'phase1';
    }

    switch ($provisioning_state) {
      case 'phase1':
        $form['actions']['submit']['#access'] = FALSE;
        $form['actions']['phase1'] = [
          '#type' => 'submit',
          '#value' => $this->t('Phase 1'),
          '#submit' => ['::submitPhase1'],
          '#button_type' => 'primary',
        ];
        break;

      case 'phase2':
        $form['actions']['submit']['#access'] = FALSE;
        $form['actions']['phase2'] = [
          '#type' => 'submit',
          '#value' => $this->t('Phase 2'),
          '#submit' => ['::submitPhase2'],
          '#button_type' => 'primary',
        ];

        $subsite_credentials = file_get_contents($this->getSubsitesCredentialsFilePath($entity));
        $form['subsite_credentials'] = ['#markup' => '<strong>' . $this->t('WARNING: Subsite credentials file not found or empty.'). '</strong>'];
        if (!empty($subsite_credentials)) {
          // Removing SITENAME line from subsite credentials file.
          $subsite_credentials = str_replace('SITENAME=' . $entity->getDomain() . PHP_EOL, '', $subsite_credentials);
          $form['subsite_credentials'] = [
            '#title' => $this->t('Subsite creadentials'),
            '#type' => 'textarea',
            '#default_value' => $subsite_credentials,
            '#element_validate' => ['::validateDbCredentials'],
          ];
        }
        break;
    }


    return $form;
  }

  /**
   * {@inheritdoc}
   */
  public function submitPhase1(array $form, FormStateInterface $form_state) {
    $entity = $this->getEntity();
    $entity->set('provisioning_state', 'phase1');
    $this->submitForm($form, $form_state);
    $this->save($form, $form_state);
  }

  /**
   * Validate db credentials handler
   */
  public function validateDbCredentials(array $element, FormStateInterface $form_state) {
    $entity = $this->getEntity();
    $db_credentials = str_replace(["\r\n", ' '], [PHP_EOL, ''], $element['#value']);
    $tmp_filename = \Drupal::service('file_system')->getTempDirectory() . DIRECTORY_SEPARATOR . $entity->getDomain();
    file_put_contents($tmp_filename, $db_credentials);
    $db_host = Subsite::getScriptsConfigValue('DBHOST');
    $db_name = Subsite::getScriptsConfigValue('DBNAME', $tmp_filename);
    $db_user = Subsite::getScriptsConfigValue('DBUSER', $tmp_filename);
    $db_pass = Subsite::getScriptsConfigValue('DBPASS', $tmp_filename);
    unlink($tmp_filename);
    $complete_command = '$(mysql -u' . $db_user . ' -p' . $db_pass . ' ' . $db_name . ' -h' . $db_host . ' -e ";")';
    exec($complete_command, $op, $return_var);
    if ($return_var) {
      $form_state->setError($element, $this->t('Database with this credentials is not accessible'));
    }
  }

  /**
   * {@inheritdoc}
   */
  public function submitPhase2(array $form, FormStateInterface $form_state) {
    $entity = $this->getEntity();
    $entity->set('provisioning_state', 'phase2');

    if ($subsite_credentials = $form_state->getValue('subsite_credentials')) {
      $subsite_credentials = str_replace(["\r\n", ' '], [PHP_EOL, ''], $subsite_credentials);
      $subsite_credentials = 'SITENAME=' . $entity->getDomain() . PHP_EOL . $subsite_credentials;
      file_put_contents($this->getSubsitesCredentialsFilePath($entity), $subsite_credentials);
    }

    $this->submitForm($form, $form_state);
    $this->save($form, $form_state);
  }


  /**
   * {@inheritdoc}
   */
  public function save(array $form, FormStateInterface $form_state) {
    $form_state->setRedirect('subsites.status');
    $entity = $this->getEntity();
    $entity->save();
  }

  /**
   * Subsite validation.
   */
  public function validateSubsite(array $form, FormStateInterface $form_state) {
    // Validate domain name.
    $entity = $this->getEntity();

    if ($entity->isNew()) {
      $name = $form_state->getValue('name')[0]['value'];
      if (!$entity->isValidDomain($entity->getDomain($name))) {
        $form_state->setErrorByName('name', 'The entered name is not valid. Only lowercase letters and no special characters.');
      }

      $ids = \Drupal::entityQuery('subsite')
        ->condition('name', $name)
        ->execute();
      if (!empty($ids)) {
        $form_state->setErrorByName('name', 'The entered name is already in use.');
      }
    }

    // Validate additional domains.
    $domains = $form_state->getValue('domains')[0]['value'];
    foreach (explode("\r\n", $domains) as $delta => $value) {
      if (!empty($value)) {
        if (!$entity->isValidDomain($entity->getDomain($value))) {
          $form_state->setErrorByName('domains', 'The domain ' . $value . ' is not valid. Only lowercase letters and no special characters.');
        }
      }
    }
  }

  /**
   * Generates path to subsite credentials file.
   *
   * @param $entity
   *
   * @return string
   */
  private function getSubsitesCredentialsFilePath($entity) {
    $provisioning_source_path = Subsite::getScriptsConfigValue('PROVISIONING_SOURCES_PATH');
    return $provisioning_source_path . DIRECTORY_SEPARATOR . $entity->getDomain();
  }
}
