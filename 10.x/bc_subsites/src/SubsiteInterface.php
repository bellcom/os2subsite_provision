<?php

namespace Drupal\bc_subsites;

use Drupal\Core\Entity\ContentEntityInterface;
use Drupal\Core\Entity\EntityChangedInterface;

/**
 * Provides an interface defining a Subsite entity.
 *
 * We have this interface so we can join the other interfaces it extends.
 *
 * @ingroup bc_subsites
 */
interface SubsiteInterface extends ContentEntityInterface, EntityChangedInterface {

}
