# Shuba69 Processor

This optional service lets the Shosetsu extension delegate chapter fetch, decode, cleanup, and translation work to a VPS.

It exposes one JSON endpoint:

```json
{"action":"chapter_html","url":"https://www.69shuba.com/txt/12345/67890","referer":"https://www.69shuba.com/book/12345/"}
```

and:

```json
{"action":"translate_html","html":"<p>...</p>","source":"zh-CN","target":"en"}
```

and:

```json
{"action":"search","query":"斗破苍穹"}
```

## Run

```bash
cd processor
python3 -m venv .venv
. .venv/bin/activate
pip install -r requirements.txt
export PROCESSOR_TOKEN='change-me'
export GOOGLE_TRANSLATE_KEY='your-google-translate-html-key'
uvicorn shuba69_processor:app --host 0.0.0.0 --port 8787
```

Then set these constants near the top of `src/zh/Shuba69.lua`:

```lua
local processorURL = "https://your-vps.example.com/"
local processorToken = "change-me"
```

Put the service behind HTTPS before using it from a phone. If `GOOGLE_TRANSLATE_KEY` is not set, the service returns cleaned original chapter HTML without translating it.

The service does not solve access challenges. If the upstream returns a JavaScript/cookie challenge instead of chapter HTML, the processor returns `upstream_challenge`; use only access methods you are authorized to use.
