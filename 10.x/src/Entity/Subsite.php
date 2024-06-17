<?php

namespace Drupal\bc_subsites\Entity;

use Drupal\Component\Render\FormattableMarkup;
use Drupal\Core\Field\BaseFieldDefinition;
use Drupal\Core\Entity\ContentEntityBase;
use Drupal\Core\Entity\EntityTypeInterface;
use Drupal\bc_subsites\SubsiteInterface;
use Drupal\Core\Entity\EntityChangedTrait;
use Drupal\Core\Messenger\MessengerTrait;

/**
 * Defines the ContentEntityExample entity.
 *
 * @ingroup bc_subsites
 *
 * @ContentEntityType(
 *   id = "subsite",
 *   label = @Translation("Subsite entity"),
 *   handlers = {
 *     "view_builder" = "Drupal\Core\Entity\EntityViewBuilder",
 *     "list_builder" = "Drupal\bc_subsites\Entity\Controller\SubsiteListBuilder",
 *     "form" = {
 *       "add" = "Drupal\bc_subsites\Form\SubsiteForm",
 *       "edit" = "Drupal\bc_subsites\Form\SubsiteForm",
 *       "delete" = "Drupal\bc_subsites\Form\SubsiteDeleteForm",
 *     },
 *     "access" = "Drupal\bc_subsites\SubsiteAccessControlHandler",
 *   },
 *   list_cache_contexts = { "user" },
 *   base_table = "os2subsite",
 *   entity_keys = {
 *     "id" = "id",
 *     "name" = "name",
 *     "uuid" = "uuid",
 *     "admin_mail" = "admin_mail",
 *   },
 *   links = {
 *     "canonical" = "/admin/structure/{subsite}",
 *     "edit-form" = "/admin/structure/{subsite}/edit",
 *     "delete-form" = "/admin/structure/{subsite}/delete",
 *     "collection" = "/admin/structure/subsite/list"
 *   },
 * )
 *
 * The 'links' above are defined by their path. For core to find the
 * corresponding route, the route name must follow the correct pattern:
 *
 * entity.<entity-name>.<link-name> (replace dashes with underscores)
 * Example: 'entity.subsite.canonical'
 *
 * See routing file above for the corresponding implementation
 *
 * The Subsite class defines methods and fields for the subsite entity.
 *
 * Being derived from the ContentEntityBase class, we can override the methods
 * we want. In our case we want to provide access to the standard fields about
 * creation and changed time stamps.
 *
 * Our interface (see SubsiteInterface) also exposes the EntityOwnerInterface.
 * This allows us to provide methods for setting and providing ownership
 * information.
 *
 * The most important part is the definitions of the field properties for this
 * entity type. These are of the same type as fields added through the GUI, but
 * they can by changed in code. In the definition we can define if the user with
 * the rights privileges can influence the presentation (view, edit) of each
 * field.
 *
 * The class also uses the EntityChangedTrait trait which allows it to record
 * timestamps of save operations.
 */
class Subsite extends ContentEntityBase implements SubsiteInterface {

  use EntityChangedTrait;
  use MessengerTrait;

  /**
   * {@inheritdoc}
   *
   * Define the field properties here.
   *
   * Field name, type and size determine the table structure.
   *
   * In addition, we can define how the field and its content can be manipulated
   * in the GUI. The behaviour of the widgets used can be determined here.
   */
  public static function baseFieldDefinitions(EntityTypeInterface $entity_type) {

    // Standard field, used as unique if primary index.
    $fields['id'] = BaseFieldDefinition::create('integer')
      ->setLabel(t('ID'))
      ->setDescription(t('The ID of the Subsite entity.'))
      ->setReadOnly(TRUE);

    // Standard field, unique outside of the scope of the current project.
    $fields['uuid'] = BaseFieldDefinition::create('uuid')
      ->setLabel(t('UUID'))
      ->setDescription(t('The UUID of the Subsite entity.'))
      ->setReadOnly(TRUE);

    // Name of the subsite.
    $fields['name'] = BaseFieldDefinition::create('string')
      ->setLabel(t('Subdomain name'))
      ->setDescription(t('The main subdomain name of the Subsite entity.'))
      ->setRequired(TRUE)
      ->setSettings([
        'max_length' => 255,
        'text_processing' => 0,
      ])
      // Set no default value.
      ->setDefaultValue(NULL)
      ->setDisplayOptions('view', [
        'label' => 'above',
        'type' => 'string',
        'weight' => -6,
      ])
      ->setDisplayOptions('form', [
        'type' => 'string_textfield',
        'weight' => -6,
      ])
      ->setDisplayConfigurable('form', FALSE)
      ->setDisplayConfigurable('view', FALSE);

    // Administrator email field for the subsite.
    $fields['admin_mail'] = BaseFieldDefinition::create('email')
      ->setLabel(t('Administrator email'))
      ->setDescription(t('The admin email of the Subsite entity.'))
      ->setRequired(TRUE)
      ->setDefaultValue('')
      ->setDisplayOptions('view', [
        'label' => 'above',
        'type' => 'string',
        'weight' => -6,
      ])
      ->setDisplayOptions('form', [
        'type' => 'string_textfield',
        'weight' => -6,
      ])
      ->setDisplayConfigurable('form', FALSE)
      ->setDisplayConfigurable('view', FALSE);

    $profile_options = [];
    $allowed_install_profiles = self::getConfigValue('allowed_install_profiles') ?: [];
    if (!empty($allowed_install_profiles)) {
      foreach ($allowed_install_profiles as $profile) {
        $profile_path = drupal_get_path('profile', $profile);
        $info = \Drupal::service('info_parser')->parse("$profile_path/$profile.info.yml");
        $profile_options[$profile] = $info['name'];
      }
    }

    $base_subsite_config_sync_dir = self::getConfigValue('base_subsite_config_dir');
    $subsites_config_dir = self::getConfigValue('subsites_config_dir');
    if ($base_subsite_config_sync_dir && $subsites_config_dir) {
      $profile_options['base_config'] = t('Install from base configuration @config_path', [
        '@config_path' => $base_subsite_config_sync_dir,
      ]);
    }

    // Install profile field for the subsite.
    $fields['profile'] = BaseFieldDefinition::create('list_string')
      ->setLabel(t('Install profile'))
      ->setDescription(t('Select profile for new subsite. If no profile selected default value from subiste configuration will be used.'))
      ->setRequired(FALSE)
      ->setDefaultValue(self::getConfigValue('default_profile') ?: '')
      ->setReadOnly(TRUE)
      ->setDisplayOptions('view', [
        'label' => 'above',
        'type' => 'string',
        'weight' => -5,
      ])
      ->setSetting('allowed_values', $profile_options)
      ->setDisplayOptions('form', [
        'type' => 'options_buttons',
        'weight' => -5,
      ])
      ->setDisplayConfigurable('form', FALSE)
      ->setDisplayConfigurable('view', FALSE);

    // Additional domains for subsite.
    $fields['domains'] = BaseFieldDefinition::create('string_long')
      ->setLabel(t('Domains'))
      ->setDescription(t('Here you must specify which public domain the site should respond to. eg. "svendborg-havn.dk" and "www.svendborg-havn.dk". If you do not specify something here. Will the site not be publicly available..'))
      ->setDefaultValue('')
      ->setDisplayOptions('view', [
        'label' => 'hidden',
        'type' => 'text_default',
        'weight' => 0,
      ])
      ->setDisplayConfigurable('view', TRUE)
      ->setDisplayOptions('form', [
        'type' => 'text_textfield',
        'weight' => 0,
      ])
      ->setDisplayConfigurable('form', TRUE);

    // Subsite description user for searching index.
    $fields['description'] = BaseFieldDefinition::create('string_long')
      ->setLabel(t('Description'))
      ->setDescription(t('Description for subsite. Keyword related to subsite.'))
      ->setTranslatable(TRUE)
      ->setDefaultValue('')
      ->setDisplayOptions('view', [
        'label' => 'hidden',
        'type' => 'text_default',
        'weight' => 0,
      ])
      ->setDisplayConfigurable('view', TRUE)
      ->setDisplayOptions('form', [
        'type' => 'text_textfield',
        'weight' => 0,
      ])
      ->setDisplayConfigurable('form', TRUE);

    $fields['changed'] = BaseFieldDefinition::create('changed')
      ->setLabel(t('Changed'))
      ->setDescription(t('The time that the entity was last edited.'));

    // Provisioning state of the subsite.
    $fields['provisioning_state'] = BaseFieldDefinition::create('list_string')
      ->setLabel(t('Provisioning state'))
      ->setRequired(TRUE)
      ->setDefaultValue('full')
      ->setDisplayConfigurable('view', TRUE);

    // Provisioning state of the subsite.
    $fields['last_log_message'] = BaseFieldDefinition::create('string_long')
      ->setLabel(t('Last log message'))
      ->setDescription(t('Shows last log message.'))
      ->setDefaultValue('')
      ->setDisplayOptions('form', [
        'type' => 'text_textfield',
        'weight' => 0,
      ])
      ->setDisplayConfigurable('form', FALSE)
      ->setDisplayConfigurable('view', FALSE);

    return $fields;
  }

  /**
   * Get domain.
   */
  public function getDomain($name = FALSE) {
    if (empty($name)) {
      $name = $this->name->value;
    }
    return $name . '.' . $this->getConfigValue('domain_suffix');
  }

  /**
   * Get provisioning_state.
   */
  public function getProvisioningState() {
    return $this->provisioning_state->value;
  }

  /**
   * Set provisioning_state.
   */
  public function setProvisioningState($value) {
    return $this->set('provisioning_state', $value);
  }

  /**
   * Get Last log message.
   */
  public function getLastLogMessage() {
    return $this->last_log_message->value;
  }

  /**
   * Set Last log message.
   */
  public function setLastLogMessage($value) {
    return $this->set('last_log_message', $value);
  }

  /**
   * Get config value.
   */
  public static function getConfigValue($key) {
    $bc_settings = \Drupal::service('config.factory')->get('bc_subsites.settings');
    return $bc_settings->get($key);
  }

  /**
   * Gets variable value from shell script by using source command.
   */
  public static function getScriptsConfigValue($key, $file = FALSE) {
    if (getenv('USE_ENV_CONFIG') && empty($file)) {
      return getenv($key);
    }
    if (empty($file)) {
      $file = '../scripts/os2subsites_provision/config.sh';
    }
    $complete_command = 'bash -c \'source ' . $file . ' && echo $' . $key . '\'';
    exec($complete_command, $op, $return_var);
    return isset($op[0]) ? $op[0] : NULL ;
  }

  /**
   * Execute subsite script.
   */
  private function subsiteExecute($command) {
    $script_path = $this->getConfigValue('script_dir');
    // Preserv environment configuration.
    $preserve_env = $this->getScriptsConfigValue('USE_ENV_CONFIG') ? '-E' : '';
    $complete_command = "sudo $preserve_env $script_path/$command";

    $log = realpath(\Drupal::service('file_system')->getTempDirectory()) . '/' . preg_replace("/[^a-zA-Z0-9]+/", "", $command) . rand(0, 20) . '.log';
    $complete_command = 'nohup ' . $complete_command . ' > ' . $log . ' 2>&1 & echo $!';

    $pid = exec($complete_command, $op, $return_var);
    $session_key = $pid . '|' . $this->id();
    $_SESSION['bc_subsite_pids'][$session_key] = $log;

    if ($return_var > 0) {
      $this->messenger()->addMessage(t('Der skete en fejl') . ': '  . end($op), 'error');
    }
    $logger = \Drupal::logger('bc_subsites');
    $logger->notice(new FormattableMarkup('Executed command: "%command", pid: <pre>%op</pre>', [
      '%command' => $complete_command,
      '%op' => implode("\n", $op)
    ]));
  }

  /**
   * Create subsite.
   */
  public function subsitesCreate($domain, $useremail, $profile_options) {
    $this->subsiteExecute('subsite_create.sh ' . $this->getDomain($domain) . ' ' . $useremail . ' "' . $profile_options . '"');
  }

  /**
   * Run phase2 on subsite.
   */
  public function subsitesPhase1($domain, $useremail, $profile_options) {
    $this->subsiteExecute('phase1.sh ' . $this->getDomain($domain) . ' ' . $useremail);
  }

  /**
   * Run phase2 on subsite.
   */
  public function subsitesPhase2($domain, $useremail, $profile_options) {
    $this->subsiteExecute('phase2.sh ' . $this->getDomain($domain) . ' ' . $useremail . ' "' . $profile_options . '"');
  }

  /**
   * Delete subsite.
   */
  public function subsitesDelete($domain) {
    $this->subsiteExecute('subsite_delete.sh ' . $this->getDomain($domain));
  }

  /**
   * Remove domains from subsite.
   */
  public function removeDomains($sitename, $domains) {
    foreach ($domains as $domain) {
      $this->subsiteExecute('subsite_remove_domain.sh ' . $this->getDomain($sitename) . ' ' . $this->getDomain($domain));
    }
  }

  /**
   * Add domains to subsite.
   */
  public function addDomains($sitename, $domains) {
    foreach ($domains as $domain) {
      $this->subsiteExecute('subsite_add_domain.sh ' . $this->getDomain($sitename) . ' ' . $domain);
    }
  }

  /**
   * Validate domain name.
   */
  public function isValidDomain($domain_name) {
    if (strpos($domain_name, '.') === FALSE) {
      return FALSE;
    }

    if ($domain_name != strtolower($domain_name)) {
      return FALSE;
    }

    // http://stackoverflow.com/questions/1755144/how-to-validate-domain-name-in-php
    return (preg_match("/^([a-z\d](-*[a-z\d])*)(\.([a-z\d](-*[a-z\d])*))*$/i", $domain_name)
      && preg_match("/^.{1,253}$/", $domain_name)
      && preg_match("/^[^\.]{1,63}(\.[^\.]{1,63})*$/", $domain_name));
  }

  /**
   * Clone config directory folder.
   */
  public function cloneConfigDir($source, $destination) {
    mkdir($destination, 0755, TRUE);
    foreach (array_diff(scandir($source), array('..', '.')) as $file) {
      copy($source . '/' . $file, $destination . '/' . $file);
    }
  }

  public static function getProvisioningStates() {
    return [
      'phase1' => t('Phase 1'),
      'phase2' => t('Phase 2'),
      'full' => t('Full'),
      'completed' => t('Completed'),
    ];
  }
}
