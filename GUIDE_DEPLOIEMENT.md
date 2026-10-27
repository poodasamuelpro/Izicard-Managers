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

**Configuration obligatoire (une seule fois).** Sur GitHub, dépôt `Izicard-Managers` > Settings > Secrets and variables > Actions > onglet **Secrets** > New repository secret :

| Nom exact | Valeur | Obligatoire |
|---|---|---|
| `SUPABASE_URL` | `https://thsedbhzhonemdhbndpf.supabase.co` | Oui |
| `SUPABASE_ANON_KEY` | clé `anon` / publishable du projet | Oui |
| `ANDROID_KEYSTORE_BASE64` | `base64 -w0 release-key.jks` | Pour une release publiable |
| `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD` | infos du keystore | Avec la ligne précédente |

Les noms doivent être identiques, en majuscules. Les créer dans l'onglet **Secrets** (pas **Variables** : le workflow lit `secrets.*`). Le dépôt ne peut pas vérifier leur présence à votre place ; le workflow, lui, la vérifie à chaque lancement et s'arrête avec un message clair s'ils manquent.

**Lancer le build.** Onglet **Actions** > workflow **Build APK** > bouton **Run workflow** > choisir la branche `master` et le type `release` ou `debug` > **Run workflow**. Autre façon : pousser un tag (`git tag v1.0.0 && git push origin v1.0.0`) lance un build release.

**Ce que fait le workflow, dans l'ordre :**
1. Vérifie les variables (`scripts/build_apk.sh --check-only`) : secrets absents, valeurs d'exemple, clé `service_role` ou `sb_secret_` -> échec immédiat, rien n'est compilé.
2. Installe Java 17 et Flutter (canal stable).
3. Si les secrets de signature existent, crée le keystore et `android/key.properties` ; sinon avertit que la release sera signée avec la clé debug.
4. Lance `bash scripts/build_apk.sh <mode>` : `flutter pub get` puis `flutter build apk` avec les variables injectées par `--dart-define-from-file`.
5. Publie l'APK en artefact `izicard-manager-apk-<mode>`.

**Récupérer l'APK.** Actions > le run terminé (coche verte) > section **Artifacts** en bas de page > télécharger le zip > l'extraire > installer `app-release.apk` (ou `app-debug.apk`). Les artefacts expirent au bout d'un délai fixé par GitHub (90 jours par défaut).

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

## 7. Audit du dossier `android/` (écarts constatés)
Lecture seule des fichiers, sans compilation (Flutter et Android SDK absents de l'environnement d'audit).

**Conforme :**
- Nom `IziCard Manager`, `namespace` et `applicationId` = `com.izicardouaga.izicardmanager`, identiques à `MainActivity.kt` (même paquet).
- Manifeste : permission NFC, `android.hardware.nfc` avec `required="false"`, `INTERNET`, `allowBackup="false"`, `usesCleartextTraffic="false"`, activité `exported="true"` avec le filtre MAIN/LAUNCHER, `flutterEmbedding=2`. Le manifeste debug ne contient que `INTERNET`.
- Icône adaptative avec variante monochrome ; écran de démarrage clair et sombre (dossiers `drawable-night*`, `values-night*`, Android 12+).
- Signature : `key.properties`, `*.jks`, `*.keystore`, `local.properties` ignorés par Git ; aucun secret dans `android/`.
- Dépendance NFC en lecture/écriture côté Flutter déclarée (`nfc_manager`).

**Écarts :**
1. **Aucune variable Supabase dans `android/`** : normal, elles sont injectées à la compilation Dart (`--dart-define`). L'APK debug déjà construit sans elles est donc inutilisable (cause du dysfonctionnement constaté).
2. **Release signée avec la clé debug** tant que `key.properties` est absent (repli prévu dans `app/build.gradle.kts`) : APK non publiable. La clé temporaire de M17 doit être remplacée.
3. **`minSdk = flutter.minSdkVersion`** alors que `pubspec.yaml` indique `min_sdk_android: 24` : la valeur réelle dépend de la version de Flutter installée. Compatibilité avec `nfc_manager 4.0.2` non vérifiée ; à confirmer au premier build.
4. **`versionCode` = 1** (`version: 0.1.0+1`) : à incrémenter dans `pubspec.yaml` à chaque publication.
5. **Pas de lien profond (deep link)** : aucun schéma ni domaine n'est défini dans le dépôt, rien n'a été inventé. À fournir par le propriétaire.
6. **Pas de réduction/obfuscation** (`minifyEnabled` absent) : choix par défaut, non justifié par écrit jusqu'ici.
7. **`gradlew`, `gradlew.bat`, `gradle-wrapper.jar` non versionnés** (ignorés par `android/.gitignore`) : Flutter les régénère au build ; sans impact avec Flutter/GitHub Actions, mais `./gradlew` seul ne marche pas sur un clone neuf.
8. **Aucun filtre NFC (découverte de tag à l'ouverture de l'app)** : la lecture/écriture se fait uniquement quand l'écran NFC de l'application est ouvert.
9. **Rien n'a été compilé ni installé** : tous les points ci-dessus sont issus de la lecture des fichiers.
