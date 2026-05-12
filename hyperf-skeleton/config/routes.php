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
use Hyperf\HttpServer\Router\Router;

Router::addRoute(['GET', 'POST', 'HEAD'], '/', 'App\Controller\IndexController@index');

// 健康检查只用于确认当前服务可响应，暂不检查数据库、缓存等外部依赖。
Router::get('/health', 'App\Controller\HealthController@index');

Router::get('/favicon.ico', function () {
    return '';
});
