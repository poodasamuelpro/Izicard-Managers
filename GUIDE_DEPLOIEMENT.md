# Guide de déploiement — IziCard Manager (Android)

Ce guide vaut pour l'application Flutter de ce dépôt. L'espace web (`izicard-managers-web`) est un autre projet, déployé séparément.

## 1. Variables obligatoires au build

| Variable | Rôle | Valeur |
|---|---|---|
| `SUPABASE_URL` | Adresse du projet Supabase | `https://<projet>.supabase.co` (Supabase > Project Settings > API > Project URL) |
| `SUPABASE_ANON_KEY` | Clé publique `anon` / publishable | Supabase > Project Settings > API > clé `anon` / `public` |

**Elles doivent être fournies À LA COMPILATION, pour les builds debug comme release.**
Le code les lit avec `String.fromEnvironment` (`lib/core/config/env.dart`) : Flutter les écrit dans l'APK au moment du build. Elles ne se lisent pas au lancement et on ne peut pas les ajouter à un APK déjà construit.

**Symptôme d'un APK construit sans elles :** au lancement, l'écran « Configuration Supabase manquante ». Il faut reconstruire l'APK, rien d'autre ne corrige ce défaut.

**Interdit dans l'application, le dépôt et le build :** clé `service_role`, clé `sb_secret_…`, clé API Resend, token de gestion Supabase. Ces secrets restent côté Supabase. Le script de build refuse une clé `service_role` ou `sb_secret_`.

## 2. Construire l'APK (3 façons, même règle)

### A. En local, avec le script (recommandé)
```bash
cp env.example.json env.json      # puis remplir les 2 valeurs ; env.json est ignoré par Git
bash scripts/build_apk.sh debug   # ou : release
```
Le script **refuse de construire** si une variable manque, vaut encore la valeur d'exemple, ou si la clé est une `service_role`. Il vérifie ensuite que l'adresse Supabase se trouve dans l'APK.
Valider les variables sans construire : `bash scripts/build_apk.sh --check-only`.
Sans `env.json`, le script lit les variables d'environnement `SUPABASE_URL` et `SUPABASE_ANON_KEY`.

### B. À la main avec Flutter
```bash
flutter build apk --debug   --dart-define-from-file=env.json
flutter build apk --release --dart-define-from-file=env.json
flutter run                 --dart-define-from-file=env.json
```
Un `flutter build apk` ou un `flutter run` **sans** `--dart-define-from-file` (ou sans les deux `--dart-define`) produit un APK inutilisable. Dans Android Studio / VS Code, ajouter l'argument de lancement `--dart-define-from-file=env.json`.

### C. Avec GitHub Actions
1. GitHub > Settings > Secrets and variables > Actions : créer `SUPABASE_URL` et `SUPABASE_ANON_KEY`.
2. Actions > **Build APK** > Run workflow (ou pousser un tag `v1.0.0`).
3. Le travail échoue **avant toute compilation** si les secrets manquent. L'APK est téléchargeable dans les artefacts du run.
4. Signature release (facultatif mais indispensable pour publier) : secrets `ANDROID_KEYSTORE_BASE64` (`base64 -w0 release-key.jks`), `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`. Sans eux, le build release est signé avec la clé debug : à ne pas publier.

Le workflow **Analyse et tests** n'a pas besoin des variables (il ne construit pas d'APK).

## 3. Vérifier l'APK avant de le distribuer
1. Installer l'APK : l'écran de connexion doit s'afficher, **pas** « Configuration Supabase manquante ».
2. Se connecter avec un compte de test.
3. Ouvrir Réglages et vérifier le nom/la version.
Le contrôle automatique du script est indicatif ; seul le lancement sur un téléphone fait foi.

## 4. Prérequis côté Supabase (hors application)
À faire une seule fois par projet, dans Supabase (détails : `SUPABASE_SETUP.md`) :
- Schéma `nfc` et scripts SQL appliqués (003, 004, puis les suivants dans l'ordre).
- Authentication : fournisseur Email actif, OTP de récupération à **8 chiffres**, SMTP Resend, URLs de redirection autorisées, inscription publique désactivée si l'application doit être fermée.
- Edge Function `create-client-user` déployée. Elle lit sa propre clé `service_role` dans les secrets de Supabase : cette clé ne va **jamais** dans l'application.

## 5. Signature et publication
- Une clé de signature générée automatiquement par un outil de développement **ne doit pas servir à publier**. Utiliser la clé de production du propriétaire (`android/key.properties` + `.jks`, jamais commités).
- L'identifiant `com.izicardouaga.izicardmanager` ne doit plus changer après la première publication.

## 6. Dépannage rapide
| Constat | Cause | Remède |
|---|---|---|
| « Configuration Supabase manquante » au lancement | APK construit sans les variables | Reconstruire avec `scripts/build_apk.sh` |
| Le script refuse la clé | Clé `service_role` ou valeur d'exemple | Prendre la clé `anon` dans Supabase |
| Connexion refusée / erreur réseau | URL ou clé d'un autre projet, ou projet en pause | Comparer avec Supabase > Project Settings > API |
| L'e-mail de récupération n'arrive pas | SMTP Resend ou OTP non configurés | Voir `SUPABASE_SETUP.md` |
| Le build GitHub échoue tout de suite | Secrets absents | Créer `SUPABASE_URL` et `SUPABASE_ANON_KEY` |
