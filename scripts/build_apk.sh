#!/usr/bin/env bash
# Construit l'APK IziCard Manager EN EXIGEANT les variables Supabase.
# Sans SUPABASE_URL et SUPABASE_ANON_KEY valides, le build est REFUSÉ (un APK sans elles est inutilisable).
#
# Usage :
#   bash scripts/build_apk.sh debug            # lit env.json, sinon les variables d'environnement
#   bash scripts/build_apk.sh release
#   bash scripts/build_apk.sh --check-only     # valide seulement les variables (sans construire)
set -euo pipefail
cd "$(dirname "$0")/.."

MODE="${1:-debug}"
CHECK_ONLY=0
if [ "$MODE" = "--check-only" ]; then CHECK_ONLY=1; MODE="debug"; fi
case "$MODE" in debug|release) ;; *) echo "Usage : $0 [debug|release|--check-only]" >&2; exit 2;; esac

TMP_ENV="$(mktemp)"
trap 'rm -f "$TMP_ENV"' EXIT

# 1) Source des valeurs : env.json (prioritaire) ou variables d'environnement.
if [ -f env.json ]; then
  SRC="env.json"
  cp env.json "$TMP_ENV"
else
  SRC="variables d'environnement"
  python3 - "$TMP_ENV" <<'PY'
import json, os, sys
json.dump({"SUPABASE_URL": os.environ.get("SUPABASE_URL", ""),
           "SUPABASE_ANON_KEY": os.environ.get("SUPABASE_ANON_KEY", "")}, open(sys.argv[1], "w"))
PY
fi

# 2) Validation stricte.
python3 - "$TMP_ENV" "$SRC" <<'PY'
import base64, json, re, sys
path, src = sys.argv[1], sys.argv[2]
try:
    d = json.load(open(path))
except Exception as e:
    sys.exit(f"ERREUR : {src} illisible ({e}).")
url = (d.get("SUPABASE_URL") or "").strip()
key = (d.get("SUPABASE_ANON_KEY") or "").strip()
errs = []
if not url or not key:
    errs.append("SUPABASE_URL et SUPABASE_ANON_KEY sont OBLIGATOIRES au build (absentes ou vides).")
else:
    if not url.startswith("https://") or re.search(r"VOTRE|votre|your|example", url):
        errs.append("SUPABASE_URL invalide ou encore à la valeur d'exemple (attendu : https://<projet>.supabase.co).")
    if re.search(r"VOTRE|votre|your|example", key):
        errs.append("SUPABASE_ANON_KEY est encore à la valeur d'exemple.")
    if key.startswith("sb_secret_"):
        errs.append("REFUSÉ : c'est une clé secrète (sb_secret_). Utilisez la clé anon / publishable.")
    if key.startswith("eyJ"):
        try:
            p = key.split(".")[1]; p += "=" * (-len(p) % 4)
            role = json.loads(base64.urlsafe_b64decode(p)).get("role")
            if role == "service_role":
                errs.append("REFUSÉ : c'est une clé service_role. Elle ne doit JAMAIS être embarquée dans l'application.")
            elif role != "anon":
                print(f"AVERTISSEMENT : la clé JWT n'a pas le rôle 'anon' (rôle lu : {role!r}). Vérifiez-la dans Supabase.")
        except Exception:
            errs.append("SUPABASE_ANON_KEY ressemble à un JWT mais n'est pas lisible.")
if errs:
    print(f"Variables lues depuis : {src}")
    for e in errs: print(" - " + e)
    print("Voir GUIDE_DEPLOIEMENT.md (section « Variables obligatoires »).")
    sys.exit(1)
print(f"OK : SUPABASE_URL = {url} ; SUPABASE_ANON_KEY présente ({src}).")
PY

if [ "$CHECK_ONLY" = 1 ]; then exit 0; fi

# 3) Construction avec les variables injectées.
flutter pub get
flutter build apk "--$MODE" "--dart-define-from-file=$TMP_ENV"

# 4) Contrôle de l'APK : l'URL doit s'y trouver (indicatif ; la preuve reste le lancement sur téléphone).
APK="build/app/outputs/flutter-apk/app-$MODE.apk"
[ -s "$APK" ] || { echo "ERREUR : APK introuvable ou vide : $APK" >&2; exit 1; }
HOST="$(python3 -c "import json,urllib.parse as u;print(u.urlparse(json.load(open('$TMP_ENV'))['SUPABASE_URL']).hostname)")"
FOUND=0
for entry in $(unzip -Z1 "$APK" | grep -E '(^lib/.*/libapp\.so$|kernel_blob\.bin$)' || true); do
  if unzip -p "$APK" "$entry" | grep -aqF "$HOST"; then FOUND=1; break; fi
done
if [ "$FOUND" = 1 ]; then
  echo "CONTRÔLE : l'adresse Supabase ($HOST) est bien présente dans l'APK."
else
  echo "AVERTISSEMENT : adresse Supabase non retrouvée dans l'APK par ce contrôle (peut être un faux négatif)."
  echo "              Lancez l'APK : l'écran « Configuration Supabase manquante » signifie que les variables n'ont PAS été incluses."
fi
ls -l "$APK"; sha256sum "$APK"
