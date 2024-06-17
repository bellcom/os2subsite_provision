<?php
/**
 * @file
 * Contains Subsites controller definition.
 */

namespace Drupal\bc_subsites\Controller;

use Drupal\bc_subsites\Entity\Subsite;
use Drupal\Component\Render\FormattableMarkup;
use Drupal\Core\Controller\ControllerBase;
use Drupal\Core\Messenger\MessengerInterface;
use Symfony\Component\HttpFoundation\RedirectResponse;
use Drupal\Core\Url;
use Drupal\Component\Serialization\Json;

/**
 * Class Subsites controller.
 *
 * @package Drupal\bc_subsites\Controller
 */
class SubsitesController extends ControllerBase {

  /**
   * Subsites status callback.
   */
  public function status() {
    if (!isset($_SESSION['bc_subsite_pids']) || empty($_SESSION['bc_subsite_pids'])) {
      if (!empty($_SESSION['bc_subsite_messages'][MessengerInterface::TYPE_ERROR])) {
        foreach ($_SESSION['bc_subsite_messages'][MessengerInterface::TYPE_ERROR] as $error) {
          $this->messenger()->addError(new FormattableMarkup($error, []));
        }
        unset($_SESSION['bc_subsite_messages'][MessengerInterface::TYPE_ERROR]);
      }
      if (!empty($_SESSION['bc_subsite_messages'][MessengerInterface::TYPE_STATUS])) {
        foreach ($_SESSION['bc_subsite_messages'][MessengerInterface::TYPE_STATUS] as $status) {
          $this->messenger()->addStatus(new FormattableMarkup($status, []));
        }
        unset($_SESSION['bc_subsite_messages'][MessengerInterface::TYPE_STATUS]);
      }
      return new RedirectResponse(Url::fromRoute('entity.subsite.collection')->toString());
    }

    $build['inline_js'] = [
      '#type' => 'html_tag',
      '#tag' => 'script',
      '#value' => 'setTimeout(function () { location.reload(1); }, 5000);',
    ];

    foreach ($_SESSION['bc_subsite_pids'] as $session_key => $log_file) {
      list($pid, $subsite_id) = explode('|', $session_key);
      // Check if process is still running.
      $op = array();
      $command = 'ps -p ' . $pid;
      exec($command, $op);
      $log = file_get_contents($log_file);
      if (!isset($op[1])) {
        unset($_SESSION['bc_subsite_pids'][$session_key]);

        // Load log and remove logfile.
        unlink($log_file);

        // Extractin log lines to better parsing
        $log_lines = array_filter(explode("\n", $log), function ($value) { return trim($value);});

        // By default we consider all messages as failed unless if would be found successful status.
        $status = FALSE;
        $complete_status = end($log_lines);
        $status_data = NULL;
        if (strpos($complete_status, 'complete_status:{') === 0) {
          $status_data = Json::decode(str_replace('complete_status:', '', $complete_status));
          if (isset($status_data['status'])) {
            $status = $status_data['status'];
          }
        }

        // Fetching subsite entity to update additional information.
        $subsite = NULL;
        /** @var Subsite|null $subsite */
        $subsite = $this->entityTypeManager()->getStorage('subsite')->load($subsite_id);

        if ($subsite) {
          // Update last_log_message for subsite.
          $subsite->set('last_log_message', $log);
          $subsite->save();
        }

        $message = new FormattableMarkup('Command pid: %pid, result: <pre>%log</pre>', [
          '%pid' => $pid,
          '%log' => $log,
        ]);

        $_SESSION['bc_subsite_messages'][$status ? MessengerInterface::TYPE_STATUS : MessengerInterface::TYPE_ERROR][] = (string) $message;
        $this->getLogger('bc_subsites')->notice($message);

        // Failed statuses is not handled.
        if (!$status) {
          continue;
        }

        if ($subsite) {
          // Update provisioning_state for subsite.
          if (isset($status_data['provisioning_state'])) {
            $subsite->set('provisioning_state', $status_data['provisioning_state']);
          }

          // Update successful last_log_message for subsite.
          $subsite->set('last_log_message', $log);
          $subsite->save();
        }
      }
    }

    $build['result']['#markup'] = '<p>Wait please...</p><div id="updateprogress" class="progress"
aria-live="polite"><div class="progress__label"></div><div class="progress__track"><div class="progress__bar" style="width: 100%;"></div></div></div>';
    if (!empty($log)) {
      $build['log'] = [
        '#type' => 'details',
        '#open' => TRUE,
        '#title' => t('execution log'),
        'execution_log' => ['#markup' => "<pre>$log</pre>"],
      ];
    }
    return $build;
  }

  /**
   * Subsites log redirect callback.
   */
  public function log() {
    $_SESSION['dblog_overview_filter'] = array(
      'type' => array(
        'bc_subsites' => 'bc_subsites',
      ),
      'severity' => array(),
    );
    return RedirectResponse::create(Url::fromRoute('dblog.overview', [
      'type[]' => 'bc_subsites',
    ])->toString());
  }

}
