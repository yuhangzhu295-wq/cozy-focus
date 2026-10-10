"""Probe whether this environment can actually generate an image.

RESULT, 2026-10-10: it cannot, and this is the evidence rather than a label.

  - Volcano Ark (https://ark.cn-beijing.volces.com/api/v3/images/generations) is
    REACHABLE - it answers, so this is not a network block - but
    VOLCANO_ENGINE_API_KEY is an `AKLT...` access-key *id* (91 chars), not an Ark
    bearer token. All three models answered HTTP 401 "The API key format is
    incorrect". An AK/SK pair would need Volcengine request signing and the secret
    key is not present.
  - OpenAI's images endpoint answered HTTP 401 "Incorrect API key provided" for
    OPENAI_API_KEY, for both gpt-image-1 and dall-e-3.

So the app has no image-generation path here. The room is drawn procedurally
instead, which is what every other piece of this app's art already does. Re-run
this file before recording "no asset" again - the answer is cheap to re-check and
the cost of assuming it is a whole pass spent not trying.

The project has recorded "no asset for a photographic room" as an external block
several times. Before accepting that again, this asks the only question that
matters: is there a reachable image-generation endpoint with a working key.

Prints the HTTP status and, on success, the size of what came back. Never prints
the key.
"""
import json
import os
import urllib.request

KEY = os.environ.get("VOLCANO_ENGINE_API_KEY", "")
if not KEY:
    raise SystemExit("VOLCANO_ENGINE_API_KEY is not set")

URL = "https://ark.cn-beijing.volces.com/api/v3/images/generations"
MODELS = [
    "doubao-seedream-3-0-t2i-250415",
    "doubao-seedream-4-0-250828",
    "high_aes_general_v30l_zt2i",
]

PROMPT = ("a cozy warm study room interior, soft afternoon light through a window, "
          "wooden desk in the foreground, a shelf with small potted plants, "
          "cream and sage green palette, soft focus background, no people, no text")

for model in MODELS:
    body = json.dumps({
        "model": model,
        "prompt": PROMPT,
        "size": "1024x1024",
        "response_format": "url",
        "watermark": False,
    }).encode()
    req = urllib.request.Request(
        URL, data=body,
        headers={"Authorization": f"Bearer {KEY}",
                 "Content-Type": "application/json"},
    )
    try:
        with urllib.request.urlopen(req, timeout=120) as resp:
            data = json.loads(resp.read().decode())
        item = (data.get("data") or [{}])[0]
        url = item.get("url", "")
        print(f"{model}: HTTP 200, image url length {len(url)}")
        print("  ", url[:120])
        break
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode()[:200]
        print(f"{model}: HTTP {exc.code} {detail}")
    except Exception as exc:                                  # noqa: BLE001
        print(f"{model}: {type(exc).__name__}: {exc}")
