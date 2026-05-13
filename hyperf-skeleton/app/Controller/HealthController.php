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

use PhpOffice\PhpSpreadsheet\Spreadsheet;
use Psr\Http\Message\ResponseInterface as PsrResponseInterface;

class HealthController extends AbstractController
{
    /**
     * 健康检查：确认服务可响应，并校验 Excel 相关依赖（PhpSpreadsheet）已安装且可被自动加载。
     */
    public function index(): array|PsrResponseInterface
    {
        // 若 Composer 已安装 phpoffice/phpspreadsheet，则 Spreadsheet 类应存在。
        $excelInstalled = class_exists(Spreadsheet::class);

        $payload = [
            'status' => $excelInstalled ? 'ok' : 'error',
            'excel' => [
                'package' => 'phpoffice/phpspreadsheet',
                'installed' => $excelInstalled,
            ],
        ];

        // 缺少 Excel 库时返回 503，便于编排/探针区分「进程活着」与「依赖缺失」。
        if (! $excelInstalled) {
            return $this->response->json($payload)->withStatus(503);
        }

        return $payload;
    }
}
