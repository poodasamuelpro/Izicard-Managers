# Suivi du projet mobile IziCard

Ce fichier est la référence obligatoire de l’avancement du dépôt mobile.

## Règle de mise à jour

Après **chaque** modification, correction ou fonctionnalité, une entrée doit être ajoutée ici avec :

- la date et l’heure en UTC ;
- le périmètre concerné ;
- ce qui est terminé ;
- ce qui est partiel ou non terminé ;
- ce qui reste à faire ;
- le commit Git correspondant lorsqu’il existe.

Aucune modification ne doit être considérée comme terminée sans cette mise à jour.

## État initial — 2026-10-25 08:46:54 UTC

### Terminé

- Dépôt Flutter Android créé.
- Structure mobile NFC initiale importée.
- Logo IziCard ajouté dans `assets/images/logo.jpg`.
- Logo déclaré comme asset Flutter.
- Architecture fonctionnelle documentée dans `MOBILE_ARCHITECTURE.md`.
- Dépôt GitHub privé relié et synchronisé.

### Partiel / non terminé

- Supabase est maintenant initialisé nativement dans le code Flutter.
- Connexion par email + code OTP implémentée côté application.
- Déconnexion implémentée côté application.
- Le parcours de réinitialisation par mot de passe est volontairement exclu de cette phase.
- Écrans UI/UX finaux non implémentés.
- Configuration Resend non effectuée côté Supabase.
- Aucun secret serveur ou clé `service_role` ne doit être ajouté au dépôt.

### Prochaine étape validée

Finaliser et valider le socle OTP Supabase côté mobile :

1. configuration par variables de build ;
2. initialisation du client Supabase ;
3. envoi du code OTP par email ;
4. validation d’un code à 8 chiffres ;
5. déconnexion et nettoyage local ;
6. tests et mise à jour de ce fichier.

## Plan Supabase et Resend

- L’application utilisera uniquement l’URL Supabase et la clé publishable/anon côté client.
- La clé `service_role` restera exclusivement côté serveur et ne sera jamais embarquée dans Flutter.
- Les règles RLS et les fonctions SQL resteront l’autorité pour les droits d’accès.
- Supabase Auth gérera les sessions, la connexion, la déconnexion et les tokens.
- Le parcours retenu est un accès par code OTP ; aucune réinitialisation par mot de passe n’est prévue dans cette phase.
- Resend sera utilisé uniquement comme fournisseur d’envoi SMTP de Supabase Auth pour le code OTP et, si activée, la confirmation de compte.
- Aucune clé API Resend ne sera stockée dans l’application mobile.
- Les clés publishable fournies seront injectées via configuration de build ou fichier local ignoré par Git, jamais via une clé serveur.

## Documentation et suivi — 2026-10-25 08:47:09 UTC

### Terminé

Le fichier de suivi racine a été créé. Le README documente désormais la règle de traçabilité, la séparation des responsabilités web/mobile, la configuration Supabase côté client et l’usage minimal de Resend. Le fichier `.env.example` contient uniquement des placeholders pour l’URL et la clé publishable Supabase.

### Partiel / non terminé

La configuration SMTP Resend doit être effectuée dans le projet Supabase, sans ajouter de clé Resend au dépôt. La longueur de 8 chiffres doit être configurée et vérifiée côté Supabase ; l’application refuse tout code qui ne comporte pas exactement 8 chiffres.

### Reste à faire

Tester sur un appareil Android le socle Auth Supabase : envoi OTP, validation, session, déconnexion et gestion des erreurs.

### Commit

Commit : à renseigner après le commit de l’implémentation OTP.

## Authentification OTP — 2026-10-25 08:50:30 UTC

### Terminé

Supabase Flutter natif est initialisé via `SUPABASE_URL` et `SUPABASE_ANON_KEY`. Le flux comprend la saisie d’email, l’envoi d’un OTP, la saisie et validation d’un code de 8 chiffres, la persistance de session via Supabase Auth, la déconnexion et l’écran d’accueil de session. Le logo et la charte IziCard sont utilisés par les écrans de connexion et d’accueil.

### Partiel / non terminé

Flutter n’est pas installé dans cet environnement, donc l’analyse statique et l’exécution sur Android n’ont pas encore été réalisées. Le serveur Supabase doit être configuré pour envoyer les emails et accepter le format OTP de 8 chiffres. La connexion est limitée aux utilisateurs déjà créés (`shouldCreateUser: false`).

### Reste à faire

Configurer et tester l’OTP côté Supabase, installer/valider Flutter, ajouter les tests Auth, puis construire les écrans dossiers et NFC.

### Commit

Commit : 001c266

## Socle Supabase OTP — 2026-10-25 08:51:30 UTC

### Terminé

L’application initialise Supabase avec `supabase_flutter`. Le parcours de connexion demande une adresse email, envoie un OTP via `signInWithOtp`, vérifie un code composé exactement de 8 chiffres via `verifyOTP`, conserve la session Supabase et propose la déconnexion. Les écrans utilisent le logo IziCard et la palette cyan/bleu. Aucun parcours de réinitialisation par mot de passe n’a été ajouté.

### Partiel / non terminé

Flutter n’est pas installé dans cet environnement : aucun `flutter pub get`, `flutter analyze` ou build Android n’a pu être exécuté. L’instance Supabase doit être configurée pour l’envoi des emails et le format OTP de 8 chiffres. Le code n’autorise pas l’inscription automatique (`shouldCreateUser: false`) : les comptes doivent exister côté Supabase.

### Reste à faire

Configurer Supabase Auth et SMTP Resend, vérifier la longueur réelle de l’OTP côté serveur, tester le parcours sur Android, puis ajouter la gestion des rôles et des écrans dossiers/NFC.

### Commit

Commit : 001c266

## Correction Auth et fournisseur email — 2026-10-25 08:57:57 UTC

### Terminé

Le parcours mobile a été corrigé pour utiliser la clé Supabase `anon`, la connexion email + mot de passe et la déconnexion. Le mot de passe oublié demande l’email, vérifie un code de récupération de 8 chiffres, puis permet de définir un nouveau mot de passe. L’ancien prototype OTP-only a été retiré. Toutes les instructions email utilisent désormais Resend, configuré uniquement côté Supabase.

### Partiel / non terminé

La configuration Resend dans Supabase doit encore être vérifiée manuellement. Flutter n’est pas installé dans cet environnement, donc `flutter pub get`, l’analyse et le test Android restent à effectuer.

### Reste à faire

Configurer Resend dans **Authentication > SMTP Settings**, régler `mailer_otp_length` à `8`, appliquer le template Recovery IziCard, tester la récupération sur Android, puis terminer l’authentification web et les contrôles de rôle.

### Commit

À renseigner après le commit de cette correction.

## Réalignement demandé — 2026-10-25 08:58:37 UTC

### Terminé

La configuration client Flutter utilise maintenant `SUPABASE_ANON_KEY`. Le parcours mobile utilise `signInWithPassword` pour la connexion, `signOut` pour la déconnexion, `resetPasswordForEmail` pour demander la récupération, `verifyOTP` de type recovery pour le code de 8 chiffres et `updateUser` pour enregistrer le nouveau mot de passe. Le fournisseur email documenté et retenu est Resend uniquement. Le guide Supabase/Resend est présent dans `SUPABASE_SETUP.md`.

### Partiel / non terminé

La longueur OTP doit être réglée à 8 dans la configuration Auth Supabase et le template Recovery doit afficher `{{ .Token }}`. Resend doit être vérifié manuellement dans **Authentication > SMTP Settings**. Flutter n’est pas installé ici, donc l’analyse et le build Android restent à exécuter.

### Reste à faire

Tester connexion, déconnexion et récupération de mot de passe avec un utilisateur Supabase réel, puis poursuivre les écrans de dossiers et d’encodage NFC.

### Commit

Commit : 63f31d0


## Backend unique et parité admin Web/mobile — 2026-10-25 09:19:00 UTC

### Terminé

Les README et documents d’architecture précisent que l’application mobile et l’espace admin Web partagent un backend/API unique, le même projet Supabase, les mêmes tables, fonctions serveur/RPC et règles RLS. La parité des fonctions admin est requise, notamment gestion des clients et accès, création/suivi des dossiers, import/export et autres opérations métier. Les règles métier doivent être centralisées côté backend, et non recodées indépendamment en Flutter.

### Partiel / non terminé

La documentation décrit l’architecture cible ; elle ne confirme pas que les écrans mobiles couvrent déjà toutes les opérations Web. Les tests fonctionnels non indispensables sont reportés.

### Reste à faire

Construire les écrans admin mobiles manquants, les relier aux mêmes opérations du backend/API que le Web et vérifier les fonctions nécessitant un test.

### Commit

Modifications locales, commit à renseigner s’il est créé.


## Rôles, UX et schéma `nfc` — 2026-10-25 09:22:00 UTC

### Terminé

La documentation mobile et le guide Supabase exigent l’usage du schéma PostgreSQL `nfc` pour toutes les données et RPC NFC, un profil/rôle chargé depuis `nfc.nfc_profiles`, un accueil adapté au rôle et des autorisations appliquées par le backend/RLS. Les critères UX/UI professionnels et sécurisés sont précisés. Le template Recovery demandé, avec code cyan `#01A3CA`, est documenté. Les tests de connexion sont explicitement différés.

### Partiel / non terminé

Le code mobile n’a actuellement pas de chargement effectif du profil/rôle : les fichiers remote/profile sont des squelettes et `AuthGate` envoie tout utilisateur connecté vers un accueil générique. La migration des objets métier depuis `public` vers `nfc` n’est pas faite.

### Reste à faire

Migrer/qualifier les objets backend dans le schéma `nfc`, puis implémenter profil/rôle, garde d’accès, accueil et navigation par rôle, écrans admin/client et appels à l’API partagée. Appliquer les critères UX/UI sans lancer les tests de connexion avant demande.

### Commit

Commit documentaire à renseigner s’il est créé.


## Routage par rôle et socle UI mobile — 2026-10-25 09:30:00 UTC

### Terminé

- Le client PostgREST mobile utilise `nfc` comme schéma par défaut ; les requêtes de profil/client utilisent explicitement `.schema(AppConstants.nfcSchema)`.
- Après authentification, `AuthGate` charge `nfc.nfc_profiles`, vérifie le rôle, les statuts actif/expiration et l’accès du client via `nfc.nfc_clients`.
- Le routage distingue les accueils Admin et Client. Les destinations contrôlent les rôles et le droit `can_create_batches`; les profils absents, expirés, révoqués ou en erreur ont des états dédiés.
- Première refonte UI/UX : thème Material 3 IziCard, écran de connexion accessible, tableaux de bord par rôle, navigation retour et écrans de destination transparents sur l’avancement.

### Partiel / non terminé

Les écrans de destination sont des squelettes de navigation : clients, dossiers, création, import/export, NFC, vérification, synchronisation et réglages ne sont pas encore reliés aux fonctions métier. Le SQL partagé du dépôt Web crée encore les objets dans `public`; le chargement profil en `nfc` ne fonctionnera qu’après migration/exposition du schéma et application des RLS/grants correspondants. Aucun test de connexion n’a été lancé, conformément à la demande. Flutter et Dart ne sont pas installés dans cet environnement ; aucun `flutter analyze`, formatage Dart ou build Android n’a donc été exécuté.

### Reste à faire

1. Migrer les objets SQL partagés et leurs fonctions/types/RLS vers le schéma `nfc` puis l’exposer dans Supabase.
2. Raccorder chaque écran aux opérations serveur partagées et construire les fonctions admin/client complètes, sans logique métier dupliquée.
3. Vérifier ultérieurement le rendu, la compilation et les parcours fonctionnels quand Flutter/environnement et autorisation de test seront disponibles.

### Commit

`7a999ce` — poussé sur `master`.


## Migration Supabase `nfc` confirmée — 2026-10-25 09:40:00 UTC

### Terminé

Le propriétaire confirme que la migration des objets Supabase vers le schéma `nfc` est maintenant déployée. Le client Flutter est configuré pour utiliser `nfc` et le chargement du profil le cible explicitement.

### Partiel / non terminé

Le script historique du dépôt Web `supabase/migrations/001_nfc.sql` utilise encore `public` et doit être réaligné pour les installations futures. Aucun test de connexion n’a été lancé.

### Reste à faire

Poursuivre les écrans et raccordements métier mobile décrits dans l’entrée précédente ; vérifier RLS/exposition et tester les parcours lorsque cela sera autorisé.

### Commit

`061afd3` — poussé sur `master`.


## Dossiers et gestion des accès clients dans l’app — 2026-10-25 09:54:00 UTC

### Terminé

- Remplacement des squelettes de modèles/remote/repository pour les clients, formats et dossiers par des lectures ciblant explicitement le schéma `nfc`.
- Écran Dossiers relié à `nfc.nfc_batch_stats`, avec filtres, compteurs, progression, états vide/erreur/chargement et détail de dossier.
- Création d’un dossier depuis l’app reliée à la RPC Supabase `nfc_create_batch`, avec sélection du client (admin), format actif, type de données, quantité et option de verrouillage ; les rôles/droits existants restent contrôlés par l’UI et la fonction serveur.
- Écran Admin Clients relié à `nfc.nfc_clients` ; activation/révocation et expiration utilisent la RPC existante `nfc_set_access`.
- Le routeur par rôle ouvre désormais ces vrais écrans pour les destinations Dossiers, Créer un dossier et Clients. Aucun serveur intermédiaire/Edge Function n’a été ajouté.

### Partiel / non terminé

Les fonctions Import Excel, liste et écriture/rélecture physique des tags NFC, vérification, export, synchronisation hors-ligne et réglages restent à raccorder. L’ajout d’un client et la création/liaison de son compte Supabase Auth ne sont pas inclus ; aucune clé privilégiée n’est embarquée. La connexion réelle et la compilation Flutter n’ont pas été testées. Flutter/Dart ne sont pas installés dans l’environnement.

### Reste à faire

1. Terminer la gestion du cycle de vie client/profil sans clé `service_role` dans l’application.
2. Implémenter l’import (choix/lecture du fichier, aperçu/correspondance) puis appeler `nfc_import_rows` avec limites et traitement d’erreurs.
3. Implémenter l’écriture/rélecture NFC Android, appeler `nfc_mark_written` après chaque résultat et gérer les erreurs/synchronisations sans contourner les RLS.
4. Compléter export, progression temps réel ou rafraîchie, UX hors-ligne si requise et réglages.
5. Plus tard, effectuer l’analyse/build Android et les vérifications de connexion autorisées.

### Commit

`3737ff2` — poussé sur `master`.

## Création de dossiers réservée aux admins — 2026-10-25 10:01:00 UTC

### Terminé

- Le contrôle Flutter mobile réserve désormais la destination et les commandes de création de dossiers au rôle `admin` uniquement. L’ancien indicateur client `can_create_batches` n’accorde plus ce droit.
- Le formulaire vérifie lui-même le rôle admin avant de charger ses options ou de soumettre une création ; un profil non-admin ne voit pas les champs de création.

### Partiel / non terminé

- Le contrôle serveur de la RPC `nfc_create_batch` doit également être mis à jour par une migration SQL afin que l’autorisation admin-only soit imposée côté backend (y compris pour les appels Web/API). Cette migration n’est pas réalisée dans ce dépôt Flutter.
- Aucun test de connexion n’a été effectué. Aucun test/build Flutter n’a été lancé (Flutter absent).

### Reste à faire

Créer et déployer la migration SQL mettant à jour la RPC, puis vérifier les autorisations côté serveur et effectuer les validations Flutter/connexion uniquement quand l’environnement et l’autorisation seront disponibles.

### Commit

Aucun commit créé, conformément à la demande.


## Invitation administrée et dossiers attribués — 2026-10-25 10:10:30 UTC

### Terminé / alignement

- Le propriétaire confirme le parcours : IziCard Admin crée manuellement le client et l’invite par email ; l’utilisateur accepte l’invitation, définit son mot de passe et peut ensuite se connecter sur Web ou Android. Aucun parcours d’auto-inscription client n’est autorisé.
- Le Web prépare la fonction Supabase partagée `create-client-user`, qui crée le profil `client` et relie son `client_id`. Le mobile réutilisera cette même fonction pour une future création/invitation Admin depuis l’app, sans clé `service_role` dans Flutter.
- L’Admin est seul à créer un dossier ; le formulaire Admin choisit le client afin qu’à la connexion le client voie ses dossiers attribués via les RLS.

### Non vérifié / reste

La fonction d’invitation et le patch SQL admin-only sont écrits dans le dépôt Web, mais ne sont pas déployés/appliqués à Supabase. Aucun compte ni email n’a été créé ou envoyé. Le parcours d’invitation mobile reste à implémenter. Aucun test de connexion, analyse ou build Flutter n’a été exécuté (Flutter absent).

### Commit

`08a42f7` — poussé sur `master`.


## Invitation Admin depuis Android — 2026-10-25 10:23:50 UTC

### Terminé

- L’écran mobile Admin « Clients et accès » permet maintenant d’ouvrir un vrai formulaire « Inviter un client ».
- Le formulaire valide le nom, l’email, le nom de l’organisation et les coordonnées facultatives.
- Le mobile appelle la même Edge Function Supabase `create-client-user` que le Web via `functions.invoke` ; aucun `service_role` n’est embarqué.
- Le compte Auth, le client `nfc_clients` et le profil `nfc_profiles` restent créés côté serveur avec le rôle `client` et le même `client_id`.
- Après succès, la liste mobile est rafraîchie. La gestion d’accès existante reste disponible.

### Partiel / non vérifié

Flutter/Dart n’est pas installé dans cet environnement : aucun `flutter analyze`, test Android ou build n’a pu être exécuté. Le déploiement de la fonction Edge, SMTP Resend et le test réel d’envoi restent à faire dans Supabase.

Les écrans mobiles Import, Export, Écriture NFC, Vérification, Synchronisation et Réglages restent des modules de présentation non raccordés, contrairement aux écrans Clients, Dossiers et Création de dossier.

### Reste à faire

1. Déployer et tester `create-client-user` avec SMTP Resend et un compte Admin réel.
2. Raccorder les modules Import/Export/Écriture/Vérification/Synchronisation/Réglages au backend partagé.
3. Installer Flutter ou utiliser GitHub Actions pour exécuter l’analyse, les tests et le build Android.

### Commit

`8349d67` — `feat(admin): invite clients from mobile`


## Activation client sur Android — 2026-10-25 10:31:30 UTC

### Terminé dans le code

- Écran mobile `PasswordSetupScreen` créé avec validation du mot de passe et confirmation.
- L’écran est affiché sur l’événement Supabase `passwordRecovery`, enregistre le mot de passe puis ferme la session pour permettre une reconnexion normale.
- Le parcours rappelle que le même mot de passe est utilisable sur Web et Android.

### Partiel / non vérifié

Flutter n’est pas installé : aucun analyseur, test ou build n’a pu être exécuté. Le deep link Android d’invitation doit encore être déclaré dans Auth URL et dans le manifeste avant distribution. Le parcours Web `set-password.html` est le fallback officiellement documenté.

### Reste à faire

Configurer la redirection réelle vers la page d’activation, ajouter le deep link Android si souhaité, puis tester une invitation réelle avec le même compte sur Web et mobile.

### Commit

`ec5b8c0` — `feat(auth): add mobile password activation`


## Import Excel/CSV — état réel et actions manuelles — 2026-10-25 10:35:55 UTC

### Fonctionnement prévu

Depuis un dossier, l’utilisateur autorisé choisit un fichier `.xlsx`, `.xls` ou `.csv`. L’application doit lire le fichier localement, détecter et normaliser les colonnes, proposer une correspondance automatique avec les champs du format, permettre la correction manuelle, afficher un aperçu, valider les champs obligatoires puis appeler la même RPC backend `nfc_import_rows` que le Web par paquets. Les erreurs doivent être retournées ligne par ligne sans bloquer les lignes valides. Les données importées alimenteront ensuite la file d’écriture NFC et la synchronisation.

### État réel actuel

Les fichiers mobiles `lib/services/import/excel_reader.dart`, `lib/features/import/import_screen.dart`, `lib/features/import/mapping_screen.dart`, `lib/features/import/preview_screen.dart` et `lib/features/import/import_result_screen.dart` sont encore des squelettes. L’import Excel/CSV mobile ne fonctionne donc pas réellement aujourd’hui et aucun fichier n’est encore envoyé à Supabase.

### Actions manuelles à faire par le propriétaire dans Supabase/Resend

- Activer Email dans Supabase Auth et désactiver l’auto-inscription publique.
- Configurer SMTP Resend avec une adresse expéditeur et un domaine vérifiés.
- Régler l’OTP à 8 chiffres et coller les templates Recovery et Invite user.
- Autoriser l’URL Web `set-password.html` et le futur deep link Android dans **Authentication > URL Configuration**.
- Déployer `create-client-user` avec `SUPABASE_SERVICE_ROLE_KEY` dans les secrets et `INVITE_REDIRECT_TO` vers la page d’activation.
- Vérifier l’exposition PostgREST/RPC du schéma `nfc`, les grants et les politiques RLS.
- Appliquer le patch SQL qui réserve `nfc_create_batch` aux Admins.
- Vérifier ou créer le profil Admin actif initial dans `nfc.nfc_profiles`.
- Publier l’APK Android et remplacer le lien temporaire de `/app.html` par le vrai lien de téléchargement.
- Tester invitation, activation, connexion, accès client et isolation des dossiers avant production.

### Reste à faire dans le code

Implémenter le lecteur `.xlsx/.xls/.csv`, la correspondance automatique/modifiable, l’aperçu, la validation, l’appel par paquets à `nfc_import_rows`, le bilan d’import et le stockage local nécessaire avant écriture NFC. Garder exactement les mêmes règles et la même RPC que le Web.

### Commit

Modification documentaire uniquement ; commit à renseigner s’il est créé.


## Précision fonctionnelle Excel — champs partagés du backend — 2026-10-25 10:38:50 UTC

La description précédente était trop générique. L’Excel ne sert pas seulement à fournir des colonnes : chaque ligne devient une carte et les cellules sont mappées vers le `field_schema` du format sélectionné, exactement comme dans la migration SQL et le Web.

Les formats partagés prévoient notamment : IziCare (`full_name`, `birth_date`, `blood_group`, `allergies`, `conditions`, `medications`, contacts d’urgence et `ref`), IziPro (`full_name`, `title`, `org`, `phone`, `email`, `website`, `linkedin`, `ref`), IziID (`full_name`, `birth_date`, `blood_group`, `address`, contacts d’urgence et `ref`), lien personnalisé (`_payload`, `ref`), texte personnalisé (`_payload`, `ref`), vCard (`full_name`, `phone`, `email`, `org`, `title`, `website`) et téléphone (`phone`, `ref`). Les champs obligatoires sont définis par format, pas arbitrairement par l’interface.

La reconnaissance utilise les alias définis dans `field_schema` : par exemple `nom`, `nom complet`, `nom et prenom`, `name` et `beneficiaire` peuvent correspondre à `full_name`; `telephone`, `tel`, `mobile`, `portable` et `whatsapp` à `phone`. Les clés `_payload` et `_type` sont spéciales. Le type du dossier détermine le mode lien/direct, le payload NDEF est généré côté RPC, les cellules vides sont retirées et la capacité de la puce est contrôlée.

La RPC commune est `nfc_import_rows(p_batch, p_rows, p_filename, p_mapping)`. Elle remplit d’abord les cartes vierges, crée les cartes supplémentaires, conserve les erreurs par numéro de ligne et ne bloque pas toutes les lignes lorsqu’une ligne échoue.

Le code Flutter de lecture/mapping/aperçu reste toutefois à implémenter : ces règles sont actuellement dans la migration et l’architecture, pas encore dans les écrans mobiles squelettes.


## Socle hors-ligne et écran de synchronisation — 2026-10-25 11:03:00 UTC

### Terminé dans le code

- Dépendances ajoutées pour SQLite, le chemin de base locale et la connectivité.
- `AppDatabase` crée les tables locales `offline_batches` et `pending_writes`, avec index et fermeture propre.
- `PendingWritesDao` permet d’ajouter, compter, lire, marquer une tentative et supprimer les résultats synchronisés.
- `TagsRemote` appelle la RPC commune `nfc_mark_written`.
- `SyncRepository` envoie la file séquentiellement, supprime uniquement les opérations confirmées et conserve la file lorsqu’une erreur réseau ou backend survient.
- `ConnectivityService` détecte le retour réseau.
- `SyncWorker` lance une synchronisation au retour en ligne.
- `SyncStatusScreen` affiche l’état, les opérations en attente et un bouton de synchronisation manuelle. La route mobile Synchronisation ouvre maintenant cet écran réel.

### Partiel / non terminé

Le socle est prêt mais le contrôleur d’écriture NFC n’est pas encore raccordé pour appeler automatiquement `enqueueWrite` après chaque écriture/relecture. Le téléchargement local complet des dossiers et des tags reste à brancher. Flutter n’est pas installé dans cet environnement, donc aucun `flutter pub get`, analyse, test ou build n’a été exécuté.

Les autres modules Import, Export, Écriture, Vérification et Réglages restent à finaliser. L’harmonisation visuelle est engagée par les thèmes/états communs, mais la parité fonctionnelle complète Web/mobile n’est pas encore atteinte.

### Reste à faire

Raccorder la file au contrôleur NFC, persister les dossiers/tags téléchargés, gérer les conflits et l’accès révoqué, puis exécuter les tests et vérifier le rendu sur plusieurs tailles Android.

### Commit

`f4082e4` — `feat(offline): add local write queue and sync screen`


## Audit déconnexion et sécurité mobile — 2026-10-25 11:23:00 UTC

### Terminé dans le code

La déconnexion mobile efface désormais les dossiers et opérations hors ligne locales (`offline_batches` et `pending_writes`) après la fermeture de session Supabase. Cela empêche qu’un autre compte utilisant le même appareil récupère la file d’un compte précédent. La validation du rôle, de l’état actif et de l’expiration du profil reste effectuée au chargement depuis le schéma `nfc`.

### Partiel / non vérifié

Flutter et Dart ne sont pas installés dans cet environnement : l’analyse, les tests et le build Android ne peuvent pas encore confirmer la compilation. Les données locales ne sont pas encore cloisonnées par `user_id`; elles sont donc volontairement purgées à chaque déconnexion.

### Reste à faire

Raccorder et démarrer le `SyncWorker` au cycle de vie authentifié, associer si nécessaire les caches à l’utilisateur courant, puis tester la déconnexion, le changement de compte, la révocation d’accès et le retour réseau sur appareil Android.

### Commit

À renseigner après le commit de l’audit.


### Complément cycle de vie — 2026-10-25 11:24:39 UTC

`AuthGate` partage maintenant une instance de `AppDatabase` avec `AuthRepository`, et la ferme à sa destruction. La purge de la file locale est donc appliquée par le même chemin de déconnexion depuis l’accueil, l’écran d’accès révoqué et l’activation du mot de passe.

### Commit

À renseigner après le commit de l’audit.


## Correction de stratégie hors-ligne et session — 2026-10-25 11:28:40 UTC

La purge globale ajoutée précédemment à `signOut` a été retirée. Une déconnexion ne doit pas supprimer `pending_writes` ni `offline_batches`, car ces données peuvent contenir des écritures NFC et des dossiers à synchroniser après le retour réseau. La file locale reste donc persistante au redémarrage et pendant les périodes hors connexion.

Supabase Flutter conserve normalement la session localement et renouvelle automatiquement le jeton lorsqu’une connexion revient ; aucune déconnexion automatique sur simple perte réseau n’est ajoutée. La durée réelle d’un mois dépend toutefois de la configuration Supabase et d’un refresh token encore valide. L’accès totalement hors ligne nécessite encore un profil local/caches sécurisés : aujourd’hui `AuthGate` recharge le profil `nfc` au démarrage et ce parcours doit être adapté avant de déclarer le mode hors ligne complet.

### Reste à faire

Démarrer `SyncWorker` au cycle de vie authentifié, conserver les données en attente jusqu’à confirmation serveur, associer les caches à l’utilisateur courant pour éviter les mélanges de comptes, puis tester un mois de session avec pertes réseau répétées sur Android.

### Commit

À renseigner après le commit de cette correction.


## Cache profil et autorisations hors connexion — 2026-10-25 11:32:30 UTC

### Terminé dans le code

Le profil métier et l’autorisation associée sont maintenant mis en cache dans SQLite, indexés par `user_id`, après une lecture Supabase réussie. En cas d’erreur réseau au démarrage, `AuthRepository` relit uniquement le cache du même utilisateur Supabase actuellement authentifié. Le cache expire après 31 jours ; un profil expiré n’est pas utilisé. La session Supabase persistée reste la condition d’accès au cache, et la perte réseau ne déclenche pas de déconnexion.

La table `cached_profiles` est créée pour les nouvelles bases et ajoutée par migration SQLite pour les bases existantes. La file `pending_writes` et les dossiers hors ligne ne sont pas supprimés lors de la déconnexion.

### Partiel / non vérifié

Flutter/Dart n’est pas installé ici : aucune analyse, compilation ou exécution Android n’a pu être faite. Une révocation serveur survenue pendant une période hors ligne ne peut être connue qu’au prochain retour réseau ; la durée maximale de 31 jours limite ce risque mais ne remplace pas une validation en ligne.

### Reste à faire

Démarrer `SyncWorker` au cycle de vie authentifié, tester les pertes réseau prolongées, vérifier le renouvellement de session Supabase sur appareil Android et associer aussi les dossiers/tags hors ligne au `user_id` lorsque leur cache sera implémenté.

### Commit

À renseigner après le commit de cette modification.


### Invalidation après vérification en ligne — 2026-10-25 11:33:05 UTC

Lorsqu’une lecture Supabase réussie confirme qu’aucun profil n’existe pour l’utilisateur courant, le cache correspondant est maintenant supprimé. Une révocation connue en ligne ne pourra donc pas être réutilisée hors connexion ; le fallback cache ne s’applique qu’en cas d’échec de lecture réseau.

### Commit

À renseigner après le commit de cette modification.
