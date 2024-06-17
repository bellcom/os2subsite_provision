<?php
/**
 * @file
 * Contains \Drupal\bc_subsites\EventSubscriber\SubsiteRedirectSubscriber.
 */

namespace Drupal\bc_subsites\EventSubscriber;

use Symfony\Component\EventDispatcher\EventSubscriberInterface;
use Drupal\Core\Routing\TrustedRedirectResponse;
use Symfony\Component\HttpKernel\Event\GetResponseEvent;
use Symfony\Component\HttpKernel\KernelEvents;

/**
 * Class SubsiteRedirectSubscriber.
 */
class SubsiteRedirectSubscriber implements EventSubscriberInterface {

  /**
   * {@inheritdoc}
   */
  public static function getSubscribedEvents() {
    return [
      KernelEvents::REQUEST => [
        ['redirectSubsite'],
      ]
    ];
  }

  /**
   * Redirect requests for subsite entity view.
   *
   * @param \Symfony\Component\HttpKernel\Event\GetResponseEvent $event
   *   Response object.
   */
  public function redirectSubsite(GetResponseEvent $event) {
    $request = $event->getRequest();

    if ($request->attributes->get('_route') !== 'entity.subsite.canonical') {
      return;
    }

    $subsite = $request->attributes->get('subsite');
    $response = new TrustedRedirectResponse('http://' . $subsite->getDomain());
    $event->setResponse($response);
  }

}
