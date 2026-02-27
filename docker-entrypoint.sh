#!/bin/sh
set -eu

NODE_PROXY_PORT="${NODE_PROXY_PORT:-4000}"

if [ -z "${NODE_PROXY_URL:-}" ]; then
  export NODE_PROXY_URL="http://127.0.0.1:${NODE_PROXY_PORT}"
fi

echo "[entrypoint] starting node-proxy on :${NODE_PROXY_PORT}"
node /app/node-proxy/server.mjs &
node_pid="$!"

wait_node_ready() {
  i=0
  while [ "$i" -lt 50 ]; do
    if curl -fsS "http://127.0.0.1:${NODE_PROXY_PORT}/health" >/dev/null 2>&1; then
      return 0
    fi
    i=$((i + 1))
    sleep 0.2
  done
  return 1
}

if ! wait_node_ready; then
  echo "[entrypoint] node-proxy not reachable at http://127.0.0.1:${NODE_PROXY_PORT}/health" >&2
  kill "$node_pid" 2>/dev/null || true
  exit 1
fi

run_mode="${RUN_MODE:-}"
case "$run_mode" in
  anthropic)
    echo "[entrypoint] starting python proxy (anthropic) on :${PORT:-9998}"
    python3 /app/anyrouter2anthropic.py &
    ;;
  openai)
    echo "[entrypoint] starting python proxy (openai) on :${OPENAI_PROXY_PORT:-9999}"
    python3 /app/anyrouter2openai.py &
    ;;
  *)
    echo "[entrypoint] Please set RUN_MODE to \"anthropic\" or \"openai\"" >&2
    kill "$node_pid" 2>/dev/null || true
    exit 1
    ;;
esac

py_pid="$!"

term() {
  echo "[entrypoint] shutting down..."
  kill "$py_pid" 2>/dev/null || true
  kill "$node_pid" 2>/dev/null || true
  wait "$py_pid" 2>/dev/null || true
  wait "$node_pid" 2>/dev/null || true
}

trap term INT TERM

wait "$py_pid"
exit_code="$?"

kill "$node_pid" 2>/dev/null || true
wait "$node_pid" 2>/dev/null || true

exit "$exit_code"
