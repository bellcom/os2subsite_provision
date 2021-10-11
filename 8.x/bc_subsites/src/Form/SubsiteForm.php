<?php

namespace Drupal\bc_subsites\Form;

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
      $this->messenger()->addMessage(t('bc_subsites module is not configured. See README.md.'));
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
    return $form;
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

}
