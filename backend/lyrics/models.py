# Titofy — Copyright (C) 2026 Titofy
# Licensed under GNU General Public License v3.0 or later.

"""
models.py — Modelos y Contratos de Datos para Letras Sincronizadas
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field, asdict
from enum import Enum
from typing import Any


class LyricSource(str, Enum):
    ONLINE_SYNCED = "online_synced"       # Nivel 1: Sincronizada desde proveedor online (ej. LRCLIB)
    ONLINE_ALIGNED = "online_aligned"     # Nivel 2: Texto plano online + Forced Alignment local
    AI_GENERATED = "ai_generated"         # Nivel 3: Whisper local de audio completo
    CACHE = "cache"                       # Letra recuperada del caché local


@dataclass
class LyricWord:
    text: str
    start: float
    end: float

    def to_dict(self) -> dict[str, Any]:
        return {
            "text": self.text,
            "start": round(self.start, 3),
            "end": round(self.end, 3),
        }

    @classmethod
    def from_dict(cls, d: dict[str, Any]) -> LyricWord:
        return cls(
            text=str(d.get("text", "")),
            start=float(d.get("start", 0.0)),
            end=float(d.get("end", 0.0)),
        )


@dataclass
class LyricLine:
    text: str
    start: float | None = None
    end: float | None = None
    words: list[LyricWord] = field(default_factory=list)

    def to_dict(self) -> dict[str, Any]:
        sec = round(self.start, 3) if self.start is not None else None
        return {
            "text": self.text,
            "start": sec,
            "time": sec if sec is not None else 0.0,  # Campo dual para garantizar compatibilidad con Flutter
            "end": round(self.end, 3) if self.end is not None else None,
            "words": [w.to_dict() for w in self.words] if self.words else [],
        }

    @classmethod
    def from_dict(cls, d: dict[str, Any]) -> LyricLine:
        words_data = d.get("words", [])
        words = [LyricWord.from_dict(w) for w in words_data] if words_data else []
        raw_start = d.get("start") if d.get("start") is not None else d.get("time")
        return cls(
            text=str(d.get("text", "")),
            start=float(raw_start) if raw_start is not None else None,
            end=float(d["end"]) if d.get("end") is not None else None,
            words=words,
        )


@dataclass
class LyricData:
    title: str
    artist: str
    duration: int | None = None
    language: str | None = None
    source: LyricSource = LyricSource.ONLINE_SYNCED
    lines: list[LyricLine] = field(default_factory=list)
    plain_lyrics: str | None = None
    album: str | None = None
    provider: str | None = None
    metadata: dict[str, Any] = field(default_factory=dict)

    @property
    def is_synced(self) -> bool:
        """Indica si la letra contiene timestamps válidos y sincronizados en el tiempo."""
        if not self.lines:
            return False
        # Para considerarse sincronizada, debe haber al menos una línea con timestamp mayor a 0
        return any(l.start is not None and l.start > 0.0 for l in self.lines)

    def get_plain_text(self) -> str:
        """Retorna la letra en formato texto plano."""
        if self.plain_lyrics:
            return self.plain_lyrics
        return "\n".join(line.text for line in self.lines if line.text.strip())

    def to_lrc(self) -> str:
        """Exporta la letra en formato estándar .lrc."""
        header_lines = [
            f"[ti:{self.title}]" if self.title else "",
            f"[ar:{self.artist}]" if self.artist else "",
            f"[al:{self.album}]" if self.album else "",
            f"[by:Titofy ({self.source.value})]" if self.source else "",
            "",
        ]
        out_lines = [h for h in header_lines if h]

        for line in self.lines:
            text = line.text.strip()
            if not text:
                continue
            if line.start is not None:
                mins = int(line.start // 60)
                secs = line.start % 60
                ts = f"[{mins:02d}:{secs:05.2f}]"
                out_lines.append(f"{ts}{text}")
            else:
                out_lines.append(text)

        return "\n".join(out_lines)

    def to_dict(self) -> dict[str, Any]:
        return {
            "title": self.title,
            "artist": self.artist,
            "duration": self.duration,
            "language": self.language,
            "source": self.source.value if isinstance(self.source, LyricSource) else str(self.source),
            "lines": [line.to_dict() for line in self.lines],
            "plain_lyrics": self.plain_lyrics or self.get_plain_text(),
            "album": self.album,
            "provider": self.provider,
            "metadata": self.metadata,
            "is_synced": self.is_synced,
            "raw_lrc": self.to_lrc(),
        }

    @classmethod
    def from_dict(cls, d: dict[str, Any]) -> LyricData:
        source_val = d.get("source", LyricSource.ONLINE_SYNCED.value)
        try:
            source = LyricSource(source_val)
        except ValueError:
            source = LyricSource.ONLINE_SYNCED

        lines_data = d.get("lines", [])
        lines = [LyricLine.from_dict(line) for line in lines_data]

        return cls(
            title=str(d.get("title", "")),
            artist=str(d.get("artist", "")),
            duration=int(d["duration"]) if d.get("duration") is not None else None,
            language=d.get("language"),
            source=source,
            lines=lines,
            plain_lyrics=d.get("plain_lyrics"),
            album=d.get("album"),
            provider=d.get("provider"),
            metadata=d.get("metadata", {}),
        )

    @classmethod
    def from_lrc_string(
        cls,
        lrc_text: str,
        title: str = "",
        artist: str = "",
        duration: int | None = None,
        source: LyricSource = LyricSource.ONLINE_SYNCED,
        language: str | None = None,
        album: str | None = None,
        provider: str | None = None,
    ) -> LyricData:
        """Parsea una cadena LRC estándar a una instancia de LyricData."""
        lines: list[LyricLine] = []
        parsed_title = title
        parsed_artist = artist
        parsed_album = album

        ts_pattern = re.compile(r"^\[(\d{1,2}):(\d{2}(?:\.\d{1,3})?)\](.*)$")
        tag_pattern = re.compile(r"^\[([a-zA-Z]+):(.*)\]$")

        raw_lines = lrc_text.splitlines()
        for raw_line in raw_lines:
            raw_line = raw_line.strip()
            if not raw_line:
                continue

            # Detectar tags [ti:...], [ar:...], [al:...]
            tag_match = tag_pattern.match(raw_line)
            if tag_match:
                tag, val = tag_match.group(1).lower(), tag_match.group(2).strip()
                if tag == "ti" and not parsed_title:
                    parsed_title = val
                elif tag == "ar" and not parsed_artist:
                    parsed_artist = val
                elif tag == "al" and not parsed_album:
                    parsed_album = val
                continue

            # Detectar timestamps
            ts_match = ts_pattern.match(raw_line)
            if ts_match:
                mins = int(ts_match.group(1))
                secs = float(ts_match.group(2))
                start_sec = mins * 60 + secs
                text = ts_match.group(3).strip()
                lines.append(LyricLine(text=text, start=start_sec))
            else:
                # Línea sin timestamp
                lines.append(LyricLine(text=raw_line, start=None))

        # Calcular 'end' de cada línea basándose en el 'start' de la siguiente
        for i in range(len(lines)):
            curr_start = lines[i].start
            if curr_start is not None:
                next_start = lines[i + 1].start if (i + 1 < len(lines)) else None
                if next_start is not None:
                    lines[i].end = next_start
                elif duration is not None and float(duration) > curr_start:
                    lines[i].end = float(duration)
                else:
                    lines[i].end = curr_start + 4.0


        return cls(
            title=parsed_title,
            artist=parsed_artist,
            duration=duration,
            language=language,
            source=source,
            lines=lines,
            album=parsed_album,
            provider=provider,
        )
