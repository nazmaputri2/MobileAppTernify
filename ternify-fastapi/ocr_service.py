import cv2
import re
import json
import joblib
import numpy as np
import pytesseract
from rapidfuzz import process, fuzz

pytesseract.pytesseract.tesseract_cmd = r"C:\Program Files\Tesseract-OCR\tesseract.exe"

# Path Windows dihapus karena Colab menggunakan Linux. Pytesseract akan otomatis menemukannya.

# ==================================================================
# KNOWLEDGE BASE — Kamus istilah untuk koreksi teks OCR
# ==================================================================
KB_RAS = ["Merino", "Suffolk", "Dorper", "Garut", "Texel", "Corriedale",
          "Awassi", "Barbados", "Ekor Gemuk", "Priangan", "Batur", "Sapudi",
          "Jonggol", "Lokal", "Domba Garut", "Domba Merino", "Domba Etawa", "Etawa"]

KB_GEJALA = ["nafsu makan rendah", "nafsu makan turun", "lemas", "diare",
             "demam", "batuk", "sesak napas", "gatal", "pincang", "kembung"]

KB_DIAGNOSIS = ["sehat", "orf", "scabies", "kudis", "cacingan", "pneumonia",
                "bloat", "kembung", "mastitis", "tetanus", "diare", "pink eye",
                "anemia", "malnutrisi", "PMK", "luka", "demam", "sakit perut"]

KB_TINDAKAN = ["pemberian obat", "suntik", "operasi", "isolasi", "vaksinasi",
               "perawatan luka", "pemberian vitamin", "drench"]

KB_OBAT = ["ivermectin", "albendazole", "oxytetracycline", "penicillin",
           "amoxicillin", "vitamin B", "kalsium", "probiotik", "betadine",
           "antibiotik", "antiparasit", "vaksin", "akarisida"]

# Status kondisi domba (kondisi umum, bukan diagnosa medis spesifik)
KB_STATUS = ["sehat", "lemas", "kritis", "membaik", "stabil",
             "perlu observasi", "mati", "sembuh",
             "susah makan", "nafsu makan turun", "nafsu makan rendah"]

KB_KELAMIN = ["jantan", "betina", "jantan kastrasi"]

KB_KEBUNTINGAN = ["bunting", "tidak bunting", "belum diketahui", "melahirkan",
                  "keguguran", "bunting 1 bulan", "bunting 2 bulan",
                  "bunting 3 bulan", "bunting 4 bulan", "bunting 5 bulan"]

ALL_KB = (KB_RAS + KB_GEJALA + KB_DIAGNOSIS + KB_TINDAKAN + KB_OBAT + KB_STATUS + KB_KELAMIN + KB_KEBUNTINGAN)

# ==================================================================
# DATA LAYER - PREPROCESSING
# ==================================================================
def preprocess_image(image_path):
    original = cv2.imread(image_path)
    if original is None:
        raise ValueError(f"Gambar tidak ditemukan: {image_path}")

    gray = cv2.cvtColor(original, cv2.COLOR_BGR2GRAY)
    h, w = gray.shape
    if w < 1500:
        scale = 1500 / w
        gray = cv2.resize(gray, None, fx=scale, fy=scale, interpolation=cv2.INTER_CUBIC)

    blurred = cv2.GaussianBlur(gray, (5, 5), 0)
    thresh = cv2.adaptiveThreshold(
        blurred, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C, cv2.THRESH_BINARY_INV, 35, 15
    )

    h_kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (40, 1))
    v_kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (1, 40))
    h_lines  = cv2.morphologyEx(thresh, cv2.MORPH_OPEN, h_kernel, iterations=2)
    v_lines  = cv2.morphologyEx(thresh, cv2.MORPH_OPEN, v_kernel, iterations=2)
    table_lines = cv2.add(h_lines, v_lines)

    dilate_k = np.ones((3, 3), np.uint8)
    table_lines = cv2.dilate(table_lines, dilate_k, iterations=1)

    thresh_clean = cv2.subtract(thresh, table_lines)
    final_img = 255 - thresh_clean

    erode_k = np.ones((2, 2), np.uint8)
    final_img = cv2.erode(final_img, erode_k, iterations=1)

    tess_data = pytesseract.image_to_data(
        final_img, lang="ind", config="--oem 3 --psm 6", output_type=pytesseract.Output.DICT
    )
    confs = [int(c) for c in tess_data["conf"] if str(c).isdigit() and int(c) > 0]
    confidence = round(sum(confs) / len(confs), 1) if confs else 0

    return final_img, confidence

# ==================================================================
# OCR ENGINE & NLP
# ==================================================================
def run_ocr_engine(image):
    data = pytesseract.image_to_data(
        image, config="--oem 3 --psm 11 -l ind", output_type=pytesseract.Output.DICT
    )
    lines_dict = {}
    for i in range(len(data["text"])):
        text = data["text"][i].strip()
        conf = int(data["conf"][i])
        if not text or conf <= 10: continue

        y, x = data["top"][i], data["left"][i]
        matched_y = next((ey for ey in lines_dict if abs(y - ey) < 20), None)
        if matched_y is None:
            lines_dict[y] = []
            matched_y = y
        lines_dict[matched_y].append((x, text))

    result_lines = []
    for y in sorted(lines_dict):
        words = sorted(lines_dict[y], key=lambda w: w[0])
        result_lines.append(" ".join(w[1] for w in words))

    return "\n".join(result_lines)

def nlp_text_correction(word, kb_list, threshold=78):
    if not word or len(word) <= 2 or word in ["-", "--", "~"]: return word
    match = process.extractOne(word.lower(), [k.lower() for k in kb_list], scorer=fuzz.ratio)
    if match and threshold <= match[1] < 100:
        idx = [k.lower() for k in kb_list].index(match[0])
        return kb_list[idx]
    return word

# ==================================================================
# PARSERS
# ==================================================================
def _strip_bullet(line):
    """Hilangkan penanda bullet (*, -, •, dll) di awal baris sebelum parsing label:value."""
    return re.sub(r"^[\*\-\u2022\u25CF\u25AA\u25E6•·▪●]+\s*", "", line).strip()

def _split_glued_lines(raw_text):
    """
    Pisahkan baris yang nempel akibat OCR gagal mendeteksi newline,
    contoh: '...Jantan (Ear Tag): 031Ear Tag: 001...' (dua field/record
    tergabung dalam satu baris tanpa pemisah). Disisipkan newline sebelum
    label field baru yang dikenali (Ear Tag, Jenis Kelamin, dst) jika ia
    muncul tepat menempel setelah suatu nilai (huruf/angka langsung diikuti
    huruf kapital label, tanpa spasi).
    """
    known_labels = (
        r"Ear\s*Tag|Jenis\s*Kelamin|Tanggal\s*Lahir|Jenis\s*Domba|"
        r"Induk|Jantan|Pejantan|Tanggal\s*perkawinan|Status\s*Kebuntingan|"
        r"Berat\s*badan|Status\s*Kondisi|Tindakan|Dosis|Gejala|Diagnosa|Catatan"
    )
    pattern = re.compile(r"(?<=[a-zA-Z0-9])(" + known_labels + r")\s*:", flags=re.IGNORECASE)
    return pattern.sub(r"\n\1:", raw_text)

# Kata-kata yang HANYA muncul sebagai bagian dari nama label field (bukan isi value).
# Dipakai untuk mendeteksi baris "label murni" — baris yang cuma berisi nama field
# tanpa value (kasus OCR yang membaca value di baris sebelumnya, label di baris
# berikutnya, mis. layout kolom yang urutan bacanya terbalik/acak).
_LABEL_ONLY_WORDS = {
    "ear", "tag", "jenis", "kelamin", "tanggal", "lahir", "domba", "induk",
    "jantan", "pejantan", "perkawinan", "status", "kebuntingan", "berat",
    "badan", "kondisi", "tindakan", "dosis", "obat", "gejala", "diagnosa",
    "diagnosis", "catatan", "no", "id", "bobot", "ras", "breed", "tgl",
    "keterangan", "note", "treatment", "penanganan",
}

def _is_label_only_line(line):
    """
    True jika sebuah baris kemungkinan besar HANYA berisi nama label field
    (tanpa value asli), misalnya 'Status Kondisi' atau 'Tindakan'. Dideteksi
    dengan mengecek apakah SEMUA kata di baris itu adalah kata label yang
    dikenal (lihat _LABEL_ONLY_WORDS), dan tidak ada angka di baris tsb.
    """
    words = [w.lower().strip(".,:;()[]{}") for w in line.split()]
    words = [w for w in words if w]
    if not words: return False
    if any(re.search(r"\d", w) for w in words): return False
    return all(w in _LABEL_ONLY_WORDS for w in words)

_LOOKBACK_MARKER = "\u0000LB\u0000"  # penanda internal: baris ini hasil gabungan _merge_lookback_lines

def _merge_lookback_lines(lines, field_map):
    """
    Menangani layout OCR di mana VALUE muncul di satu baris dan LABEL field-nya
    baru muncul di baris BERIKUTNYA (urutan baca terbalik), contoh nyata:
        'Susah makan'        <- value, tanpa label apapun
        'Status Kondisi'     <- label murni, tanpa value
        'pemberi obat'       <- value (terpotong OCR dari 'pemberian obat')
        'Tindakan an'        <- label field + sisa potongan kata yang nyasar

    Aturan: jika sebuah baris TIDAK cocok dengan field manapun ("yatim"), dan
    baris BERIKUTNYA cocok dengan suatu field, gabungkan baris yatim itu sebagai
    bagian depan dari value field berikutnya:
        'Tindakan an'  +  prev 'pemberi obat'  ->  'Tindakan: pemberi obat an'
    Baris yang sudah punya pemisah ':' / '=' (format label:value normal) TIDAK
    pernah dianggap yatim, supaya format dokumen standar tidak terganggu.
    Baris hasil gabungan diberi penanda _LOOKBACK_MARKER supaya tahap berikutnya
    tahu baris ini perlu dibersihkan dari sisa kata label yang menempel.
    """
    field_keys_only = {k: v for k, v in field_map.items()}
    merged = []
    i = 0
    n = len(lines)
    while i < n:
        line = lines[i]

        if ":" in line or "=" in line:
            merged.append(line)
            i += 1
            continue

        current_field_key, _ = _parse_line_with_map(line, field_keys_only)

        if current_field_key is None and i + 1 < n:
            next_line = lines[i + 1]
            if ":" not in next_line and "=" not in next_line:
                next_field_key, _ = _parse_line_with_map(next_line, field_keys_only)
                if next_field_key is not None:
                    # baris ini "yatim" (tak match field apapun) dan baris berikutnya
                    # punya field -> gabungkan jadi satu baris: [baris_field_berikutnya] [baris_yatim]
                    merged.append(f"{next_line} {line}{_LOOKBACK_MARKER}")
                    i += 2
                    continue

        merged.append(line)
        i += 1

    return merged

def _strip_leading_label_words(value, is_lookback_merged):
    """
    Buang kata-kata label generik (lihat _LABEL_ONLY_WORDS) yang nyangkut di
    AWAL value, misalnya 'Kondisi Susah makan' -> 'Susah makan' (kata 'Kondisi'
    adalah sisa label). Juga membuang token tunggal pendek (<=2 huruf) yang
    tidak bermakna sebagai kata utuh, misalnya potongan OCR 'an' dari 'pemberian'.

    HANYA dijalankan jika is_lookback_merged True (baris ini hasil gabungan
    _merge_lookback_lines) — supaya value field NORMAL yang kebetulan diawali
    kata generik (mis. jenis_domba = "Domba Garut") tidak ikut terpotong.
    """
    if not is_lookback_merged:
        return value
    words = value.split()
    while words and (words[0].lower().strip(".,:;()[]{}") in _LABEL_ONLY_WORDS):
        words.pop(0)
    while words and len(words[0]) <= 2 and words[0].isalpha():
        words.pop(0)
    cleaned = " ".join(words).strip()
    return cleaned if cleaned else value

def _parse_line_with_map(line, field_map):
    # Pola dicek sesuai URUTAN field_map (insertion order). Field yang lebih spesifik
    # (mis. "induk", "jantan") harus didefinisikan SEBELUM pola umum (mis. "ear.?tag")
    # di dalam FIELD_MAP masing-masing parser, supaya label gabungan seperti
    # "Induk (Ear Tag)" tidak salah tertangkap oleh pola umum "ear_tag".
    sep = re.split(r"\s*[:=]\s*", line, maxsplit=1)
    if len(sep) == 2 and sep[0].strip() and sep[1].strip():
        raw_label, value = sep[0].strip(), sep[1].strip()
        for pattern, key in field_map.items():
            if re.search(pattern, raw_label, re.IGNORECASE): return key, value

    words = line.split()
    for length in (1, 2, 3, 4):
        if len(words) <= length: continue
        candidate_label = " ".join(words[:length])
        candidate_value = " ".join(words[length:])
        for pattern, key in field_map.items():
            if re.search(pattern, candidate_label, re.IGNORECASE): return key, candidate_value
    return None, None

# Parser Rekam Medis
def parse_rekam_medis_card(raw_text):
    FIELD_MAP = {
        r"domba|ear.?tag|no.?domba|id.?domba": "ear_tag",
        r"berat.?badan|berat|bobot": "berat_badan",
        r"gejala|symptom|keluhan": "gejala",
        r"diagnosa|diagnosis|diagnos": "diagnosa",
        r"tindakan|treatment|penanganan": "tindakan",
        r"dosis.?obat|dosis|^obat$": "dosis_obat",
        r"status.?kondisi|status|kondisi": "status_kondisi",
        r"catatan|note|keterangan": "catatan",
    }
    KB_MAP = {"gejala": KB_GEJALA, "diagnosa": KB_DIAGNOSIS, "tindakan": KB_TINDAKAN,
              "dosis_obat": KB_OBAT, "status_kondisi": KB_STATUS}
    record = {k: None for k in FIELD_MAP.values()}
    raw_text = _split_glued_lines(raw_text)
    raw_lines = [_strip_bullet(l.strip()) for l in raw_text.split("\n") if l.strip()]
    raw_lines = _merge_lookback_lines(raw_lines, FIELD_MAP)

    for raw_line in raw_lines:
        is_lookback = _LOOKBACK_MARKER in raw_line
        raw_line = raw_line.replace(_LOOKBACK_MARKER, "")
        line = re.sub(r"[|\[\]\(\){]{2,}", " ", raw_line).strip()
        field_key, value = _parse_line_with_map(line, FIELD_MAP)
        if not field_key or not value: continue

        # Buang sisa kolom tabel OCR yang nyangkut di depan value (mis. "77   susah makan"),
        # tapi HANYA jika token awal itu kode/angka, bukan kata biasa (mis. "susah makan").
        value = re.sub(r"^[\d\W]{1,6}\s{2,}", "", value).strip()
        # Buang sisa kata label / token nyasar yang nempel di depan value akibat
        # penggabungan baris lookback (mis. layout OCR value-mendahului-label).
        value = _strip_leading_label_words(value, is_lookback)
        if field_key in KB_MAP:
            value = nlp_text_correction(value, KB_MAP[field_key], threshold=70)

        if field_key == "ear_tag":
            id_match = re.search(r"\b(\d{2,4})\b", value)
            value = id_match.group(1) if id_match else value
        if field_key == "berat_badan":
            berat_match = re.search(r"(\d{1,3}(?:[.,]\d+)?)\s*(kg|gram|gr|g)\b", value.lower())
            if berat_match:
                value = f"{berat_match.group(1)} {berat_match.group(2)}"
        if field_key == "dosis_obat":
            dosis_match = re.search(r"(\d{1,3}(?:[.,]\d)?\s*(?:ml|mg|cc|tablet|kapsul))", value.lower())
            if dosis_match:
                value = dosis_match.group(1)
            else:
                # Fallback: OCR kadang salah baca satuan singkat (mis. "ml" -> "w" / "nl" / "ni").
                # Jika ada angka dengan token satuan pendek (1-3 huruf) yang TIDAK dikenali,
                # anggap itu varian rusak dari "ml" (satuan dosis cair paling umum pada form ini).
                fallback_match = re.search(r"(\d{1,3}(?:[.,]\d)?)\s*([a-zA-Z]{1,3})\b", value)
                if fallback_match and fallback_match.group(2).lower() not in ("kg", "gr"):
                    value = f"{fallback_match.group(1)} ml"

        record[field_key] = value
    return record

# Parser Perkawinan
def parse_perkawinan_card(raw_text):
    FIELD_MAP = {
        r"tanggal.?perkawinan|tgl.?perkawinan|tanggal.?kawin": "tanggal_perkawinan",
        r"induk": "ear_tag_induk",
        r"pejantan|jantan.*ear|ear.*jantan": "ear_tag_pejantan",
        r"kebuntingan|bunting|status": "status_kebuntingan",
        r"catatan|note|keterangan": "catatan"
    }
    KB_MAP = {"status_kebuntingan": KB_KEBUNTINGAN}
    record = {k: None for k in FIELD_MAP.values()}
    raw_text = _split_glued_lines(raw_text)
    raw_lines = [_strip_bullet(l.strip()) for l in raw_text.split("\n") if l.strip()]
    raw_lines = _merge_lookback_lines(raw_lines, FIELD_MAP)

    for raw_line in raw_lines:
        is_lookback = _LOOKBACK_MARKER in raw_line
        raw_line = raw_line.replace(_LOOKBACK_MARKER, "")
        line = re.sub(r"[|\[\]\(\)]{2,}", " ", raw_line).strip()
        field_key, value = _parse_line_with_map(line, FIELD_MAP)
        if not field_key or not value: continue

        value = _strip_leading_label_words(value, is_lookback)
        if field_key in KB_MAP: value = nlp_text_correction(value, KB_MAP[field_key], threshold=70)
        if field_key in ("ear_tag_induk", "ear_tag_pejantan"):
            id_match = re.search(r"\b(\d{2,4})\b", value)
            value = id_match.group(1) if id_match else value
        if field_key == "tanggal_perkawinan":
            tgl = re.search(r"(\d{1,2}\s*[-/.]\s*\d{1,2}\s*[-/.]\s*\d{2,4})", value)
            if tgl: value = re.sub(r"\s+", "", tgl.group(1))
        record[field_key] = value
    return record

# Parser Data Domba
def parse_data_domba_card(raw_text):
    FIELD_MAP = {
        r"induk": "ear_tag_induk",
        r"jantan.*ear|ear.*jantan|pejantan": "ear_tag_jantan",
        r"ear.?tag": "ear_tag",
        r"jenis.?kelamin|kelamin": "jenis_kelamin",
        r"tanggal.?lahir|lahir|tgl": "tanggal_lahir",
        r"jenis.?domba|ras|breed": "jenis_domba",
        r"catatan|note|keterangan": "catatan"
    }
    KB_MAP = {"jenis_kelamin": KB_KELAMIN, "jenis_domba": KB_RAS}
    record = {k: None for k in FIELD_MAP.values()}
    raw_text = _split_glued_lines(raw_text)
    raw_lines = [_strip_bullet(l.strip()) for l in raw_text.split("\n") if l.strip()]
    raw_lines = _merge_lookback_lines(raw_lines, FIELD_MAP)

    for raw_line in raw_lines:
        is_lookback = _LOOKBACK_MARKER in raw_line
        raw_line = raw_line.replace(_LOOKBACK_MARKER, "")
        line = re.sub(r"[|\[\]\(\)]{2,}", " ", raw_line).strip()
        field_key, value = _parse_line_with_map(line, FIELD_MAP)
        if not field_key or not value: continue

        value = _strip_leading_label_words(value, is_lookback)
        if field_key in KB_MAP: value = nlp_text_correction(value, KB_MAP[field_key], threshold=70)
        if field_key in ("ear_tag", "ear_tag_induk", "ear_tag_jantan"):
            id_match = re.search(r"\b(\d{2,4})\b", value)
            value = id_match.group(1) if id_match else value
        if field_key == "tanggal_lahir":
            tgl = re.search(r"(\d{1,2}\s*[-/.]\s*\d{1,2}\s*[-/.]\s*\d{2,4})", value)
            if tgl: value = re.sub(r"\s+", "", tgl.group(1))
        record[field_key] = value
    return record

# ==================================================================
# ROUTER & PIPELINE
# ==================================================================
def detect_form_type(text):
    t = re.sub(r"\s+", " ", text.upper())

    if "DOKUMEN PERKAWINAN" in t or "PERKAWINAN" in t:
        return "PERKAWINAN"
    if "DOKUMEN DOMBA" in t or ("JENIS KELAMIN" in t and "TANGGAL LAHIR" in t):
        return "DATA_DOMBA"
    if "DOKUMEN REKAM MEDIS" in t or "REKAM MEDIS" in t:
        return "REKAM_MEDIS"

    # Sinyal tambahan tanpa judul dokumen eksplisit
    if "INDUK" in t and "PEJANTAN" in t and ("KEBUNTINGAN" in t or "BUNTING" in t):
        return "PERKAWINAN"
    if "GEJALA" in t or "DIAGNOSA" in t or "DIAGNOSIS" in t:
        return "REKAM_MEDIS"
    if ("BERAT BADAN" in t or "BOBOT" in t) and ("STATUS KONDISI" in t or "TINDAKAN" in t or "DOSIS" in t):
        return "REKAM_MEDIS"
    if "JENIS DOMBA" in t and "TANGGAL LAHIR" in t:
        return "DATA_DOMBA"

    return "UNKNOWN"

def process_form_image(image_path):
    img, confidence = preprocess_image(image_path)

    if confidence < 50:
        return {"success": False, "message": f"Confidence terlalu rendah ({confidence}%)", "data": None}

    raw_text = run_ocr_engine(img)
    form_type = detect_form_type(raw_text)

    if form_type == "UNKNOWN":
        return {"success": False, "message": "Jenis form tidak dikenali", "data": None}

    if form_type == "REKAM_MEDIS": record = parse_rekam_medis_card(raw_text)
    elif form_type == "PERKAWINAN": record = parse_perkawinan_card(raw_text)
    elif form_type == "DATA_DOMBA": record = parse_data_domba_card(raw_text)

    return {
        "success": True,
        "message": "OCR Berhasil",
        "form_type": form_type,
        "confidence": confidence,
        "extracted_text": raw_text,
        "details": record,
        "data": record
    }