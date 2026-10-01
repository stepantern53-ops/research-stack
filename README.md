# research-stack — self-hosted поисковая система для omp

Self-hosted **SearXNG** в Docker как поисковый бэкенд для агента [omp](https://github.com/can1357/oh-my-pi) и других LLM-агентов.

- **Безлимитный метапоиск** — десятки движков (Google, Bing, DuckDuckGo, Brave, Wikipedia и др.) через один endpoint.
- **0 ₽, без API-ключей** — всё работает локально, ключи не нужны.
- **JSON API** — отдает структурированные результаты, готовые для LLM-агента.

## Архитектура

```
omp (роль web)
 └─► SearXNG  http://localhost:8080
      ├─ Docker Compose: searxng-core + valkey (кэш)
      ├─ метапоиск по десяткам движков
      └─ formats: [html, json]  ← JSON API включён в settings.yml
```

- **searxng-core** — сам SearXNG, порт `8080` (настраивается `SEARXNG_PORT`).
- **valkey** — кэш SearXNG (official compose-схема).
- JSON-формат разрешён в `searxng/core-config/settings.yml` (секция `search.formats`).

## Установка

Предварительно: **Docker Desktop**.

```powershell
powershell -File start.ps1   # запустить Docker Desktop, дождаться демона, docker compose up -d, проверка JSON API
```

Или вручную:

```powershell
cd searxng
copy .env.example .env       # опционально: зафиксировать SEARXNG_VERSION/PORT
docker compose up -d
```

Проверка (ожидаем JSON с `"results"`):

```powershell
curl.exe -s "http://localhost:8080/search?q=test&format=json"
```

Остановка:

```powershell
powershell -File stop.ps1    # docker compose stop
```

## Установка ИИ-агентом (для LLM-агентов)

Если ты LLM-агент и ставишь систему по этому README — выполняй шаги по порядку, после каждого проверяй ожидаемый результат. Отклонение = раздел «Troubleshooting» ниже. Кроме Docker ничего устанавливать не нужно, API-ключи не нужны.

**Шаг 0 — проверка Docker.** Команда `docker --version` → ожидаем строку версии. Если ошибка/демон не отвечает: запусти Docker Desktop и опрашивай `docker ps` каждые 10 сек до успеха (лимит ожидания 5 минут).

**Шаг 1 — клон и файлы.** `git clone https://github.com/stepantern53-ops/research-stack.git && cd research-stack`, затем `cd searxng` и скопируй `.env.example` → `.env` (Windows: `copy`, Linux/macOS: `cp`). Наполнение .env не требуется.

**Шаг 2 — запуск.** `docker compose up -d` → ожидаем два контейнера: searxng-core (порт 8080) и searxng-valkey (без порта наружу). Проверка: `docker compose ps` — оба status Up/running.

**Шаг 3 — проверка JSON API.** `curl -s "http://localhost:8080/search?q=test&format=json"` → ожидаем JSON с непустым полем `results`.

**Шаг 4 — интеграция в omp (только для агентов omp).** Скопируй три блока из `omp-config/config.yml` (searxng / modelRoles.web / retry.fallbackChains.web) в `~/.omp/agent/config.yml` (глобально) или `<проект>/.omp/config.yml` (только для проекта). Перезапусти omp-сессию. Проверка: тул `web_search` возвращает источники; провайдер в ответе — SearXNG.

**Troubleshooting:**
- JSON-запрос возвращает 403 → в `searxng/core-config/settings.yml` секция `search.formats` должна содержать `json` (в этом репо уже содержит) → после правки `docker compose restart`.
- Порт 8080 занят → в `searxng/.env` раскомментируй и поменяй `SEARXNG_PORT`, затем `docker compose up -d`; не забудь поменять порт в omp-конфиге.
- 429 на JSON-запросах → убедись, что `server.limiter: false` (в этом репо так по умолчанию; лимитер нужен только для публичных инстансов).
- Движки отдают 0 результатов → upstream-движки периодически ломаются; обнови образ: `docker compose pull && docker compose up -d`.

## Интеграция в omp

Пример — см. `omp-config/config.yml`. Три куска конфига omp:

```yaml
searxng:
  endpoint: "http://localhost:8080"   # нативный слот поиска omp

modelRoles:
  web: web/searxng                    # роль web по умолчанию — SearXNG

retry:
  fallbackChains:
    web:                              # если SearXNG недоступен — цепочка провайдеров
      - web/exa
      - web/tavily
      - web/duckduckgo
      - web/public
```

Поиск omp идёт через нативный слот `searxng.endpoint` — MCP-серверы для этого не нужны. Fallback-провайдеры (exa/tavily/duckduckgo/public) сработают, только если локальный SearXNG не отвечает.

## Обновление и откат

- Обновление образа: `cd searxng && docker compose pull && docker compose up -d`.
- Фиксация версии: раскомментируйте `SEARXNG_VERSION` в `searxng/.env` и укажите тег (например `2026.3.25-541c6c3cb`) — иначе по умолчанию `latest`.
- Откат настроек: правьте `searxng/core-config/settings.yml` и `docker compose restart` (файл смонтирован как volume).
- Полная остановка/удаление: `stop.ps1`, затем при необходимости `docker compose down -v` (удалит и кэш-valkey).

## Структура файлов

```
research-stack/
├── searxng/
│   ├── docker-compose.yml          # searxng-core + valkey
│   ├── .env.example                # шаблон переменных (версия/порт)
│   ├── .env                        # локальный, в git не попадает
│   └── core-config/settings.yml    # конфиг SearXNG (formats: json)
├── omp-config/
│   └── config.yml                  # пример интеграции поиска в omp
├── start.ps1                       # запуск (Docker Desktop → compose up → проверка)
├── stop.ps1                        # остановка
├── .gitignore
└── README.md
```
