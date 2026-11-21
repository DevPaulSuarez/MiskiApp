<?php

use Illuminate\Auth\AuthenticationException;
use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;
use Illuminate\Http\Request;
use Symfony\Component\HttpKernel\Exception\HttpExceptionInterface;

// API routes live inside each module (app/Modules/*/routes.php).
return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        web: __DIR__.'/../routes/web.php',
        commands: __DIR__.'/../routes/console.php',
        health: '/up',
    )
    ->withMiddleware(function (Middleware $middleware): void {
        $middleware->api(append: ['throttle:api']);
    })
    ->withExceptions(function (Exceptions $exceptions): void {
        $exceptions->shouldRenderJsonWhen(
            fn (Request $request) => $request->is('api/*') || $request->expectsJson(),
        );

        // Framework default messages are in English; the app shows these to people.
        $exceptions->render(function (AuthenticationException $e, Request $request) {
            if ($request->is('api/*')) {
                return response()->json(['message' => 'Tu sesión expiró. Vuelve a iniciar sesión.'], 401);
            }
        });
        $exceptions->render(function (HttpExceptionInterface $e, Request $request) {
            if (! $request->is('api/*')) {
                return null;
            }
            $status = $e->getStatusCode();
            $defaults = ['', 'This action is unauthorized.', 'Not Found', 'Too Many Attempts.'];
            $message = match (true) {
                $status === 404 => 'No encontramos lo que buscabas.',
                in_array($e->getMessage(), $defaults, true) || str_starts_with($e->getMessage(), 'No query results') => match ($status) {
                    403 => 'No tienes permiso para hacer esto.',
                    429 => 'Demasiados intentos. Espera un momento.',
                    default => null,
                },
                default => $e->getMessage(),
            };

            return $message === null ? null : response()->json(['message' => $message], $status, $e->getHeaders());
        });
    })->create();
