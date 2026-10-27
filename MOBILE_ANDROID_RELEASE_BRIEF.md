# IziCard Manager — prompt de livraison Android

Ce document concerne uniquement la plateforme Android du dépôt mobile Flutter : génération du dossier `android/`, configuration de l’application, icône et écran de démarrage, permissions, compilation et remise de l’artefact installable. Il ne décrit ni ne demande de travail sur les services distants ou les fonctionnalités métier.

## Identité de l’application

- Nom affiché : **IziCard Manager**.
- Description courte : **Gestion et encodage NFC**.
- Nom technique Flutter actuel : `izicard_nfc_app` ; ne pas l’utiliser comme libellé visible.
- Identifiant Android proposé : `com.izicardouaga.izicardmanager`. Le vérifier dans le dépôt et le conserver de manière stable ; ne pas le changer silencieusement.
- Utiliser le logo déjà fourni dans `assets/images/logo.jpg` comme référence de marque. Ne pas remplacer ni altérer le fichier source.

## Prompt d’exécution

> Tu travailles uniquement dans le dépôt Flutter `Izicard-Managers` pour générer et livrer correctement la plateforme **Android** de l’application **IziCard Manager**. Réalise le travail dans le dépôt ; ne réponds pas par un simple plan. Travaille par lots cohérents, consigne chaque lot dans `PROJECT_PROGRESS.md` (date/heure UTC, fichiers concernés, étapes terminées, vérifications, limites, reste à faire), puis commit et pousse immédiatement ce lot sur la branche déjà utilisée avant de commencer le suivant.
>
> **Périmètre strict :** prépare le dossier Android et les fichiers strictement nécessaires à sa configuration et à sa livraison. Préserve les fonctionnalités et le code mobile existants. Ne change pas leur logique pour contourner un problème de compilation. N’ajoute aucun service distant, ne modifie aucune base, aucun serveur ni aucune fonction externe. Ne travaille pas dans un autre dépôt.
>
> **1. Vérifier l’environnement et le projet.** Relève les versions Flutter, Dart, Java/JDK, Gradle et Android SDK disponibles ainsi que les contraintes `pubspec.yaml`. Repère les fichiers Android éventuellement déjà présents et les changements locaux avant d’agir. Génère le dossier manquant avec la version Flutter compatible avec le projet ; ne remplace pas les sources Android existantes sans les avoir examinées. Si un outil ou une version indispensable manque, consigne précisément le blocage.
>
> **2. Configurer proprement l’application.** Configure le nom visible **IziCard Manager**, l’identifiant stable `com.izicardouaga.izicardmanager` (sauf identifiant déjà établi dans les sources), le namespace, les versions SDK minimales et cibles compatibles avec Flutter et les plugins réellement utilisés. Définis des versions cohérentes (`versionName`/`versionCode` ou leurs équivalents Flutter), les variantes debug/release et les réglages Gradle nécessaires. Garde la configuration claire, reproductible et sans valeur dépendante du chemin de l’ordinateur.
>
> **3. Déclarer uniquement les permissions nécessaires.** Déclare la permission Android NFC `android.permission.NFC` et la fonctionnalité `android.hardware.nfc` avec `required="false"`, afin que les fonctions de gestion restent installables sur les appareils sans NFC ; l’application doit expliquer clairement quand une opération NFC ne peut pas être utilisée. Vérifie également les permissions réseau réellement nécessaires et celles fusionnées par les plugins. N’ajoute aucune permission au hasard, n’active pas le trafic HTTP en clair sans nécessité démontrée et vérifie le manifeste final fusionné.
>
> **4. Configurer l’icône et l’écran de démarrage.** À partir des ressources de marque déjà présentes, crée ou prépare les ressources Android requises : icône adaptative (foreground/background et zone de sécurité corrects), variantes de compatibilité/densité et, si pris en charge, icône monochrome Android récent. Configure un écran de démarrage natif conforme aux conventions Android actuelles, utilisant le logo, les couleurs de la marque et une transition propre vers Flutter, sans flash blanc/noir ni étirement du logo. Conserve le fichier logo source. Vérifie les ressources générées à différentes tailles et dans les thèmes clair/sombre du système.
>
> **5. Vérifier les liens d’application et la navigation système.** Examine les routes et schémas de liens déjà définis dans le dépôt et configure dans le manifeste Android uniquement les filtres qui correspondent à ces valeurs réelles. Ne fabrique pas de domaine, d’URL de production ou de schéma incompatible. Vérifie le lancement depuis un lien, le retour arrière, le partage de fichiers si utilisé et les changements d’orientation. Si une valeur indispensable n’existe pas dans le dépôt et ne peut pas être déterminée, consigne précisément laquelle manque plutôt que d’inventer une configuration.
>
> **6. Contrôler la sécurité de la configuration.** Vérifie que les composants exportés sont explicitement déclarés, que les clés et fichiers de signature ne sont pas inclus dans Git, que `android/local.properties`, les caches et sorties de build sont ignorés, et que les options de sauvegarde, cleartext, minification et ProGuard sont justifiées par le code existant. Ne committe jamais un keystore ni un mot de passe de signature. N’applique pas de minification release si elle casse un plugin ; vérifie le résultat avant livraison.
>
> **7. Formater, analyser, tester et construire.** Exécute `flutter pub get`, le formatage des fichiers modifiés, `flutter analyze`, `flutter test`, puis au minimum `flutter build apk --debug`. Corrige les erreurs provenant des modifications de ce lot. Distingue explicitement les erreurs de compilation des avertissements préexistants ; ne supprime pas de fonctionnalités ou de tests pour faire passer le build. Si l’environnement le permet, construis aussi l’APK release non signé ou signé uniquement avec une configuration sécurisée déjà disponible. N’invente pas la réussite d’un build ou d’un essai appareil.
>
> **8. Livrer le résultat.** Localise l’APK produit, vérifie qu’il existe et n’est pas vide, note son chemin, son poids et son SHA-256. Vérifie package, version, manifeste et permissions de l’APK avec les outils Android disponibles. Fournis directement le fichier APK installable et un court relevé indiquant le type de build, les vérifications réussies, les avertissements connus et les essais qui nécessitent un téléphone réel. Ne publie pas l’application sur un store et ne déploie rien sans demande explicite.
>
> À la fin, mets à jour `PROJECT_PROGRESS.md`, commit et pousse immédiatement le lot terminé. Dans le compte rendu final, fournis le lien direct vers l’APK si le build a réussi ; sinon, indique clairement le blocage et les artefacts effectivement produits.

## Contrôles de livraison attendus

| Domaine | Résultat attendu |
|---|---|
| Plateforme | Dossier Android Flutter complet, versionné et reproductible |
| Identité | Libellé `IziCard Manager` et identifiant Android stable |
| NFC | Permission présente, fonctionnalité déclarée facultative, manifeste final vérifié |
| Visuels natifs | Icône adaptative/densités et splash conformes au logo fourni |
| Liens et navigation | Uniquement les schémas réellement définis, filtres Android vérifiés |
| Qualité | Résultats réels de `flutter analyze`, `flutter test` et build APK rapportés |
| Sécurité | Aucun chemin SDK local, secret ou clé de signature dans le dépôt |
| Livraison | APK vérifié, chemin, taille et SHA-256 communiqués |
