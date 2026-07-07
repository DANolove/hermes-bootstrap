// Hermes API Proxy v5 — Groq + GitHub fallback
// Cloudflare Worker — защищает API ключи от геоблокировки
// Ключи вшиты через KV или env (настраивается в Cloudflare Dashboard)

const PROVIDERS = {
  groq: {
    base_url: 'https://api.groq.com/openai/v1',
    env_key: 'GROQ_API_KEY',
    priority: 1,
  },
  github: {
    base_url: 'https://models.github.ai/inference',
    env_key: 'GITHUB_TOKEN',
    priority: 2,
  },
};

// Fallback chain: Groq → GitHub
// Если Groq падает — автоматически пробуем GitHub (бесплатно)
const FALLBACK_CHAIN = ['groq', 'github'];

export default {
  async fetch(request) {
    const url = new URL(request.url);
    const path = url.pathname;

    // Health
    if (path === '/health') {
      return new Response(JSON.stringify({
        status: 'ok',
        providers: Object.keys(PROVIDERS),
        fallback: FALLBACK_CHAIN,
      }), { headers: { 'Content-Type': 'application/json' } });
    }

    // CORS preflight
    if (request.method === 'OPTIONS') {
      return new Response(null, {
        headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
          'Access-Control-Allow-Headers': 'Content-Type, Authorization',
        },
      });
    }

    // Парсинг пути: /v1/{provider}/{action}
    const match = path.match(/\/v1\/(\w+)\/(.+)/);
    if (!match) return new Response('Not found', { status: 404 });

    const provider = match[1];
    const action = match[2];
    const config = PROVIDERS[provider];

    if (!config) return new Response(`Unknown provider: ${provider}`, { status: 400 });

    // Пробуем провайдера + fallback chain
    const body = request.method === 'POST' ? await request.json() : null;

    // Определяем порядок попыток
    const chain = [provider, ...FALLBACK_CHAIN.filter(p => p !== provider)];

    let lastError = null;
    for (const p of chain) {
      const cfg = PROVIDERS[p];
      if (!cfg) continue;

      const apiKey = globalThis[cfg.env_key] || (typeof process !== 'undefined' ? process.env?.[cfg.env_key] : null);
      if (!apiKey) {
        lastError = `${p}: no API key`;
        continue;
      }

      try {
        const targetUrl = action === 'chat/completions'
          ? `${cfg.base_url}/chat/completions`
          : `${cfg.base_url}/${action}`;

        const headers = {
          'Authorization': `Bearer ${apiKey}`,
          'Content-Type': 'application/json',
        };

        // Очистка сообщений от неизвестных полей
        if (body?.messages) {
          body.messages = body.messages.map(m => {
            const { timestamp, observed, ...clean } = m;
            return clean;
          });
        }

        const resp = await fetch(targetUrl, {
          method: request.method,
          headers,
          body: body ? JSON.stringify(body) : null,
        });

        if (resp.ok) {
          // Успех — возвращаем результат
          const responseHeaders = new Headers(resp.headers);
          responseHeaders.set('X-Fallback-Provider', p);
          responseHeaders.set('Access-Control-Allow-Origin', '*');
          return new Response(resp.body, {
            status: resp.status,
            headers: responseHeaders,
          });
        }

        // Если провайдер вернул 4xx/5xx — пробуем следующий
        const errorText = await resp.text();
        lastError = `${p}: HTTP ${resp.status}`;
        console.log(`Fallback from ${p} to next: ${resp.status} ${errorText.slice(0, 100)}`);

      } catch (e) {
        lastError = `${p}: ${e.message}`;
        console.log(`Fallback from ${p}: ${e.message}`);
      }
    }

    // Все провайдеры упали
    return new Response(JSON.stringify({
      error: { message: `All providers failed: ${lastError}`, code: 503 },
    }), {
      status: 503,
      headers: { 'Content-Type': 'application/json', 'Access-Control-Allow-Origin': '*' },
    });
  },
};
