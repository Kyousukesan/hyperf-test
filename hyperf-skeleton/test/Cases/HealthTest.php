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

namespace HyperfTest\Cases;

use Hyperf\Testing\TestCase;

/**
 * @internal
 * @coversNothing
 */
class HealthTest extends TestCase
{
    public function testHealthCheckOnlyChecksService(): void
    {
        // 健康检查需确认 PhpSpreadsheet 已安装（响应体中带 excel.installed）。
        $this->get('/health')
            ->assertOk()
            ->assertExactJson([
                'status' => 'ok',
                'excel' => [
                    'package' => 'phpoffice/phpspreadsheet',
                    'installed' => true,
                ],
            ]);
    }
}
