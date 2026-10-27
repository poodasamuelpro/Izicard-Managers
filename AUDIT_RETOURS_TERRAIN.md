# Audit des retours terrain (27/10/2026)

> **Mise à jour (lot M25) : tout est corrigé dans le code SAUF le nom (IziCardOuaga) et le design, laissés à part sur demande.** Les corrections ne sont ni compilées ni testées (pas de Flutter ici) : contrôler par un build GitHub puis un essai sur le téléphone. La migration SQL 007 du dépôt web doit être exécutée dans Supabase. Détail du correctif par point : section « Corrigé (M25) » en fin de document. Le texte ci-dessous décrit l'état avant correction.

Méthode : lecture du code (mobile `Izicard-Managers`, web `izicard-managers-web`, migrations SQL) et des 8 captures d'écran de l'APK installé. **Rien n'a été modifié** hors le lien d'invitation (corrigé côté web, lot W6). Aucun correctif ci-dessous n'est testé.
Priorité : P1 bloque l'usage, P2 gêne fortement, P3 confort.

## 0. Corrigé : lien d'invitation « expiré » (dépôt web, lot W6)
- Cause probable : le lien Supabase `{{ .ConfirmationURL }}` est à usage unique ; un aperçu/scanner d'email (Gmail, antivirus) l'ouvre avant vous. De plus, `set-password.js` ne lisait pas l'erreur renvoyée par le lien et testait la session trop tôt. Non reproduit, hypothèse la plus courante.
- Correction : nouveau lien `?token_hash=…&type=invite`, jeton consommé seulement au clic « Activer mon accès ».
- **À faire par vous** : coller `supabase/email_templates/invite.html` dans Supabase > Authentication > Email Templates > Invite user ; Site URL = `https://manager.izicardouaga.com` ; déployer le web. Les invitations déjà envoyées gardent l'ancien lien : en renvoyer.

## 1. Vérification d'un tag (P2)
**Ce que ça fait** (`verify_tag_screen.dart`) : (1) lit l'UID ; (2) cherche cet UID dans la base (`findByUid`, limité à ce que votre compte a le droit de voir) ; (3) compare le contenu NDEF lu au payload attendu. Inconnu ⇒ « Tag inconnu ou non autorisé ».
**Écarts :**
- « Inconnu » mélange 3 cas : tag étranger (pas IziCard), tag IziCard d'un autre client, tag non encore enregistré. Aucune distinction.
- Pour un tag inconnu, le contenu lu n'est pas affiché : impossible de savoir s'il porte un lien IziCard, du texte, ou rien.
- Le modèle de puce (NTAG213/215/216) n'est ni lu ni comparé au format de la carte ; l'état verrouillé non plus.
- Capture : UID `04C19401700000` (7 octets finissant par des zéros) : à contrôler, une lecture tronquée est possible (non vérifié).
**Proposition :** résultat en 2 blocs « Appartenance » (UID connu ? à quel dossier/client ? sinon « tag non IziCard ») et « Contenu » (conforme / différent / vide, avec le contenu lu affiché), + modèle de puce lu vs attendu + verrouillé oui/non.

## 2. Types « NTAG213 » presque partout (réponse)
Ce n'est pas l'app qui l'exige : c'est la table `nfc_card_formats` (migration 001), colonne `chip`, valeur par défaut `NTAG213` dans les formats d'origine (capacité 144 octets, liens et textes courts). Seuls sont en NTAG215 : fiche contact vCard et « Membre/événement » ; en NTAG216 : IziCare données directes. L'app affiche simplement `label · chip`. Ce n'est donc pas une limite de l'app : on peut changer la puce d'un format ou en ajouter (SQL ou écran admin). Non vérifié : si l'écriture refuse une puce différente de celle du format.
**Proposition :** permettre au choix « puce » d'être modifiable à la création, ou afficher « NTAG213 (144 octets) » avec une aide ; vérifier à l'écriture la puce réelle contre la capacité.

## 3. Dossiers, clients et pages non reliées (P1)
**Constats dans le code :**
- `batch_create_screen.dart` : l'admin doit choisir un client ; sans client, message « Aucun client disponible. Ajoutez un client… » sans bouton pour en créer.
- Base : `nfc_batches.client_id` est `NOT NULL` et `nfc_create_batch` lève « Client introuvable ». Un dossier **sans client** est impossible aujourd'hui, donc « pour soi-même » aussi.
- Un client ne crée que si `can_create_batches` est vrai (règle serveur, migration 004).
- Écriture : `write_screen.dart` n'affiche que « Aucun dossier disponible » ; l'écriture d'une seule carte (`single_write_screen`) n'est atteignable que via Dossier > carte : pas d'écriture libre d'une carte.
- Import : sélection d'un dossier obligatoire (`batchId`), aucun import sans dossier ni sans client.
- Aucun raccourci entre pages (client ⇄ dossier ⇄ import ⇄ écriture) : il faut sortir et revenir.
**Propositions :**
1. Dossier « personnel » : soit un client interne (ex. « IziCard — usage interne ») créé une fois et proposé par défaut (aucun changement de schéma, rapide), soit rendre `client_id` nullable avec droits admin uniquement (changement de schéma + RLS, plus lourd).
2. Dans la création de dossier : bouton « + Nouveau client » (ouvre le formulaire client et revient avec le client sélectionné).
3. Fiche client : bouton « Créer un dossier » quand il n'y en a pas.
4. Écriture : mode « Carte unique » (saisir les données, écrire sans dossier, option de l'enregistrer ensuite) en plus du mode dossier ; si aucun dossier, bouton « Créer un dossier ».
5. Import : « Importer vers… » avec choix « nouveau dossier » ou « dossier existant » créé à la volée ; fichier lisible sans client préalable.
6. Règle de conception : tout écran qui exige une donnée manquante propose de la créer sur place puis revient.
7. Décision à prendre : `can_create_batches` (un client crée librement ses dossiers, comme demandé) = supprimer le contrôle dans `nfc_create_batch` pour le client propriétaire, ou mettre la valeur par défaut à vrai.

## 4. Réinitialisation du mot de passe (P1, cause trouvée)
Le code de récupération (OTP) déclenche l'événement Supabase `passwordRecovery`. `app.dart` (l.186-188) passe alors `_passwordSetup = true` et affiche `PasswordSetupScreen` ; ce drapeau **n'est jamais remis à faux** (seules lignes : 99, 188, 221). Or `password_reset_screen.dart` a son propre écran « nouveau mot de passe ». Résultat : deux écrans pour la même action ; le premier change bien le mot de passe, le second repart sur une session déjà fermée/consommée et affiche « lien peut-être expiré ». Sortir et revenir remet le drapeau à faux, d'où le contournement observé.
**Proposition :** un seul écran. Soit supprimer l'étape 2 de `password_reset_screen` (laisser `PasswordSetupScreen`), soit ignorer l'événement `passwordRecovery` quand le flux OTP est en cours ; dans les deux cas remettre `_passwordSetup = false` après `updatePassword` + déconnexion et revenir à la connexion avec un message « Mot de passe mis à jour ».

## 5. Nom et design (P2/P3)
- Nom : le titre de l'app Flutter est « IziCard Manager », la barre d'accueil « IziCard », le web « IziCard ». Vous voulez « IziCardOuaga ». À harmoniser : `app.dart` (title), `home_screen.dart` (AppBar), `android:label`, textes web, e-mails. (Le marquage actuel suit le brief Android initial : « IziCard Manager ».)
- Observations sur les captures (écran d'accueil admin) : liste verticale de grandes cartes texte, une seule colonne, icônes monochromes, aucune image ni illustration ; la première moitié de l'écran est prise par l'en-tête. Peu hiérarchisé : actions fréquentes (écrire une carte, vérifier un tag) noyées entre des écrans de gestion.
- Proposition mobile-first : accueil en 2 zones : (a) 2 grandes actions rapides « Écrire une carte » et « Vérifier un tag » ; (b) grille 2 colonnes pour Dossiers, Clients, Import, Export, Sync, Réglages, avec compteurs (cartes à écrire, tags vérifiés) ; barre de navigation en bas à 4-5 entrées ; états vides illustrés avec action (« Créer un client »). Utiliser le logo/visuels de marque, cohérence clair/sombre déjà en place.
- Non audité : accessibilité, tailles tactiles, autres écrans que ceux des captures.

## 6. Autres points relevés
- Clé `anon` du web (`config.js`) : le contenu décodé n'indique pas de rôle `anon` explicite (à vérifier dans Supabase).
- Trigger `on_auth_user_created` (projet partagé) : corrigé côté base par vous ; garder la fonction tolérante.
- Rien n'a été testé sur appareil par moi ; les captures montrent seulement l'état affiché.

## Ordre conseillé
1. Publier le lien d'invitation (§0) et vérifier.  2. Mot de passe (§4, petit).  3. Dossier personnel + création client à la volée + écriture carte unique + import libre (§3).  4. Vérification de tag enrichie (§1).  5. Nom + accueil (§5).  6. Puces (§2).

## Corrigé (M25)
- **§0 Lien d'invitation** : voir lot W6 (web).
- **§1 Vérification de tag** : deux résultats séparés, « 1. Appartenance » (UID enregistré ou non) et « 2. Contenu » (conforme / différent / non comparé), contenu réellement lu affiché (lien, texte, vCard), puce probable déduite de la capacité. Non fait : détection fiable de l'état verrouillé et comparaison avec la puce prévue par le format. Le doute sur l'UID `04C19401700000` reste à vérifier avec un autre tag.
- **§2 Puces** : question répondue (valeur par défaut des formats en base) ; aucun changement de code.
- **§3 Dossiers / clients / pages reliées** :
  - Dossier « Mes propres cartes (usage interne) » : un client interne « IziCardOuaga — usage interne » est créé automatiquement (admin) et présélectionné. Choix fait sans attendre votre réponse : pas de changement de schéma.
  - Création de dossier : bouton « Nouveau client » qui crée le client puis le présélectionne ; plus de blocage si aucun client.
  - Liste des clients : bouton « Créer un dossier » par client.
  - Page Dossiers : bouton « Nouveau client » (admin).
  - Écriture : « Écrire une seule carte (sans dossier) » (nouvel écran, écriture non enregistrée en base) et bouton « Créer un dossier » quand aucun dossier.
  - Import : bouton « Créer un dossier » quand aucun dossier ; plus besoin d'un client existant grâce au client interne.
  - Un client actif crée librement ses dossiers (profil mobile, accès web et migration SQL 007). L'interrupteur « autoriser la création » est retiré de l'application mobile.
- **§4 Mot de passe** : un seul écran ; les événements de session sont ignorés pendant la réinitialisation, la session ouverte par le code est fermée après le changement ou si l'écran est abandonné, retour à la connexion avec le message « Mot de passe mis à jour ».
- **§5 Nom et design** : non traités (demande de l'utilisateur).
- **Limites** : l'import reste attaché à un dossier (créé à la volée) ; l'écriture d'une seule carte n'enregistre rien dans la base ; l'interrupteur « can_create_batches » du web (`clients.js`) existe encore mais n'a plus d'effet.

## Complément (M26)
- **Nom** : l'application reste « IziCard Manager » partout (titre, accueil, libellé Android, textes). Les textes « IziCardOuaga » ajoutés en M25 sont remplacés ; le client interne s'appelle désormais « IziCard Manager — usage interne » (l'ancien nom « IziCardOuaga — usage interne » est reconnu s'il existe déjà).
- **Lecture de tag** : l'écran affiche maintenant toutes les données lues : UID et sa longueur, fabricant (d'après l'UID), technologies, ATQA, SAK, famille MIFARE Ultralight/NTAG, puce probable (capacité NDEF), NDEF pris en charge, écriture autorisée ou verrouillée, et TOUS les enregistrements NDEF avec type, taille et contenu (vCard complète). Chaque donnée technique est lue « au mieux » : si le téléphone ou la puce ne la fournit pas, elle est simplement absente. Ce n'est pas encore l'équivalent complet d'un outil comme NXP TagInfo (pas de lecture brute de la mémoire page par page, pas de signature d'origine, pas de compteurs).
- **Écriture d'une seule carte** : la carte est maintenant ENREGISTRÉE dans la base (dossier automatique « Cartes uniques — Lien/Texte/Téléphone/Email », client interne pour l'admin ou compte du client), puis écrite et vérifiée par l'écran d'écriture d'une carte, qui enregistre le résultat (statut, UID, verrouillage). Connexion requise. Si l'écriture est annulée, la carte reste « en attente » dans ce dossier.
- **Import** : bouton « Nouveau dossier » (nom + format) directement dans l'écran d'import et quand aucun dossier n'existe ; plus besoin de client ni de passer par une autre page. Le dossier est rattaché au client interne (admin) ou au compte du client.
- Non vérifié : rien n'est compilé ni testé. Les lectures ATQA/SAK/technologies passent par un accès dynamique protégé (une erreur de nom d'API ne bloque pas la compilation mais ferait disparaître la donnée).
