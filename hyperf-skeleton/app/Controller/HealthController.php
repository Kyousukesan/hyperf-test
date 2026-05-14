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

use OpenApi\Generator as OpenApiGenerator;
use PhpOffice\PhpSpreadsheet\Spreadsheet;
use Psr\Http\Message\ResponseInterface as PsrResponseInterface;

class HealthController extends AbstractController
{
    /**
     * 健康检查：确认服务可响应，并校验 Excel（PhpSpreadsheet）、OpenAPI 文档（swagger-php）等依赖可被自动加载。
     */
    public function index(): array|PsrResponseInterface
    {
        // PhpSpreadsheet 核心类存在即表示 phpoffice/phpspreadsheet 已安装。
        $excelInstalled = class_exists(Spreadsheet::class);
        // swagger-php 的生成器入口类在 OpenApi 命名空间下，存在即表示 zircote/swagger-php 已安装。
        $swaggerInstalled = class_exists(OpenApiGenerator::class);

        $allDepsOk = $excelInstalled && $swaggerInstalled;

        $payload = [
            'status' => $allDepsOk ? 'ok' : 'error',
            'excel' => [
                'package' => 'phpoffice/phpspreadsheet',
                'installed' => $excelInstalled,
            ],
            'swagger' => [
                'package' => 'zircote/swagger-php',
                'installed' => $swaggerInstalled,
            ],
        ];

        // 任一关键依赖缺失时返回 503，便于探针与「仅进程存活」区分。
        if (! $allDepsOk) {
            return $this->response->json($payload)->withStatus(503);
        }

        return $payload;
    }
}
