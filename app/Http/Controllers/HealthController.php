<?php

namespace App\Http\Controllers;

use Illuminate\Http\JsonResponse;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Redis;
use Illuminate\Support\Facades\Storage;

class HealthController extends Controller
{
    public function __invoke(): JsonResponse
    {
        $checks = [
            'database' => $this->checkDatabase(),
            'redis' => $this->checkRedis(),
            'storage' => $this->checkStorage(),
        ];

        $healthy = collect($checks)->every(fn (bool $ok) => $ok);

        return response()->json([
            'status' => $healthy ? 'ok' : 'degraded',
            'checks' => $checks,
        ], $healthy ? 200 : 503);
    }

    private function checkDatabase(): bool
    {
        return rescue(fn () => DB::select('select 1') !== null, false);
    }

    private function checkRedis(): bool
    {
        return rescue(fn () => Redis::connection()->ping() === true, false);
    }

    private function checkStorage(): bool
    {
        return rescue(fn () => Storage::disk('local')->exists('.'), false);
    }
}
