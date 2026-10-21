# ai-control

The one-word control for the local AI stack on the phone.

```
ai go       start the engine (and the telegram bridge when it is configured)
ai stop     stop everything ai started
ai status   what is running right now
ai logs     tail a log:  ai logs server | ai logs bot | ai logs model
ai ask      ask the model, right here in the terminal
ai web      serve the single-file chat page (the fallback app)
ai build    build the engine natively on this phone
ai model    download the model
ai resume   finish whatever the phone lost (model, build) and start
ai update   git pull every project
ai doctor   check the stack
```

## Install

```bash
bash install.sh
```

It creates the one root folder (`~/ai`), writes `~/ai/etc/ai.env`, clones the
projects and links `ai` into `~/bin/ai` (already on the Termux PATH).

## The one root

```
~/ai/
├── bin/ai              -> this command
├── etc/ai.env          -> the configuration (KEY=VALUE)
├── models/             -> the .gguf models
├── build/              -> the native build tree (bmoe-server, bmoe-cli)
├── logs/               -> one log per service
├── run/                -> pid files
└── projects/           -> one folder per project, each its own git repo
    ├── ai-control/     <- this repo
    ├── bmoe-termux/    <- native Termux build of the engine
    └── telegram-agent/ <- telegram bridge
```

## The apps that talk to the engine

The engine speaks the OpenAI API on `http://127.0.0.1:8765/v1`, so anything
that speaks OpenAI can use it:

| app | how |
|---|---|
| the upstream web UI | built by `ai build`, opened at `http://127.0.0.1:8765/` |
| the chat page | `ai web`, opened at `http://127.0.0.1:8766/` - one file, works on the phone and on the wifi |
| the terminal | `ai ask "what is the capital of Peru"` |
| opencode | add a provider with baseURL `http://<phone>:8765/v1` |
| Chatbox, LobeChat, Enchanted, Jan, Open WebUI | point the base URL at `http://<phone>:8765/v1` |

## Configuration

`~/ai/etc/ai.env` is sourced by the command, so it can hold anything a shell
can use:

| key | meaning |
|---|---|
| `AI_MODEL_FILE` | the gguf the engine loads |
| `AI_HOST` / `AI_PORT` | where the OpenAI-compatible server listens |
| `AI_API_KEY` | key the server asks for (empty = none) |
| `AI_SERVER_ARGS` | extra flags for the engine, `--auto` by default |
| `AI_TELEGRAM_TOKEN` | bot token; the bridge starts only when this is set |
| `AI_TELEGRAM_USER_ID` | your telegram id; only you are answered |
