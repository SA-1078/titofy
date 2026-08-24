# Titofy — Copyright (C) 2026 Titofy
# Licensed under GNU General Public License v3.0 or later.

"""
normalizer.py — Limpieza y Normalización de Consultas de Letras
"""

import re
import os
import unicodedata


# Patrones de ruido comunes en títulos de canciones / nombres de archivo
NOISE_PATTERNS = [
    r"\((?:official\s*(?:video|audio|music\s*video|lyric\s*video)|video\s*oficial|audio\s*oficial|letra|lyrics)\)",
    r"\[(?:official\s*(?:video|audio|music\s*video|lyric\s*video)|video\s*oficial|audio\s*oficial|letra|lyrics)\]",
    r"\((?:remastered|remaster|remasterizado|anniversary\s*edition|deluxe\s*edition|bonus\s*track)\s*\d*\)",
    r"\[(?:remastered|remaster|remasterizado|anniversary\s*edition|deluxe\s*edition|bonus\s*track)\s*\d*\]",
    r"\((?:live|en\s*vivo|acoustic|en\s*directo|acustico)\s*\d*\)",
    r"\[(?:live|en\s*vivo|acoustic|en\s*directo|acustico)\s*\d*\]",
    r"[\(\[](?:mp3|flac|wav|m4a|aac|ogg|wma)[_\-\s]*\d+k?\w*[\)\]]",
    r"[\(\[]\d+\s*k(?:bps)?[\)\]]",
    r"[\(\[](?:4k|hd|hq|1080p|720p|480p|360p|audio|video)[_\-\s\w]*[\)\]]",
    r"[\(\[]\d{3,4}p[_\-\s\w]*[\)\]]",
    r"-\s*(?:single\s*version|radio\s*edit|album\s*version|original\s*mix)",
]


COMPILED_NOISE_PATTERNS = [re.compile(p, re.IGNORECASE) for p in NOISE_PATTERNS]

FEAT_PATTERN = re.compile(
    r"(?:\s*[\(\[]?\s*(?:feat\.?|ft\.?|featuring)\s+[^()\[\]]+[\)\]]?)",
    re.IGNORECASE,
)

TRACK_NUM_PATTERN = re.compile(r"^\s*\d{1,3}\s*[-._\s]\s*")


def clean_query(text: str | None) -> str:
    """
    Limpia un texto (título o artista) removiendo sufijos publicitarios,
    etiquetas de remaster, live, video oficial, tasas de bitrate (MP3_160K) y features.
    """
    if not text:
        return ""

    cleaned = str(text)

    # Remover patrones de ruido
    for pattern in COMPILED_NOISE_PATTERNS:
        cleaned = pattern.sub("", cleaned)

    # Remover "feat. / ft."
    cleaned = FEAT_PATTERN.sub("", cleaned)

    # Reemplazar guiones bajos aislados entre palabras por espacios
    cleaned = re.sub(r"(?<=\w)_(?=\w)", " ", cleaned)

    # Limpiar paréntesis o corchetes vacíos resultantes
    cleaned = re.sub(r"[\(\[]\s*[\)\]]", "", cleaned)

    # Colapsar espacios múltiples y recortar
    cleaned = re.sub(r"\s+", " ", cleaned).strip()

    return cleaned



def normalize_for_match(text: str | None) -> str:
    """
    Normaliza un texto para comparación o clave de caché:
    - Minúsculas
    - Remueve acentos y diacríticos (ej. 'Canción' -> 'cancion')
    - Remueve caracteres especiales y puntuación
    - Colapsa espacios
    """
    if not text:
        return ""

    cleaned = clean_query(text).lower()

    # Descomponer diacríticos (NFD) y remover marcas no espaciadas
    nfkd_form = unicodedata.normalize("NFKD", cleaned)
    without_accents = "".join(c for c in nfkd_form if not unicodedata.combining(c))

    # Conservar solo caracteres alfanuméricos y espacios
    alphanumeric_only = re.sub(r"[^\w\s]", " ", without_accents)

    # Colapsar espacios múltiples
    return re.sub(r"\s+", " ", alphanumeric_only).strip()


def round_duration(duration: float | int | None) -> int | None:
    """
    Redondea la duración a segundos enteros para evitar duplicados en caché
    por pequeñas discrepancias de milisegundos.
    """
    if duration is None:
        return None
    try:
        val = float(duration)
        if val <= 0:
            return None
        return int(round(val))
    except (ValueError, TypeError):
        return None


def extract_artist_title_from_filename(filepath_or_name: str) -> tuple[str | None, str]:
    """
    Intenta extraer (artista, título) a partir del nombre de un archivo de audio.
    Ejemplos:
      "Queen - Bohemian Rhapsody.mp3" -> ("Queen", "Bohemian Rhapsody")
      "01 - Bohemian Rhapsody.mp3"     -> (None, "Bohemian Rhapsody")
      "Imagine.mp3"                    -> (None, "Imagine")
    """
    base = os.path.basename(filepath_or_name)
    name_without_ext, _ = os.path.splitext(base)

    # Quitar número de pista inicial si existe ("01 - Song" -> "Song")
    name_cleaned = TRACK_NUM_PATTERN.sub("", name_without_ext)

    # Buscar separadores estándar " - " o " _ "
    if " - " in name_cleaned:
        parts = name_cleaned.split(" - ", 1)
        artist = clean_query(parts[0])
        title = clean_query(parts[1])
        return (artist if artist else None, title if title else name_cleaned)
    elif " _ " in name_cleaned:
        parts = name_cleaned.split(" _ ", 1)
        artist = clean_query(parts[0])
        title = clean_query(parts[1])
        return (artist if artist else None, title if title else name_cleaned)

    title = clean_query(name_cleaned)
    return (None, title if title else name_without_ext)


def split_artists(raw_artist: str | None) -> list[str]:
    """
    Separa múltiples artistas colaboradores.
    Ej: 'Silvestre Dangond_ NATTI NATASHA' -> ['Silvestre Dangond', 'NATTI NATASHA']
    Soporta separadores: _, ,, /, |, &, and, y, x, feat., ft., with.
    """
    if not raw_artist:
        return []
    cleaned = clean_query(raw_artist)
    pattern = r"[\,_/|]|\s+(?:&|and|y|x|feat\.?|ft\.?|featuring|with)\s+"
    parts = re.split(pattern, cleaned, flags=re.IGNORECASE)
    return [p.strip() for p in parts if p.strip()]


def generate_search_variations(artist: str | None, title: str) -> list[dict[str, str]]:
    """
    Genera combinaciones y permutaciones optimizadas para consultas a APIs de letras:
    1. Artista principal + Título
    2. Todos los artistas formateados ('A, B' y 'A & B') + Título
    3. Cada colaborador individual + Título
    4. Búsqueda combinada por texto ('Título Artista', 'Artista Título')
    """
    clean_t = clean_query(title)
    if not clean_t:
        return []

    variations: list[dict[str, str]] = []
    seen: set[str] = set()

    def add_var(a: str, t: str, q: str):
        key = f"{a.lower()}::{t.lower()}::{q.lower()}"
        if key not in seen:
            seen.add(key)
            variations.append({"artist": a, "title": t, "query": q})

    artists = split_artists(artist) if artist else []

    if artists:
        primary = artists[0]
        # 1. Artista principal + Título
        add_var(primary, clean_t, f"{primary} {clean_t}".strip())

        # 2. Todos los artistas juntos
        if len(artists) > 1:
            all_joined = ", ".join(artists)
            amp_joined = " & ".join(artists)
            space_joined = " ".join(artists)
            add_var(all_joined, clean_t, f"{space_joined} {clean_t}".strip())
            add_var(amp_joined, clean_t, f"{amp_joined} {clean_t}".strip())

            # 3. Colaboradores secundarios
            for sec in artists[1:]:
                add_var(sec, clean_t, f"{sec} {clean_t}".strip())

        # 4. Título primero
        add_var(primary, clean_t, f"{clean_t} {primary}".strip())
    else:
        add_var("", clean_t, clean_t)

    return variations

