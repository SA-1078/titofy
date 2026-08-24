# Titofy — Copyright (C) 2026 Titofy
# Licensed under GNU General Public License v3.0 or later.

"""
hallucination.py — Filtros de Alucinaciones Conocidas de Whisper.
"""

import re

HALLUCINATION_PATTERNS = [
    r"^letra de canci[oó]n",
    r"^transcripci[oó]n de la voz",
    r"^voz cantada",
    r"^paroles de chanson",
    r"^testo della canzone",
    r"^song lyrics",
    r"^precis(e|a) transcri",
    r"^gracias por ver$",
    r"^thanks for watching$",
    r"^thank you for watching$",
    r"^suscr[ií]bete",
    r"^subscribe",
    r"^subtítulos? (por|de|realizados)",
    r"^subtitulado por",
    r"^subtitles? (by|created by)",
    r"^captions? (by|created by)",
    r"^transcri(pc|p)ci[oó]n por",
    r"^transcribed by",
    r"^traducci[oó]n por",
    r"^translated by",
    r"^copyright",
    r"^todos los derechos reservados",
    r"^all rights reserved",
    r"^www\.",
    r"^http",
    r"^visita nuestro canal",
    r"^s[ií]guenos en",
    r"^follow us on",
    r"^\.{2,}$",
    r"^\*+$",
    r"^-+$",
    r"^[♪♫🎵🎶\s]+$",
    r"^(\w+\s*)\1{3,}",
    r"^¡?Suscr[ií]bete",
    r"^No te olvides de suscribirte",
    r"^Dale like",
    r"^Amigos de YouTube",
]



HALLUCINATION_REGEXES = [re.compile(p, re.IGNORECASE) for p in HALLUCINATION_PATTERNS]


def is_hallucination(text: str) -> bool:
    """Detecta si una línea es una alucinación conocida de Whisper."""
    clean = text.strip()
    if not clean:
        return True
    for regex in HALLUCINATION_REGEXES:
        if regex.search(clean):
            return True
    return False


def is_too_short(text: str, min_chars: int = 2) -> bool:
    """Líneas de 1-2 caracteres que no aportan nada."""
    clean = re.sub(r"[♪♫🎵🎶\s]", "", text.strip())
    return len(clean) < min_chars
