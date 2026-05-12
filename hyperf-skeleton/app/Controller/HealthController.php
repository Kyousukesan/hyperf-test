<?php

declare(strict_types=1);
/**
 * This file is part of Hyperf.
 *
 * @link     https://www.hyperf.io
 * @document https://hyperf.wiki
 * @contact  group@hyperf.io
 * @license  https://github.com/hyperf/hyperf/blob/master/LICENSE
 */

namespace App\Controller;

class HealthController extends AbstractController
{
    public function index(): array
    {
        // 当前健康检查只确认 HTTP 服务进程可响应，不探测数据库、缓存等外部依赖。
        return [
            'status' => 'ok',
        ];
    }
}
