<?php

namespace App\Controller;

use App\Annotation\HttpCacheable;
use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Component\HttpFoundation\JsonResponse;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\Routing\Annotation\Route;

class SoSlowController extends AbstractController
{

    #[HttpCacheable(maxAge: 3600)]
    #[Route('/cache', methods: [Request::METHOD_GET])]
    public function cache(): JsonResponse
    {
        $timeStart = time();
        sleep(2);
        return $this->json([
            'ok' => time() - $timeStart
        ]);
    }

    #[Route('/not-cached', methods: [Request::METHOD_GET])]
    public function notCached(): JsonResponse
    {
        $timeStart = time();
        sleep(2);
        return $this->json([
            'ok' => time() - $timeStart
        ]);
    }
}
