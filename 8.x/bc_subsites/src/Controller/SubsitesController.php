<?php
/**
 * @file
 * Contains Subsites controller definition.
 */

namespace Drupal\bc_subsites\Controller;

use Drupal\Component\Render\FormattableMarkup;
use Drupal\Core\Controller\ControllerBase;
use Symfony\Component\HttpFoundation\RedirectResponse;
use Drupal\Core\Url;

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
      return RedirectResponse::create(Url::fromRoute('entity.subsite.collection')->toString());
    }

    $build['inline_js'] = [
      '#type' => 'html_tag',
      '#tag' => 'script',
      '#value' => 'setTimeout(function () { location.reload(1); }, 5000);',
    ];

    foreach ($_SESSION['bc_subsite_pids'] as $pid => $log_file) {
      // Check if process is still running.
      $op = array();
      $command = 'ps -p ' . $pid;
      exec($command, $op);
      $log = file_get_contents($log_file);
      if (!isset($op[1])) {
        unset($_SESSION['bc_subsite_pids'][$pid]);

        // Load log and remove logfile.
        unlink($log_file);

        $message = new FormattableMarkup('Command pid: %pid, result: <pre>%log</pre>', [
          '%pid' => $pid,
          '%log' => $log
        ]);
        \Drupal::messenger()->addMessage($message);
        $logger = \Drupal::logger('bc_subsites');
        $logger->notice($message);
        return RedirectResponse::create(Url::fromRoute('entity.subsite.collection')->toString());
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
