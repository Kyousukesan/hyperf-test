#!/usr/bin/env bash
# 发布完成后在目标机上执行：先关 Nginx 断流 -> 重启 Hyperf -> 健康检查 -> 再起 Nginx
# 用法：chmod +x reload-service.sh && ./reload-service.sh
# 也可由 Jenkins 通过 ssh 远程执行：bash /path/to/reload-service.sh

set -euo pipefail

# 兼容 Jenkins 非交互 ssh 环境
export XDG_RUNTIME_DIR=/run/user/$(id -u)
export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/dbus/system_bus_socket

# ---------------------------------------------------------------------------
# 可配置项（按实际环境修改；也可在调用前 export 覆盖默认值）
# ---------------------------------------------------------------------------

# Hyperf 的 systemd 单元名
SERVICE_NAME="${SERVICE_NAME:-hyperf.service}"

# Nginx 的 systemd 单元名
NGINX_SERVICE="${NGINX_SERVICE:-nginx.service}"

# 直连 Hyperf 做健康检查（不经 Nginx，因为重启过程中 Nginx 会停止）
HEALTH_URL="${HEALTH_URL:-http://127.0.0.1:9501/}"

# 老进程优雅退出约 130s，给 systemctl restart 留足上限（秒）
RESTART_TIMEOUT="${RESTART_TIMEOUT:-180}"

# 健康检查最大重试次数；每次间隔 HEALTH_RETRY_SLEEP 秒
HEALTH_RETRY_COUNT="${HEALTH_RETRY_COUNT:-30}"
HEALTH_RETRY_SLEEP="${HEALTH_RETRY_SLEEP:-2}"

# ---------------------------------------------------------------------------
# 非 root 且存在 sudo 时，对 systemctl 使用 sudo（Jenkins deploy 用户常见）
# root 或无 sudo 时直接使用 systemctl（与容器内 root 场景一致）
# ---------------------------------------------------------------------------

if command -v sudo >/dev/null 2>&1 && [ "$(id -u)" -ne 0 ]; then
  SUDO=(sudo)
else
  SUDO=()
fi

# ---------------------------------------------------------------------------
# 1. 停止 Nginx，关闭入口流量
# ---------------------------------------------------------------------------

echo "Stopping nginx to close entrance traffic"

"${SUDO[@]}" systemctl stop "$NGINX_SERVICE"

# 确认 Nginx 已不在 active 状态
if "${SUDO[@]}" systemctl is-active --quiet "$NGINX_SERVICE"; then
  echo "ERROR: nginx is still active"
  "${SUDO[@]}" systemctl status "$NGINX_SERVICE" --no-pager || true
  exit 1
fi

echo "Nginx stopped"

# ---------------------------------------------------------------------------
# 2. 重启 Hyperf（会加载 current 指向的新代码）
# ---------------------------------------------------------------------------

echo "Restarting Hyperf service"

if ! timeout "$RESTART_TIMEOUT" "${SUDO[@]}" systemctl restart "$SERVICE_NAME"; then
  echo "ERROR: service restart failed or timeout"
  "${SUDO[@]}" systemctl status "$SERVICE_NAME" --no-pager || true
  exit 1
fi

# 确认 Hyperf 处于 active
if ! "${SUDO[@]}" systemctl is-active --quiet "$SERVICE_NAME"; then
  echo "ERROR: service is not active"
  "${SUDO[@]}" systemctl status "$SERVICE_NAME" --no-pager || true
  exit 1
fi

echo "Service is active"

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
  "${SUDO[@]}" systemctl status "$SERVICE_NAME" --no-pager || true
  exit 1
fi

# ---------------------------------------------------------------------------
# 4. 启动 Nginx，恢复入口流量
# ---------------------------------------------------------------------------

echo "Starting nginx to open entrance traffic"

"${SUDO[@]}" systemctl start "$NGINX_SERVICE"

if ! "${SUDO[@]}" systemctl is-active --quiet "$NGINX_SERVICE"; then
  echo "ERROR: nginx is not active"
  "${SUDO[@]}" systemctl status "$NGINX_SERVICE" --no-pager || true
  exit 1
fi

echo "Reload service success"