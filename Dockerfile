FROM node:20-slim AS node_proxy_builder

WORKDIR /build/node-proxy

COPY node-proxy/package.json node-proxy/package-lock.json ./
RUN npm ci --omit=dev

COPY node-proxy/server.mjs ./


FROM python:3.11-slim

LABEL maintainer="anyrouter2proxy"
LABEL version="3.0.0"
LABEL description="AnyRouter2Proxy - Anthropic/OpenAI Protocol Proxy (Node.js SDK Mode)"

WORKDIR /app

RUN apt-get update && apt-get install -y \
    ca-certificates \
    curl \
    libstdc++6 \
    && rm -rf /var/lib/apt/lists/*

COPY --from=node_proxy_builder /usr/local/bin/node /usr/local/bin/node
COPY --from=node_proxy_builder /build/node-proxy /app/node-proxy

COPY requirements.txt .
ARG PIP_INDEX_URL="https://pypi.org/simple"
RUN pip install --no-cache-dir -r requirements.txt --index-url="$PIP_INDEX_URL"

COPY anyrouter2anthropic.py .
COPY anyrouter2openai.py .
COPY docker-entrypoint.sh .

RUN chmod +x /app/docker-entrypoint.sh \
    && useradd -m -u 1000 appuser \
    && chown -R appuser:appuser /app
USER appuser

# 9998: Anthropic 代理端口
# 9999: OpenAI 代理端口
EXPOSE 9998 9999

ENV PYTHONUNBUFFERED=1
ENV HOST=0.0.0.0
ENV NODE_ENV=production

HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD sh -c 'curl -fsS "http://localhost:${PORT:-9998}/health" || curl -fsS "http://localhost:${OPENAI_PROXY_PORT:-9999}/health" || exit 1'

CMD ["/app/docker-entrypoint.sh"]
