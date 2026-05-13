#!/usr/bin/env bash
# 发布完成后在目标机上执行：先关 Nginx 断流 -> 重启 Hyperf -> 健康检查 -> 再起 Nginx
# 用法：chmod +x reload-service.sh && ./reload-service.sh
# 也可由 Jenkins 通过 ssh 远程执行：bash /path/to/reload-service.sh
# 使用 supervisorctl 管理服务（替代 systemd）

set -euo pipefail

# ---------------------------------------------------------------------------
# 可配置项（按实际环境修改；也可在调用前 export 覆盖默认值）
# ---------------------------------------------------------------------------

# Hyperf 在 supervisor 中的进程名
SERVICE_NAME="${SERVICE_NAME:-hyperf}"

# Nginx 在 supervisor 中的进程名
NGINX_SERVICE="${NGINX_SERVICE:-nginx}"

# 直连 Hyperf 做健康检查（不经 Nginx，因为重启过程中 Nginx 会停止）
HEALTH_URL="${HEALTH_URL:-http://127.0.0.1:9501/health}"

# 老进程优雅退出约 130s，给 restart 留足上限（秒）
RESTART_TIMEOUT="${RESTART_TIMEOUT:-180}"

# 健康检查最大重试次数；每次间隔 HEALTH_RETRY_SLEEP 秒
HEALTH_RETRY_COUNT="${HEALTH_RETRY_COUNT:-30}"
HEALTH_RETRY_SLEEP="${HEALTH_RETRY_SLEEP:-2}"

# ---------------------------------------------------------------------------
# 辅助函数：检查 supervisor 进程是否处于 RUNNING 状态
# ---------------------------------------------------------------------------
is_running() {
  local name="$1"
  supervisorctl status "$name" 2>/dev/null | grep -q "RUNNING"
}

# ---------------------------------------------------------------------------
# 1. 停止 Nginx，关闭入口流量
# ---------------------------------------------------------------------------

echo "Stopping nginx to close entrance traffic"

supervisorctl stop "$NGINX_SERVICE"

# 确认 Nginx 已不在 RUNNING 状态
if is_running "$NGINX_SERVICE"; then
  echo "ERROR: nginx is still running"
  supervisorctl status "$NGINX_SERVICE" || true
  exit 1
fi

echo "Nginx stopped"

# ---------------------------------------------------------------------------
# 2. 重启 Hyperf（会加载 current 指向的新代码）
# ---------------------------------------------------------------------------

echo "Restarting Hyperf service"

# 使用 timeout 限制重启耗时，supervisorctl restart 会先 stop 再 start
if ! timeout "$RESTART_TIMEOUT" supervisorctl restart "$SERVICE_NAME"; then
  echo "ERROR: service restart failed or timeout"
  supervisorctl status "$SERVICE_NAME" || true
  exit 1
fi

# 确认 Hyperf 处于 RUNNING 状态
if ! is_running "$SERVICE_NAME"; then
  echo "ERROR: service is not running"
  supervisorctl status "$SERVICE_NAME" || true
  exit 1
fi

echo "Service is running"

# ---------------------------------------------------------------------------
# 3. 健康检查（重试直到 Hyperf 可访问）
# ---------------------------------------------------------------------------

echo "Checking service health: $HEALTH_URL"

for i in $(seq 1 "$HEALTH_RETRY_COUNT"); do
  if curl -fsS "$HEALTH_URL" >/dev/null; then
    echo "Health check passed"
    break
  fi

  echo "Health check failed, retry $i/$HEALTH_RETRY_COUNT"
  sleep "$HEALTH_RETRY_SLEEP"
done

# 最后一轮再确认，避免仅 break 前未真正通过
if ! curl -fsS "$HEALTH_URL" >/dev/null; then
  echo "ERROR: health check failed"
  supervisorctl status "$SERVICE_NAME" || true
  exit 1
fi

# ---------------------------------------------------------------------------
# 4. 启动 Nginx，恢复入口流量
# ---------------------------------------------------------------------------

echo "Starting nginx to open entrance traffic"

supervisorctl start "$NGINX_SERVICE"

# 确认 Nginx 已恢复 RUNNING 状态
if ! is_running "$NGINX_SERVICE"; then
  echo "ERROR: nginx is not running"
  supervisorctl status "$NGINX_SERVICE" || true
  exit 1
fi

echo "Reload service success"
