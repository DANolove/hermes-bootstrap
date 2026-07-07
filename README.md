# Hermes Agent — /HANDOFF Bootstrap

> **5 минут до первого запуска.** Одна команда — вся инфраструктура.

```bash
curl -fsSL https://hermes.sh | bash
```

Или сохрани `bootstrap.sh`, заполни API ключи — готово.

## Что внутри

| Компонент | Назначение |
|-----------|-----------|
| **Hermes Agent** | CLI для управления агентами |
| **Groq** | Основной провайдер subagent'ов (бесплатно, llama-3.3-70b) |
| **GitHub Models** | Бесплатный fallback (gpt-4o-mini, 150 req/день) |
| **Qdrant** | Векторная память (unified_memory) |
| **Dashboard** | Web-интерфейс на порту 9090 |
| **427 skills** | Набор навыков для любых задач |

## Требования

- Linux / macOS / WSL2
- Docker
- Python 3.11+
- 2GB RAM, 10GB disk

## Быстрый старт

```bash
# 1. Установка
curl -fsSL https://hermes.sh | bash

# 2. Заполни ключи
nano ~/.hermes/.env

# 3. Запуск
hermes
```

## API ключи

Получить:

| Провайдер | Зачем | Получить |
|-----------|-------|----------|
| Groq | Основной subagent | https://console.groq.com/keys |
| GitHub | Бесплатный fallback | https://github.com/settings/tokens |
| OpenRouter | Резерв (опционально) | https://openrouter.ai/keys |

## Архитектура

```
Пользователь → Hermes CLI
                  │
            ┌─────┴─────┐
            │           │
        Subagent'ы   DeepSeek (диалог)
            │
      ┌─────┼─────┐
      │     │     │
    Groq  GitHub OpenRouter
   (беспл.)(беспл.)(:free)
```

## После установки

- `hermes` — запуск сессии
- `hermes dashboard` — открыть Dashboard
- `hermes insights` — статистика использования
- `cronjob action=list` — посмотреть активные задачи

## Для прода

- [ ] Cloudflare Worker прокси (чтобы не раскрывать IP)
- [ ] Obsidian vault для долговременной памяти
- [ ] Telegram/WhatsApp/Discord интеграция
