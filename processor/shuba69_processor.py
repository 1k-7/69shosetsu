import html
import json
import os
from typing import Any
from urllib.parse import urlparse

import httpx
from bs4 import BeautifulSoup
from fastapi import FastAPI, Header, HTTPException


app = FastAPI(title="Shuba69 processor")

SOURCE_HOSTS = {
    host.strip().lower()
    for host in os.getenv("SOURCE_HOSTS", "69shuba.com,www.69shuba.com").split(",")
    if host.strip()
}
PROCESSOR_TOKEN = os.getenv("PROCESSOR_TOKEN", "")
GOOGLE_TRANSLATE_KEY = os.getenv("GOOGLE_TRANSLATE_KEY", "")
TRANSLATE_ENDPOINT = os.getenv(
    "TRANSLATE_ENDPOINT",
    "https://translate-pa.googleapis.com/v1/translateHtml",
)

USER_AGENT = os.getenv(
    "FETCH_USER_AGENT",
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 "
    "(KHTML, like Gecko) Chrome/126 Safari/537.36",
)


def require_token(authorization: str | None) -> None:
    if not PROCESSOR_TOKEN:
        return
    expected = f"Bearer {PROCESSOR_TOKEN}"
    if authorization != expected:
        raise HTTPException(status_code=401, detail="invalid_token")


def assert_allowed_source(url: str) -> None:
    parsed = urlparse(url)
    if parsed.scheme not in {"http", "https"}:
        raise HTTPException(status_code=400, detail="invalid_url")
    if parsed.hostname is None or parsed.hostname.lower() not in SOURCE_HOSTS:
        raise HTTPException(status_code=400, detail="blocked_host")


def decode_response(response: httpx.Response) -> str:
    content_type = response.headers.get("content-type", "").lower()
    candidates: list[str] = []
    if "gbk" in content_type or "gb2312" in content_type or "gb18030" in content_type:
        candidates.extend(["gb18030", "utf-8"])
    else:
        candidates.extend(["utf-8", "gb18030"])

    for encoding in candidates:
        text = response.content.decode(encoding, errors="replace")
        if "\ufffd" not in text:
            return text
    return response.content.decode(candidates[-1], errors="replace")


def is_challenge_html(value: str) -> bool:
    lower = value.lower()
    return (
        "enable javascript and cookies to continue" in lower
        or ("just a moment" in lower and "cf_chl" in lower)
        or "challenge-platform" in lower
    )


def clean_text(value: str) -> str:
    return " ".join(value.split()).strip()


def html_paragraphs(paragraphs: list[str]) -> str:
    return "".join(f"<p>{html.escape(paragraph)}</p>" for paragraph in paragraphs if paragraph)


async def fetch_source_html(url: str, referer: str = "") -> str:
    assert_allowed_source(url)
    headers = {
        "User-Agent": USER_AGENT,
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
        "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.8",
    }
    if referer:
        headers["Referer"] = referer
    async with httpx.AsyncClient(headers=headers, follow_redirects=True, timeout=30) as client:
        response = await client.get(url)
        response.raise_for_status()
        return decode_response(response)


def extract_chapter(source_html: str) -> tuple[str, list[str]]:
    if is_challenge_html(source_html):
        raise HTTPException(status_code=502, detail="upstream_challenge")

    soup = BeautifulSoup(source_html, "lxml")
    chapter = soup.select_one(".txtnav")
    if chapter is None:
        chapter = soup.select_one("#content, .content, .chaptercontent, .read-content")
    if chapter is None:
        raise HTTPException(status_code=422, detail="chapter_not_found")

    title_node = chapter.select_one("h1") or soup.select_one("h1")
    title = clean_text(title_node.get_text(" ")) if title_node else ""

    for selector in (
        "script",
        "style",
        "iframe",
        "ins",
        ".yueduad1",
        "#txtright",
        ".txtinfo",
        ".tools",
        ".readpage",
        ".jubao",
        ".hide720",
        ".setbox",
        ".ad",
        "[id*=ad]",
        "[class*=ad]",
        "a[href*=javascript]",
    ):
        for node in chapter.select(selector):
            node.decompose()

    lines = [clean_text(line) for line in chapter.get_text("\n").splitlines()]
    paragraphs = [line for line in lines if line]
    if title and paragraphs and paragraphs[0] == title:
        paragraphs.pop(0)
    return title, paragraphs


def normalize_translated_html(decoded: Any) -> str | None:
    if not isinstance(decoded, list) or not decoded:
        return None
    first = decoded[0]
    if isinstance(first, list):
        fragments = []
        for fragment in first:
            text = str(fragment)
            if "<p" in text.lower() or "<br" in text.lower() or "<h1" in text.lower():
                fragments.append(text)
            else:
                fragments.append(f"<p>{html.escape(text)}</p>")
        return "".join(fragments)
    if isinstance(first, str):
        if "<p" in first.lower() or "<br" in first.lower() or "<h1" in first.lower():
            return first
        return f"<p>{html.escape(first)}</p>"
    return None


async def translate_html(source_html: str, source: str, target: str) -> str:
    if not source_html or not GOOGLE_TRANSLATE_KEY:
        return source_html

    payload = [[source_html, source, target], "wt_lib"]
    headers = {
        "Content-Type": "application/json+protobuf",
        "X-Goog-Api-Key": GOOGLE_TRANSLATE_KEY,
    }
    async with httpx.AsyncClient(timeout=30) as client:
        response = await client.post(TRANSLATE_ENDPOINT, headers=headers, json=payload)
        response.raise_for_status()
        translated = normalize_translated_html(response.json())
    return translated or source_html


@app.get("/health")
async def health() -> dict[str, str]:
    return {"status": "ok"}


@app.post("/")
async def process(payload: dict[str, Any], authorization: str | None = Header(default=None)) -> dict[str, str]:
    require_token(authorization)

    action = payload.get("action")
    source = str(payload.get("source") or "zh-CN")
    target = str(payload.get("target") or "en")

    if action == "translate_html":
        source_html = str(payload.get("html") or "")
        return {"html": await translate_html(source_html, source, target)}

    if action == "chapter_html":
        url = str(payload.get("url") or "")
        referer = str(payload.get("referer") or "")
        if referer:
            assert_allowed_source(referer)
        source_html = await fetch_source_html(url, referer)
        title, paragraphs = extract_chapter(source_html)
        body = html_paragraphs(paragraphs)
        translated_body = await translate_html(body, source, target)
        title_html = f"<h1>{html.escape(title)}</h1>" if title else ""
        return {"html": title_html + translated_body}

    raise HTTPException(status_code=400, detail="unknown_action")


if __name__ == "__main__":
    import uvicorn

    port = int(os.getenv("PORT", "8787"))
    uvicorn.run("shuba69_processor:app", host="0.0.0.0", port=port)
