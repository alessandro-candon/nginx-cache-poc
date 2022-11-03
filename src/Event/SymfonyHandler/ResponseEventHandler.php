<?php

declare(strict_types=1);

namespace App\Event\SymfonyHandler;

use App\Annotation\HttpCacheable;
use Closure;
use ReflectionClass;
use ReflectionException;
use ReflectionFunction;
use Symfony\Component\EventDispatcher\EventSubscriberInterface;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\HttpKernel\Event\ControllerEvent;
use Symfony\Component\HttpKernel\Event\ResponseEvent;
use Symfony\Component\HttpKernel\Event\ViewEvent;
use Symfony\Component\HttpKernel\KernelEvents;

use function assert;
use function explode;
use function is_array;
use function is_string;

class ResponseEventHandler implements EventSubscriberInterface
{
    const CACHEABLE_ATTRIBUTE_KEY = '_cacheable_attribute';

    /**
     * Name getSubscribedEvents
     *
     * @return string[]
     */
    public static function getSubscribedEvents(): array
    {
        return [
            KernelEvents::RESPONSE   => 'onResponse',
            KernelEvents::CONTROLLER => 'onController',
        ];
    }

    public function onResponse(ResponseEvent $event): void
    {
        $request = $event->getRequest();
        $response = $event->getResponse();
        $viewAttribute = $request->attributes->get(self::CACHEABLE_ATTRIBUTE_KEY);

        if (! $viewAttribute instanceof HttpCacheable) {
            return;
        }

        $response
            ->setPublic()
            ->setMaxAge($viewAttribute->maxAge);

        $response->headers->set('X-Webserver-Cache', "true");
    }

    /**
     * @throws ReflectionException
     */
    public function onController(ControllerEvent $event): void
    {
        $controller = $event->getController();

        $request = $event->getRequest();

        if ($controller instanceof Closure) {
            $reflector = new ReflectionFunction($controller);
        } elseif (is_array($controller)) {
            $reflectorClass = new ReflectionClass($controller[0]);
            $reflector = $reflectorClass->getMethod($controller[1]);
        } else {
            $reflectorClass = new ReflectionClass($controller); // @phpstan-ignore-line
            $reflector = $reflectorClass->getMethod('__invoke');
        }

        foreach ($reflector->getAttributes(HttpCacheable::class) as $reflectionAttribute) {
            $attribute = $reflectionAttribute->newInstance();
            $request->attributes->set(self::CACHEABLE_ATTRIBUTE_KEY, $attribute);
        }
    }
}
