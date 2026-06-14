# Hermes Swarm

A self-hostable **multi-agent swarm server** with a real-time dashboard. Each
agent is a full [Hermes](https://github.com/NousResearch/hermes-agent) agent —
it can browse the web, run a terminal, write files, and publish to live
platforms — and agents collaborate peer-to-peer on a shared project. You watch
and steer the whole team from one web UI.

- **Live execution view** — see each agent think → call tools → answer, in real time.
- **Per-agent config** — model, provider, tools, reasoning, iterations, sampling — from the UI.
- **Self-aware agents** — agents can read their own config/telemetry and *propose* changes for your approval.
- **Human inbox** — agents ask you for logins/decisions; you reply from the dashboard.

> **New here?** The **[Getting Started guide](docs/getting-started.md)** walks
> you from download through building and running your first team. Exposing it on
> a server? See **[Deploying on a VPS](docs/deploy-vps.md)**.

---

## Prerequisites

1. **An OpenAI-compatible LLM endpoint + API key** — e.g. [OpenRouter](https://openrouter.ai),
   OpenAI, or your own [LiteLLM](https://github.com/BerriAI/litellm) proxy.
2. **Docker** *(option A)* **or Python 3.11+** *(option B)*.

You do **not** need to install Hermes separately — it comes in automatically
(see [Already have Hermes?](#already-have-hermes) if you do).

---

## Option A — Docker (recommended)

```bash
git clone <this-repo> hermes-swarm && cd hermes-swarm
cp .env.example .env          # then edit .env: set SWARM_LLM_BASE_URL + SWARM_LLM_API_KEY
docker compose up --build
```

Open **http://127.0.0.1:8000**. The image bundles Python, Hermes, Chromium, and
the dashboard; your data persists in the `swarm-data` volume.

> Pointing at an LLM proxy running on your **host** machine? Use
> `SWARM_LLM_BASE_URL=http://host.docker.internal:4000/v1` in `.env`.

---

## Option B — pip

```bash
python3 -m venv .venv && source .venv/bin/activate   # Python 3.11+
pip install .                       # pulls hermes-agent + deps
playwright install chromium         # for the browser-publishing tools

export SWARM_LLM_BASE_URL=https://openrouter.ai/api/v1
export SWARM_LLM_API_KEY=sk-...
export SWARM_DEFAULT_MODEL=openai/gpt-4o-mini

hermes-swarm doctor                 # check Hermes + model backend + Chromium
hermes-swarm init                   # scaffold a starter team + coordinator agent
hermes-swarm up                     # serve the dashboard on http://127.0.0.1:8000
```

---

## Already have Hermes?

If you already use Hermes (`~/.hermes/`), the swarm reuses the same agent
runtime. Resolution order: the pip-installed `hermes-agent`, else
`HERMES_AGENT_PATH`, else `~/.hermes/hermes-agent`. Run `hermes-swarm doctor` to
confirm what it found.

---

## Configuration (environment variables)

| Variable | Default | Purpose |
|---|---|---|
| `SWARM_LLM_BASE_URL` | `http://127.0.0.1:4000/v1` | OpenAI-compatible LLM endpoint |
| `SWARM_LLM_API_KEY` | `sk-1234` | key for that endpoint |
| `SWARM_DEFAULT_MODEL` | `litellm-model` | default model for new agents |
| `SWARM_FALLBACK_MODELS` | `litellm-model,kimi` | dropdown list if the backend can't be queried |
| `SWARM_HOST` / `SWARM_PORT` | `127.0.0.1` / `8000` | dashboard bind address |
| `SWARM_API_KEY` | *(unset)* | if set, required on **every** endpoint + WebSocket — the dashboard prompts for it once and remembers it. **Set it whenever you expose the port.** |
| `SWARM_DATA_DIR` | repo `./data` or `~/.hermes-swarm/data` | writable state (configs, queues, workspaces) |
| `HERMES_AGENT_PATH` | *(unset)* | path to a Hermes source checkout (only if not pip-installed) |

Per-agent settings (model, provider, tools, reasoning, iterations, sampling,
soul, autonomous wake-up interval, and **cron wake-ups**) are edited live from
the dashboard's ⚙️ panel — no restart needed. `SWARM_HEARTBEAT_SECONDS` is just
the default; each agent's idle wake-up cadence can be overridden in its settings.

**Scheduled wake-ups (cron):** every agent can run recurring work on a schedule
— a 9am competitor check, an hourly metrics pull, a Monday digest. Add/enable/
delete schedules from the ⚙️ panel (5-field cron, `@hourly`/`@daily`/`@weekly`/
`@monthly`, or intervals like `@every 30m`); agents can also self-schedule and
cancel their own via the `schedule_wakeup` / `cancel_wakeup` tools.

---

## Notes

- **Security:** by default the server binds `127.0.0.1` with no key. To expose
  it (VPS/LAN), set `SWARM_API_KEY` — it then guards every HTTP endpoint *and*
  the WebSocket, and the dashboard prompts for the key once (stored in your
  browser). Put it behind a TLS reverse proxy too. Agents can run terminal
  commands as the server user, so on a shared/exposed host prefer the Docker
  route. See [`docs/deploy-vps.md`](docs/deploy-vps.md) for a hardened setup.
- **Chromium** is required only for the browser-publishing tools; everything
  else works without it (the swarm degrades gracefully).
- **Web research:** agents get `web_search` + `web_extract`. Search works with no
  setup (DuckDuckGo). For *extract*, if you've configured a Hermes web backend
  (Firecrawl/Tavily/Exa/… via `hermes tools` or API-key env vars) the swarm uses
  it untouched; otherwise it falls back to a built-in fetcher — `httpx` out of
  the box (fine for normal pages), or install `pip install .[web]` (crawl4ai +
  `playwright install chromium`) for JavaScript-heavy single-page apps.
- **Data & backups:** state lives in `SWARM_DATA_DIR`; every config save keeps a
  rotating backup under `<data>/config_backups/`.
