<?php

namespace App\Annotation;

use Attribute;
use Symfony\Component\HttpFoundation\Response;

#[Attribute]
class HttpCacheable
{
    public function __construct(public int $maxAge)
    {
    }
}
