from __future__ import annotations

import base64
import io
import json
import logging
import os
from typing import Any

import httpx
from dotenv import load_dotenv
from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse, Response
from PIL import Image, ImageEnhance, ImageOps
from pydantic import BaseModel

load_dotenv()

LOGGER = logging.getLogger("karigarkart")
logging.basicConfig(level=logging.INFO, format="%(asctime)s | %(levelname)s | %(message)s")

GEMINI_MODEL = "gemini-3.5-flash-lite"
GEMINI_IMAGE_MODEL = "gemini-3.1-flash-image"

app = FastAPI(title="KarigarKart AI Backend", version="1.4.1")
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


class CatalogRequest(BaseModel):
    artisan_text: str | None = None
    description: str | None = None
    text: str | None = None
    language: str = "English"
    category: str | None = None
    raw_material_cost: float = 0
    image_base64: str | None = None


class PricingRequest(BaseModel):
    description: str | None = None
    text: str | None = None
    category: str | None = None
    image_base64: str | None = None
    raw_material_cost: float = 0
    labor_hours: float = 0
    labor_rate: float = 0
    labor_cost: float = 0


def _gemini_api_key() -> str:
    return os.getenv("GEMINI_API_KEY", "").strip()


def _gemini_url() -> str:
    return f"https://generativelanguage.googleapis.com/v1beta/models/{GEMINI_MODEL}:generateContent"


def _interactions_url() -> str:
    return "https://generativelanguage.googleapis.com/v1beta/interactions"


async def _gemini(
    prompt: str,
    *,
    image: bytes | None = None,
    mime: str = "image/jpeg",
    max_tokens: int = 800,
) -> str:
    api_key = _gemini_api_key()
    if not api_key:
        raise RuntimeError("GEMINI_API_KEY is not configured")

    parts: list[dict[str, Any]] = [{"text": prompt}]
    if image:
        parts.append(
            {
                "inline_data": {
                    "mime_type": mime,
                    "data": base64.b64encode(image).decode("ascii"),
                }
            }
        )

    body = {
        "contents": [{"parts": parts}],
        "generationConfig": {"temperature": 0.35, "maxOutputTokens": max_tokens},
    }

    async with httpx.AsyncClient(timeout=90) as client:
        response = await client.post(
            _gemini_url(),
            headers={"x-goog-api-key": api_key, "Content-Type": "application/json"},
            json=body,
        )
        if response.status_code >= 400:
            raise RuntimeError(
                f"Gemini HTTP {response.status_code}: {response.text[:500]}"
            )
        data = response.json()
        try:
            return data["candidates"][0]["content"]["parts"][0]["text"]
        except (KeyError, IndexError, TypeError) as exc:
            raise RuntimeError("Gemini returned no text") from exc


async def _gemini_image_edit(raw: bytes, mime: str, prompt: str) -> bytes:
    api_key = _gemini_api_key()
    if not api_key:
        raise RuntimeError("GEMINI_API_KEY is not configured")

    body = {
        "model": GEMINI_IMAGE_MODEL,
        "input": [
            {"type": "text", "text": prompt},
            {
                "type": "image",
                "mime_type": mime,
                "data": base64.b64encode(raw).decode("ascii"),
            },
        ],
        "response_format": {
            "type": "image",
            "mime_type": "image/jpeg",
            "aspect_ratio": "1:1",
            "image_size": "1K",
        },
    }

    async with httpx.AsyncClient(timeout=180) as client:
        response = await client.post(
            _interactions_url(),
            headers={
                "x-goog-api-key": api_key,
                "Content-Type": "application/json",
            },
            json=body,
        )
        if response.status_code >= 400:
            raise RuntimeError(
                f"Gemini image HTTP {response.status_code}: {response.text[:800]}"
            )

    data = response.json()
    output_image = data.get("output_image")
    if isinstance(output_image, dict):
        encoded = output_image.get("data")
        if isinstance(encoded, str) and encoded:
            return base64.b64decode(encoded)

    steps = data.get("steps")
    if isinstance(steps, list):
        for step in reversed(steps):
            if not isinstance(step, dict) or step.get("type") != "model_output":
                continue
            content = step.get("content")
            if not isinstance(content, list):
                continue
            for block in reversed(content):
                if not isinstance(block, dict) or block.get("type") != "image":
                    continue
                encoded = block.get("data")
                if isinstance(encoded, str) and encoded:
                    return base64.b64decode(encoded)

    raise RuntimeError("Gemini image model returned no generated image")


def _json_from_text(text: str) -> dict[str, Any]:
    cleaned = text.strip()
    if cleaned.startswith("```"):
        lines = cleaned.split("\n")
        cleaned = "\n".join(lines[1:]) if len(lines) > 1 else cleaned
        if cleaned.endswith("```"):
            cleaned = cleaned[:-3].strip()
    start = cleaned.find("{")
    end = cleaned.rfind("}")
    if start < 0 or end <= start:
        raise ValueError("AI did not return JSON")
    value = json.loads(cleaned[start : end + 1])
    if not isinstance(value, dict):
        raise ValueError("AI JSON was not an object")
    return value


def _decode_data_uri(value: str) -> tuple[bytes, str]:
    if not value:
        return b"", "image/jpeg"
    if value.startswith("data:") and "," in value:
        header, encoded = value.split(",", 1)
        mime = header[5:].split(";", 1)[0] or "image/jpeg"
    else:
        encoded, mime = value, "image/jpeg"
    return base64.b64decode(encoded), mime


def _catalog_result(data: dict[str, Any], source: str) -> dict[str, Any]:
    title = str(data.get("title_en") or data.get("title") or source[:70]).strip()
    description = str(data.get("desc_en") or data.get("description") or source).strip()
    regional_title = str(data.get("title_regional") or title).strip()
    regional_description = str(data.get("desc_regional") or description).strip()
    bullets = data.get("bullets_en")
    if not isinstance(bullets, list):
        bullets = [source]

    return {
        "title": title,
        "description": description,
        "category": str(data.get("category") or "Handmade").strip(),
        "estimated_price": int(data.get("estimated_price") or data.get("price") or 0),
        "title_en": title,
        "desc_en": description,
        "title_regional": regional_title,
        "desc_regional": regional_description,
        "bullets_en": [str(item) for item in bullets[:5]],
        "bullets_hi": [str(item) for item in (data.get("bullets_hi") or bullets)[:5]],
    }


@app.get("/")
async def root():
    return {"service": "KarigarKart AI Backend", "status": "healthy"}


@app.get("/health")
async def health():
    return {"status": "healthy", "gemini_configured": bool(_gemini_api_key())}


@app.post("/ai/transcribe")
async def transcribe(request: Request):
    try:
        content_type = request.headers.get("content-type", "")
        file = None
        audio = b""
        language = "English"
        mime = "audio/m4a"

        if "multipart/form-data" in content_type:
            async with request.form() as form:
                value = form.get("file")
                if value is not None and hasattr(value, "read"):
                    file = value
                language = str(form.get("language") or "English")
        elif "application/json" in content_type:
            payload = await request.json()
            encoded = payload.get("audio_base64", "")
            try:
                audio = base64.b64decode(encoded)
            except Exception as exc:
                raise HTTPException(status_code=400, detail="Invalid audio data") from exc
            mime = payload.get("audio_mime", "audio/m4a")
            language = str(payload.get("language") or "English")
        else:
            raise HTTPException(status_code=400, detail="Audio is required")

        if file is not None:
            audio = await file.read()
            mime = getattr(file, "content_type", None) or "audio/m4a"

        if not audio:
            raise HTTPException(status_code=400, detail="Audio is required")
        if len(audio) > 12 * 1024 * 1024:
            raise HTTPException(status_code=413, detail="Audio is too large")

        prompt = (
            "Transcribe this artisan voice recording accurately. "
            f"Language: {language}. Return only the spoken text, with no commentary."
        )
        text = await _gemini(prompt, image=audio, mime=mime, max_tokens=500)
        return {"success": True, "text": text.strip()}
    except HTTPException:
        raise
    except Exception as exc:
        LOGGER.exception("Transcription failed")
        return JSONResponse(status_code=500, content={"success": False, "detail": str(exc)})


@app.post("/ai/catalog")
async def catalog(payload: CatalogRequest):
    source = (payload.artisan_text or payload.description or payload.text or "").strip()
    if not source:
        raise HTTPException(status_code=400, detail="Product description is required")

    prompt = (
        "Create an e-commerce listing for a handmade artisan product from this "
        f"description: {source}\n"
        f"Language requested: {payload.language}. Category: {payload.category or 'handmade'}.\n"
        "Return ONLY JSON with keys: title_en, desc_en, title_regional, "
        "desc_regional, bullets_en, bullets_hi, category, estimated_price. "
        "bullets must be arrays of 3-5 short strings. estimated_price must be a positive integer in INR."
    )
    try:
        text = await _gemini(prompt, max_tokens=900)
        data = _json_from_text(text)
        result = _catalog_result(data, source)
        return {"success": True, "result": result, "catalog": data}
    except Exception as exc:
        LOGGER.exception("Catalog generation failed")
        fallback = _catalog_result(
            {
                "title_en": source[:70],
                "desc_en": source,
                "title_regional": source[:70],
                "desc_regional": source,
                "bullets_en": [source],
                "bullets_hi": [source],
                "category": payload.category or "Handmade",
                "estimated_price": 0,
            },
            source,
        )
        return {
            "success": True,
            "result": fallback,
            "catalog": {
                "title_en": fallback["title_en"],
                "desc_en": fallback["desc_en"],
                "title_regional": fallback["title_regional"],
                "desc_regional": fallback["desc_regional"],
                "bullets_en": fallback["bullets_en"],
                "bullets_hi": fallback["bullets_hi"],
            },
            "fallback": True,
            "message": str(exc),
        }


@app.post("/ai/pricing")
async def pricing(payload: PricingRequest):
    source = (payload.description or payload.text or "").strip()
    if not source:
        raise HTTPException(status_code=400, detail="Product description is required")

    cost_floor = payload.raw_material_cost + (
        payload.labor_cost or payload.labor_hours * payload.labor_rate
    )
    prompt = (
        "You are a pricing analyst for handmade Indian artisan products. "
        "Use both the supplied product photograph and the product description. "
        f"Description: {source}. "
        f"Category: {payload.category or 'handmade'}. "
        f"Raw material cost: ₹{payload.raw_material_cost:.0f}. "
        f"Labor: {payload.labor_hours:.1f} hours at ₹{payload.labor_rate:.0f}/hour. "
        f"Calculated cost floor: ₹{cost_floor:.0f}. "
        "Assess visible craft complexity, finish, apparent quality, category, labor intensity, "
        "and market positioning. Return ONLY JSON with: "
        "suggested_price, b2b_price, b2c_price, low_price, high_price, reasoning. "
        "All prices must be positive integer INR values and consistent with the cost floor."
    )
    try:
        image = None
        mime = "image/jpeg"
        if payload.image_base64:
            image, mime = _decode_data_uri(payload.image_base64)
        data = _json_from_text(
            await _gemini(prompt, image=image, mime=mime, max_tokens=700)
        )

        suggested = int(float(data.get("suggested_price", 0)))
        b2b = int(float(data.get("b2b_price", suggested * 0.85)))
        b2c = int(float(data.get("b2c_price", suggested)))
        low = int(float(data.get("low_price", min(b2b, b2c))))
        high = int(float(data.get("high_price", max(b2b, b2c))))

        minimum_allowed = max(int(cost_floor * 1.05), 199)
        suggested = max(suggested, minimum_allowed)
        b2b = max(b2b, minimum_allowed)
        b2c = max(b2c, suggested)
        low = max(low, minimum_allowed)
        high = max(high, b2c)

        return {
            "success": True,
            "suggested_price": suggested,
            "b2b_price": b2b,
            "b2c_price": b2c,
            "price_range": {"low": low, "high": high},
            "reasoning": str(data.get("reasoning", "")).strip(),
            "cost_floor": round(cost_floor),
            "fallback": False,
        }
    except Exception as exc:
        fallback = max(int(cost_floor * 1.25), 199)
        return {
            "success": True,
            "suggested_price": fallback,
            "b2b_price": max(int(fallback * 0.9), int(cost_floor)),
            "b2c_price": fallback,
            "price_range": {
                "low": max(int(cost_floor * 1.15), 199),
                "high": max(int(fallback * 1.2), 249),
            },
            "reasoning": "Fallback benchmark based on your supplied material and labour cost.",
            "fallback": True,
            "message": str(exc),
        }


@app.post("/ai/enhance")
async def enhance(request: Request):
    try:
        content_type = request.headers.get("content-type", "")
        raw = b""
        background_color = "white"
        enhance_lighting = "true"
        output_aspect_ratio = "1:1"

        if "multipart/form-data" in content_type:
            async with request.form() as form:
                value = form.get("file") or form.get("image")
                if value is not None and hasattr(value, "read"):
                    raw = await value.read()
                background_color = str(form.get("background_color") or "white")
                enhance_lighting = str(form.get("enhance_lighting") or "true")
                output_aspect_ratio = str(form.get("output_aspect_ratio") or "1:1")
        elif "application/json" in content_type:
            payload = await request.json()
            raw, _ = _decode_data_uri(str(payload.get("image_base64") or ""))
            background_color = str(payload.get("background_color") or "white")
            enhance_lighting = str(payload.get("enhance_lighting") or "true")
            output_aspect_ratio = str(payload.get("output_aspect_ratio") or "1:1")
        elif content_type.startswith("image/"):
            raw = await request.body()
        else:
            raise HTTPException(status_code=400, detail="Image is required")

        if not raw:
            raise HTTPException(status_code=400, detail="Image is empty")
        if len(raw) > 12 * 1024 * 1024:
            raise HTTPException(status_code=413, detail="Image is too large")

        try:
            source = Image.open(io.BytesIO(raw))
            source = ImageOps.exif_transpose(source).convert("RGB")
        except Exception as exc:
            raise HTTPException(status_code=422, detail="Invalid image file") from exc

        normalized = io.BytesIO()
        source.thumbnail((1600, 1600), Image.Resampling.LANCZOS)
        source.save(normalized, format="JPEG", quality=94, optimize=True)
        normalized_bytes = normalized.getvalue()

        background_instruction = (
            "Place the product on a clean pure white studio background. "
            if background_color.lower() == "white"
            else "Place the product on a clean neutral studio background. "
        )
        lighting_instruction = (
            "Improve lighting, white balance, exposure, shadows, sharpness, and fine detail. "
            if enhance_lighting.lower() == "true"
            else "Preserve the existing lighting while improving clarity and detail. "
        )
        aspect_instruction = (
            "Compose the final image as a centered 1:1 square product photograph. "
            if output_aspect_ratio.strip() == "1:1"
            else f"Use a {output_aspect_ratio} product-photo composition. "
        )

        prompt = (
            "Edit the provided artisan product photograph into a polished e-commerce product photo. "
            "This is an IMAGE EDIT, not a new product design. Preserve the exact identity, shape, "
            "materials, colors, patterns, proportions, and important handmade details of the original product. "
            "Do not add extra products, text, logos, people, props, or decorative objects. "
            f"{background_instruction}{lighting_instruction}{aspect_instruction}"
            "Remove distracting background clutter while keeping the complete product visible. "
            "Create realistic natural edges and contact shadows, with a clean professional marketplace look. "
            "Do not invent or materially alter the product itself."
        )

        try:
            generated = await _gemini_image_edit(normalized_bytes, "image/jpeg", prompt)
            result = Image.open(io.BytesIO(generated))
            result = ImageOps.exif_transpose(result).convert("RGB")
            output = io.BytesIO()
            result.save(output, format="JPEG", quality=92, optimize=True)
            return Response(
                content=output.getvalue(),
                media_type="image/jpeg",
                headers={
                    "Cache-Control": "no-store",
                    "X-KarigarKart-Enhancement": "gemini-image-edit",
                },
            )
        except Exception as exc:
            LOGGER.exception("Gemini image enhancement failed")
            raise HTTPException(status_code=502, detail=f"AI image enhancement failed: {exc}") from exc
    except HTTPException:
        raise
    except Exception as exc:
        LOGGER.exception("Enhance failed")
        raise HTTPException(status_code=500, detail="Image enhancement failed") from exc
