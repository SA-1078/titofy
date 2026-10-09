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
    r"\((?:official\s*(?:video|audio|music\s*video|lyric\s*video|visualizer)|video\s*oficial|audio\s*oficial|video\s*con\s*letra|letra\s*oficial|visualizer|letra|lyrics)\)",
    r"\[(?:official\s*(?:video|audio|music\s*video|lyric\s*video|visualizer)|video\s*oficial|audio\s*oficial|video\s*con\s*letra|letra\s*oficial|visualizer|letra|lyrics)\]",
    r"【(?:official\s*(?:video|audio|music\s*video|lyric\s*video)|video\s*oficial|mv|pv|letra)】",
    r"「(?:official\s*(?:video|audio|music\s*video|lyric\s*video)|video\s*oficial|mv|pv|letra)」",
    r"\((?:remastered|remaster|remasterizado|anniversary\s*edition|deluxe\s*edition|bonus\s*track|\d{4}\s*remaster)\s*\d*\)",
    r"\[(?:remastered|remaster|remasterizado|anniversary\s*edition|deluxe\s*edition|bonus\s*track|\d{4}\s*remaster)\s*\d*\]",
    r"\((?:live|en\s*vivo|acoustic|en\s*directo|acustico|acoustic\s*version|live\s*at\s*[^()\[\]]+)\s*\d*\)",
    r"\[(?:live|en\s*vivo|acoustic|en\s*directo|acustico|acoustic\s*version|live\s*at\s*[^()\[\]]+)\s*\d*\]",
    r"\((?:slowed\s*(?:\+|and|&)\s*reverb|sped\s*up|speed\s*up|nightcore)\)",
    r"\[(?:slowed\s*(?:\+|and|&)\s*reverb|sped\s*up|speed\s*up|nightcore)\]",
    r"\((?:prod\.?|produced\s*by)\s+[^()\[\]]+\)",
    r"\[(?:prod\.?|produced\s*by)\s+[^()\[\]]+\]",
    r"[\(\[](?:mp3|flac|wav|m4a|aac|ogg|wma)[_\-\s]*\d+k?\w*[\)\]]",
    r"[\(\[]\d+\s*k(?:bps)?[\)\]]",
    r"[\(\[](?:4k|hd|hq|1080p|720p|480p|360p|audio|video)[_\-\s\w]*[\)\]]",
    r"[\(\[]\d{3,4}p[_\-\s\w]*[\)\]]",
    r"-\s*(?:single\s*version|radio\s*edit|album\s*version|original\s*mix|extended\s*mix|deluxe|explicit)",
]


COMPILED_NOISE_PATTERNS = [re.compile(p, re.IGNORECASE) for p in NOISE_PATTERNS]

FEAT_PATTERN = re.compile(
    r"(?:\s*[\(\[]?\s*(?:feat\.?|ft\.?|featuring)\s+[^()\[\]]+[\)\]]?)",
    re.IGNORECASE,
)

PIPE_CHANNEL_PATTERN = re.compile(r"\s*[|/]{1,2}\s*[^|/]+$", re.IGNORECASE)
TRACK_NUM_PATTERN = re.compile(r"^\s*\d{1,3}\s*[-._\s]\s*")


def clean_query(text: str | None) -> str:
    """
    Limpia un texto (título o artista) removiendo sufijos publicitarios,
    etiquetas de remaster, live, video oficial, tasas de bitrate (MP3_160K), canal y features.
    """
    if not text:
        return ""

    cleaned = text

    # Remover sufijos de canal de YouTube (ej: "Song Name | Artist Channel")
    cleaned = PIPE_CHANNEL_PATTERN.sub("", cleaned)

    # Remover patrones de ruido
    for pattern in COMPILED_NOISE_PATTERNS:
        cleaned = pattern.sub("", cleaned)

    # Remover "feat. / ft."
    cleaned = FEAT_PATTERN.sub("", cleaned)

    # Reemplazar guiones bajos aislados entre palabras por espacios
    cleaned = re.sub(r"(?<=\w)_(?=\w)", " ", cleaned)

    # Limpiar paréntesis o corchetes vacíos resultantes
    cleaned = re.sub(r"[\(\[【「]\s*[\)\]】」]", "", cleaned)

    # Limpiar guiones o barras sobrantes al final
    cleaned = re.sub(r"[\s\-_/|]+$", "", cleaned)

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
        return round(val)
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

        # 5. Si el título repite el nombre del artista (ej: ""), probar título limpio
        for a in artists:
            for w in [word for word in re.split(r"\s+", a) if len(word) >= 4]:
                pattern = re.compile(rf"\s*[-_–/|]\s*{re.escape(w)}.*$", re.IGNORECASE)
                stripped_t = pattern.sub("", clean_t).strip()
                if stripped_t and len(stripped_t) >= 2 and stripped_t != clean_t:
                    add_var(primary, stripped_t, f"{primary} {stripped_t}".strip())
                    add_var("", stripped_t, stripped_t)
    else:
        add_var("", clean_t, clean_t)

    return variations


def is_artist_compatible(expected_artist: str | None, candidate_artist: str | None) -> bool:
    """
    Verifica con alta precisión si el artista candidato es afín al artista solicitado.
    Evita falsos positivos donde buscar 'X Artista' devuelve canciones de artistas no relacionados.
    """
    if not expected_artist or not expected_artist.strip():
        return True

    clean_exp = clean_query(expected_artist)
    if not clean_exp or clean_exp.lower() in ("desconocido", "unknown", "varios", "various"):
        return True

    if not candidate_artist or not candidate_artist.strip():
        return False

    norm_exp = normalize_for_match(clean_exp)
    norm_cand = normalize_for_match(candidate_artist)

    if not norm_exp:
        return True
    if not norm_cand:
        return False

    # 1. Coincidencia idéntica o contención directa
    if norm_exp in norm_cand or norm_cand in norm_exp:
        return True

    # 2. Token overlap (subconjuntos de palabras del artista)
    tokens_exp = [t for t in norm_exp.split() if len(t) > 2]
    tokens_cand = set(norm_cand.split())
    if tokens_exp:
        matches = sum(1 for t in tokens_exp if t in tokens_cand)
        if matches >= max(1, len(tokens_exp) // 2):
            return True

    # 3. Similitud difusa
    try:
        from rapidfuzz import fuzz
        ratio = max(
            fuzz.ratio(norm_exp, norm_cand),
            fuzz.token_set_ratio(norm_exp, norm_cand),
            fuzz.partial_ratio(norm_exp, norm_cand),
        )
        if ratio >= 55.0:
            return True
    except ImportError:
        pass

    return False


def is_lyrics_script_compatible(title_or_artist: str, lyrics_text: str) -> bool:
    """
    Comprueba que el alfabeto de la letra devuelta no sea incompatible con la consulta.
    Si el título/artista está en alfabeto latino (ej: español/inglés), pero la letra
    devuelta está llena de caracteres cirílicos (ruso), hanzi (chino), hangul (coreano), etc.,
    la letra es un falso positivo y debe rechazarse.
    """
    if not lyrics_text or not lyrics_text.strip():
        return False

    cyrillic_chars = len(re.findall(r"[\u0400-\u04FF]", lyrics_text))
    cjk_chars = len(re.findall(r"[\u4E00-\u9FFF\u3040-\u30FF\uAC00-\uD7AF]", lyrics_text))
    total_alpha = len(re.findall(r"[a-zA-Z\u0400-\u04FF\u4E00-\u9FFF\u3040-\u30FF\uAC00-\uD7AF]", lyrics_text))

    if total_alpha > 20:
        query_has_cyrillic = bool(re.search(r"[\u0400-\u04FF]", title_or_artist or ""))
        query_has_cjk = bool(re.search(r"[\u4E00-\u9FFF\u3040-\u30FF\uAC00-\uD7AF]", title_or_artist or ""))

        # Si la consulta no tiene cirílico pero >15% de las letras son cirílicas -> Incompatible
        if not query_has_cyrillic and (cyrillic_chars / total_alpha) > 0.15:
            return False

        # Si la consulta no tiene caracteres asiáticos pero >25% son CJK -> Incompatible
        if not query_has_cjk and (cjk_chars / total_alpha) > 0.25:
            return False

    return True

