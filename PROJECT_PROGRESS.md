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


## Import dynamique, formats Code et droits de création — 2026-10-26 00:50 UTC

### Terminé dans le code mobile

- Le formulaire de dossier accepte un Admin pour tout client ou un client seulement pour son propre `client_id` si `can_create_batches` est accordé. L’accueil/routeur appliquent le même droit; l’écran Admin Clients contient l’interrupteur, désactivé par défaut, et met à jour `nfc.nfc_clients` sous RLS.
- Le type de données vient de `default_data_type`; les réglages `code_charset`, `code_min`, `code_max` et le paramètre `p_settings` ne sont envoyés que pour un format dont le type par défaut est `code`.
- Le flux import mobile couvre les fichiers `.xlsx`, `.xls` et `.csv`, la sélection de feuille, la lecture locale en texte, le mapping automatique/modifiable, le blocage des associations `required`/`required_any` manquantes, l’aperçu, la saisie manuelle, l’appel de `nfc_import_rows` en lots de 500, le bilan avec numéro de ligne Excel/message serveur, le CSV des rejets et le modèle XLSX à deux feuilles (Instructions, exemples, champs/règles et colonnes texte pour code/téléphone).
- Les champs, alias, types, labels, puce, capacité et règles sont lus depuis `nfc.nfc_card_formats.field_schema/rules`; aucune liste de champs métier n’est codée en dur. Les règles de contenu et le nettoyage restent à Supabase. Les dépendances Excel/fichier/partage et les contraintes Flutter/Dart minimales sont documentées dans `pubspec.yaml` et le README.
- README, architecture mobile et guide Supabase corrigés : la création client autorisé remplace l’ancienne restriction Admin-only; l’écriture NFC reste hors périmètre de cette étape.

### Partiel / non vérifié

Flutter et Dart ne sont pas installés dans cet environnement. Aucun `flutter pub get`, formatage/analyse, compilation, test sur appareil ou appel de connexion Supabase n’a été exécuté. Les scripts SQL 003 et 004 ne sont pas confirmés appliqués par le propriétaire; les nouveaux formats/règles ne pourront pas être validés avant leur application séparée et dans l’ordre demandé.

### Reste à faire

- Le propriétaire exécute 003 seul, puis 004 dans une seconde exécution, sans rejouer 001.
- Installer l’environnement Flutter minimum déclaré (Flutter 3.29.2 / Dart 3.7.2), résoudre d’éventuelles incompatibilités révélées par `pub get`/analyse/compilation, puis tester le flux sur Android et Supabase après autorisation.
- L’écriture et la relecture physique NFC, le cache/import hors ligne complet et la synchronisation reliée à l’écriture restent hors périmètre.
- L’audit lecture seule du dépôt Web a relevé qu’il contient encore `manual_patches/002_admin_only_batch_creation_nfc.sql` et ne contient pas les scripts 003/004 attendus. Le dépôt Web n’a pas été modifié dans ce lot mobile; sa mise en conformité reste à traiter dans la phase Web autorisée.

### Correction des anciennes notes

Cette entrée remplace toute ancienne consigne de suivi demandant d’appliquer le patch 002 « Admin seulement » ou indiquant que `can_create_batches` ne donne aucun droit. Ne pas appliquer 002 : la règle attendue est Admin pour tout client, ou client autorisé pour son propre compte. L’invitation client reste réservée à l’Admin; l’auto-inscription demeure interdite.

### Commit

`c72b741` — `feat(mobile): implement dynamic format imports`, poussé sur `master`.

## Lot 1 — socle réel d’encodage NFC Android — 2026-10-26 01:24 UTC

### Terminé dans le code

- Ajout des dépendances compatibles Dart 3.7.2 : `nfc_manager 4.0.2` et `nfc_manager_ndef 1.0.1`.
- Remplacement des placeholders NFC par une session réelle : disponibilité, détection, UID Android, lecture NDEF, écriture NDEF, relecture de contrôle et verrouillage définitif optionnel.
- Construction NDEF depuis le payload backend : URI, texte et MIME `text/vcard`.
- Ajout du modèle `NfcTagRecord` avec payload, type, statut, UID, verrouillage et champs.
- Ajout de la lecture ordonnée des tags `pending`/`error` depuis `nfc.nfc_tags`.
- Ajout du repository mobile pour lister les cartes inscriptibles et remonter le résultat à `nfc_mark_written`.

### Partiel / non vérifié

`git diff --check` est passé. Flutter/Dart ne sont pas installés dans ce sandbox : aucun `flutter pub get`, `flutter analyze`, build Android ou test avec une puce réelle n’a été exécuté. La permission et le manifeste Android seront traités dans le lot de câblage Android.

### Reste à faire

Brancher ce socle sur les écrans d’écriture en série et de vérification, puis synchroniser les résultats hors ligne.

### Commit

`46c32c6` — `feat(mobile): add real nfc encoding foundation`


## Lot 2 — écriture et vérification NFC raccordées — 2026-10-26 01:31:35 UTC

### Terminé dans le code mobile

- La destination Écriture NFC ouvre maintenant un écran réel avec sélection du dossier, liste des cartes inscriptibles, payload backend, progression, état de la carte courante, bouton d’approche, nouvelle tentative et passage.
- `WriteController` appelle `NfcService.writeOnce`, utilise toujours `nfc.nfc_tags.payload` comme source de vérité, enregistre `verified` ou `error` via `nfc_mark_written`, et place le résultat dans la file locale si l’appel réseau échoue.
- La destination Vérification NFC ouvre maintenant un écran réel : lecture du tag, récupération de l’UID Android, recherche de la carte dans `nfc.nfc_tags`, comparaison avec le payload NDEF attendu et affichage des cas conforme, tag inconnu, contenu différent, tag vide ou erreur.
- `TagsRemote` et `TagRepository` exposent la recherche d’une carte par UID.
- La navigation mobile ne laisse plus les destinations Écriture et Vérification sur l’écran générique de présentation.

### Partiel / non vérifié

- Flutter et Dart ne sont pas installés dans ce sandbox : aucun `flutter pub get`, `flutter analyze`, test Flutter, compilation APK ou test sur puce réelle n’a pu être exécuté.
- Le dépôt ne contient toujours pas la plateforme Android générée : `android/` ne contient que sa documentation. La permission NFC et le manifeste devront être ajoutés dans le prochain lot de génération/configuration Android.
- La comparaison NDEF et les permissions Android restent à confirmer sur appareil réel avec des tags NTAG compatibles.

### Reste à faire

- Générer/configurer la plateforme Android et déclarer `android.permission.NFC` ainsi que `android.hardware.nfc`.
- Exécuter l’analyse, les tests et le build Android dans Flutter 3.29.2 / Dart 3.7.2 ou via GitHub Actions.
- Tester l’écriture, la relecture, le verrouillage, les erreurs, la file hors ligne et la synchronisation sur appareil NFC réel.
- Vérifier dans Supabase les grants/RLS de la recherche par UID et de `nfc_mark_written`.

### Commits

- `81734f2` — `feat(mobile): wire nfc writing and verification screens`
- Progression documentaire : commit suivant.

## Lot M1 — base locale v3, réglages, détail de dossier, export, synchro — 2026-10-26 UTC

### Terminé dans le code

- Dépendances ajoutées : `shared_preferences`, `wakelock_plus`, `path_provider`.
- Base locale en version 3 (migration depuis v1/v2) : table `offline_tags` (cartes téléchargées, par utilisateur), `user_id` sur `offline_batches` et `pending_writes`, colonnes `permanent` et `sync_error` pour les refus définitifs. `OfflineTagsDao` (enregistrer/lister/rechercher par UID/mettre à jour/supprimer un dossier) et `PendingWritesDao` cloisonné par utilisateur.
- `SyncRepository` : envoi séquentiel pour le seul utilisateur propriétaire de la file ; réseau coupé ou session expirée = on garde et on s'arrête ; refus de la base (UID déjà utilisé, carte annulée, accès refusé) = marqué définitif, conservé, la file continue ; relancer ou abandonner depuis l'écran Synchronisation.
- Écran Synchronisation refait : opérations en attente et refusées (avec message), relancer/abandonner, dossiers téléchargés.
- Réglages (`AppSettingsStore`, écran Réglages) : son, vibration, avancement automatique, écran allumé, verrouillage par défaut (désactivé). `FeedbackService` (vibration, son, écran allumé).
- Détail d'un dossier complet : compteurs colorés, progression, liste paginée (50) des cartes avec statut coloré, filtres de statut, recherche (identifiant, UID, code, référence, nom), états chargement/vide/erreur, accès Importer, Écrire (dossier présélectionné), Vérifier, Exporter.
- Export CSV (`;`, UTF-8 avec BOM, protection formules) depuis le détail et depuis l'écran Exporter ; partage Android.
- Couleurs d'état communes (orange #C2410C, bleu #0299E2, vert #15803D, rouge #B91C1C). Les destinations Réglages et Exporter ne sont plus des écrans « en cours de raccordement » ; `module_screen.dart` et les fichiers vides `tag_reader`, `tag_writer`, `haptics_service`, `sound_service` sont supprimés.

### Non vérifié

Flutter/Dart absents de cet environnement et consigne de ne pas compiler avant que tout le code soit écrit : aucune analyse, aucun test. Des erreurs de compilation sont possibles et seront traitées à l'étape compilation.

### Reste à faire (mobile)

M2 : écriture en série complète (boucle, pause, verrouillage confirmé, lecture du cache local, enregistrement local d'abord), correction de la comparaison NDEF (bug : `NdefMessage` comparé par identité), vérification d'un tag améliorée. M3 : téléchargement hors-ligne d'un dossier, `SyncWorker` démarré après connexion et arrêté à la déconnexion, accès révoqué, nettoyage final. Plus tard : dossier `android/`, permission NFC, compilation, tests.

## Lot M2 — écriture NFC en série et vérification — 2026-10-26 UTC

### Terminé dans le code

- **Bug corrigé** : la relecture comparait deux `NdefMessage` avec `!=` (identité), donc jamais égaux. `NfcService.sameMessage` compare maintenant enregistrement par enregistrement (format, type, contenu). Utilisé par l'écriture et par la vérification.
- `NfcService.writeOnce` : NFC indisponible détecté, délai de 60 s, annulation (`cancel`), contrôle capacité/inscriptible, écriture, relecture comparée, verrouillage seulement après relecture réussie (échec de verrouillage signalé sans perdre la carte vérifiée), garde-fou avant écriture : UID déjà associé à une autre carte refusé.
- `WriteController` (ChangeNotifier) : lit le **cache local** (télécharge le dossier au besoin via `OfflineRepository`), boucle en série, avancement automatique ou bouton « Carte suivante », Pause/Reprendre, Passer, Réessayer, Terminer, refus du même UID deux fois d'affilée, **enregistrement local d'abord** (cache + file `pending_writes`) puis envoi immédiat si le réseau le permet, signal sonore/vibration, écran maintenu allumé.
- `WriteScreen` refait : préparation (dossier, avancement automatique, verrouillage avec confirmation explicite, mise à jour du cache depuis le serveur), écran de série plein écran (compteur n / total, panneau orange / vert / rouge, payload, boutons larges), confirmation avant de quitter, résumé final. Présélection du dossier depuis le détail.
- `VerifyTagScreen` : comparaison NDEF corrigée, recherche hors-ligne dans les dossiers téléchargés si le réseau est absent, couleurs d'état, signal sonore.
- `OfflineRepository.downloadBatch` : télécharge les cartes et ré-applique les résultats encore en file pour ne rien perdre.

### Non vérifié

Aucune compilation ni test. L'écriture NFC réelle (ISO 14443 / NTAG), le verrouillage et le comportement de `nfc_manager 4.0.2` restent à valider sur un téléphone Android avec de vrais tags.

### Reste à faire (mobile)

M3 : bouton de téléchargement hors-ligne dans le détail du dossier, `SyncWorker` démarré après connexion et arrêté à la déconnexion (retour réseau, retour au premier plan), accès révoqué en cours de session, nettoyage final et documentation. Plus tard : dossier `android/`, permission NFC, compilation, tests.

## Lot M3 — hors-ligne branché, accès révoqué, documentation — 2026-10-26 UTC

### Terminé dans le code

- Détail d'un dossier : bouton « Télécharger pour le hors-ligne » / « Mettre à jour hors-ligne » (`OfflineRepository.downloadBatch`), indicateur de disponibilité.
- `SyncWorker` réécrit (observateur de cycle de vie) et **démarré par `AuthGate`** uniquement pour un profil valide, arrêté à la déconnexion ou si l'accès est retiré ; déclencheurs : démarrage, retour du réseau, retour au premier plan.
- **Accès révoqué en cours de session** : contrôle du profil toutes les 2 minutes et au retour au premier plan ; si l'accès est retiré ou expiré, tous les écrans ouverts sont fermés et l'écran dédié s'affiche ; la file locale est conservée (jamais purgée).
- Cloisonnement par utilisateur de bout en bout (cache, file, envoi).
- `MOBILE_ARCHITECTURE.md` mis à jour (périmètre réel, boucle d'écriture, hors-ligne, sécurité).

### Écrans et fonctions mobiles désormais codés

Connexion, activation, accueil par rôle, clients/invitation, création de dossier, liste et détail des dossiers, import et saisie manuelle, écriture NFC en série, vérification d'un tag, export CSV, réglages, synchronisation, accès révoqué, hors-ligne.

### Non vérifié

Aucune compilation, aucune analyse, aucun test, aucun essai sur tags réels (consigne : code d'abord). Des erreurs de compilation Dart sont possibles.

### Reste à faire après l'écriture du code

1. Générer le dossier `android/`, déclarer `android.permission.NFC` et `android.hardware.nfc`, vérifier le `minSdk` exigé par les bibliothèques.
2. Compiler : `flutter pub get`, `flutter analyze`, corriger les erreurs, build APK.
3. Essais sur appareil avec 5 à 10 vrais tags (écriture, relecture, verrouillage, erreurs, hors-ligne, synchro, révocation).
4. Vérifier dans Supabase : grants/RLS de `nfc_tags` (lecture par UID), `nfc_mark_written`, scripts 003 puis 004 appliqués.
5. Les fichiers de `test/` sont des emplacements vides à écrire à l'étape tests.

## Relecture statique du mobile — 2026-10-26 UTC

### Corrigé

- Reprise après pause : une carte déjà vérifiée n'est plus réécrite, la série passe à la suivante.
- Détail d'un dossier : un changement rapide de filtre ou de recherche pendant un chargement pouvait laisser la liste vide ; chaque chargement est maintenant numéroté et les réponses périmées sont ignorées.
- Éléments de file créés avant la migration v3 (sans propriétaire) : rattachés à l'utilisateur connecté au premier envoi au lieu d'être ignorés.

### Limites connues

Les noms exacts de l'API `nfc_manager` 4.0.2 / `nfc_manager_ndef` 1.0.1 (`Ndef.from`, `write(message:)`, `writeLock`, `isWritable`, `maxSize`, `NdefRecord(...)`) reprennent le code existant et n'ont pas pu être vérifiés (documentation inaccessible depuis cet environnement) : à confirmer à la compilation. Aucune compilation ni test.


## Lot M4 — 2026-10-26 21:07 UTC (mobile uniquement)

### Terminé et branché
- Écriture d'**une seule carte** : `SingleWriteScreen` (garde-fous, relecture comparée, verrouillage confirmé, résultat local puis envoi), accessible depuis le détail d'une carte et depuis « Encoder une seule carte » (`CardPickerScreen`) dans l'écriture.
- Détail d'une carte : `TagDetailScreen` (en ligne, repli sur le cache).
- Dossiers hors connexion : liste (`batch_source.dart`), détail (cartes, compteurs, export lus dans le cache), choix du dossier dans l'écriture.
- Aide NFC désactivé : `NfcHelpBanner` dans l'écriture, l'écriture d'une carte et la vérification.
- Réglages : compte (mot de passe, déconnexion, version).
- Modifier un client : `ClientEditScreen` + `ClientsRemote.updateClient`.
- Tableau de bord admin : `AdminDashboardScreen`, nouvelle destination `dashboard` réservée à l'admin.

### Non vérifié
Rien compilé ni testé. Les nouvelles dépendances `package_info_plus` et `app_settings` n'ont pas été résolues. Voir `RESTE_A_FAIRE_MOBILE.md` pour le reste.

## Lot M5 — décisions métier confirmées et annulation NFC — 2026-10-26 23:16 UTC

### Décisions confirmées

- L’e-mail affiché et modifiable dans la fiche client est un e-mail de contact métier enregistré dans `nfc.nfc_clients.email`.
- La modification d’un client ne modifie jamais l’e-mail de connexion du compte Supabase Auth.
- Un client autorisé peut créer un dossier uniquement pour son propre `client_id`. Le mobile applique ce droit dans l’interface et la RPC `nfc_create_batch` le contrôle côté serveur avec `nfc_my_client()` et `can_create_batches`.
- Les workflows GitHub Actions restent présents comme documentation mais ne seront pas utilisés pour la validation. La compilation et les vérifications seront exécutées ultérieurement depuis le terminal ou un autre environnement Flutter.
- Le dossier Android complet reste volontairement en attente jusqu’à la fin du développement fonctionnel. Aucune permission NFC ni génération Android n’est ajoutée dans ce lot.
- Le cache du profil hors ligne pendant la durée prévue par la politique produit est conservé. Les données NFC de l’application sont des liens de profil IziCard ; aucune donnée IziCare sensible n’est stockée par ce projet.
- Le stockage sécurisé explicite de session Supabase n’est pas ajouté à ce stade. Un PIN local optionnel pourra être évalué séparément sans bloquer les utilisateurs qui ne l’activent pas.

### Terminé dans le code mobile

- La fiche de modification client documente et sépare explicitement l’e-mail de contact de l’e-mail Auth.
- La lecture NFC est maintenant annulable depuis l’écran Vérifier un tag.
- Une lecture NFC possède un délai maximal de 60 secondes, ferme la session dans tous les cas et signale une annulation sans créer de résultat métier.

### Partiel / non vérifié

- La compatibilité exacte des API `nfc_manager` et `nfc_manager_ndef` reste à confirmer lors de la compilation Flutter, volontairement différée.
- La synchronisation fonctionne au premier plan et au retour réseau ; la synchronisation lorsque l’application est totalement fermée reste à traiter après génération du projet Android.
- L’archivage, l’historique métier et le temps réel nécessitent encore la définition/qualification des opérations backend partagées avant raccordement mobile.

### Reste à faire

- Ajouter une confirmation professionnelle avant l’écrasement d’un tag qui contient déjà des données, sans modifier la source de vérité backend.
- Raccorder l’archivage et la consultation d’historique aux RPC/tables partagés après qualification backend.
- Évaluer puis implémenter une synchronisation Android en arrière-plan seulement après disponibilité du projet Android.

### Commit

`270dbca` — poussé sur `master`.

## Lot M6 — confirmation avant écrasement d’un tag — 2026-10-26 23:17 UTC

Le service NFC lit désormais le contenu NDEF existant avant toute écriture. Si le tag contient déjà au moins un enregistrement, l’opérateur doit confirmer explicitement le remplacement. La confirmation est disponible pour l’écriture en série et pour l’écriture d’une carte unique. Une annulation retourne un résultat non enregistrable et n’est pas comptée comme une erreur métier ni synchronisée vers le backend.

Le contrôle intervient avant `ndef.write`, tandis que la relecture de vérification et le verrouillage définitif restent obligatoires après écriture. La compilation Flutter et la validation sur vrais tags restent différées conformément aux décisions précédentes.

### Commit

`e4df99e` — poussé sur `master`.

## Lot M7 — synchronisation temps réel des dossiers — 2026-10-26 23:18 UTC

L’écran mobile des dossiers écoute maintenant les événements Supabase Realtime sur `nfc.nfc_batches` et `nfc.nfc_tags`. Les changements de dossier, de statut ou de carte déclenchent un rafraîchissement temporisé des compteurs et de la progression, avec nettoyage de l’abonnement lors de la fermeture de l’écran. Le rafraîchissement manuel reste disponible comme solution de secours.

Le dépôt Web/backend partagé contient la migration `005_nfc_realtime.sql`, qui ajoute `nfc.nfc_batches` et `nfc.nfc_tags` à la publication `supabase_realtime` et configure leur replica identity. Cette migration doit être appliquée dans Supabase avant d’attendre des événements en production.

### Partiel / non vérifié

La compilation Flutter et la réception réelle d’événements nécessitent l’application de la migration puis un environnement connecté. Le temps réel n’est pas un remplacement de la file locale de synchronisation : les résultats NFC non synchronisés restent protégés par le stockage local et la synchronisation existante.

### Commit

`af2eb0a` — poussé sur `master`.

## Lot M8 — archivage réversible et historique — 2026-10-26 23:19 UTC

Le détail d’un dossier admin propose maintenant une confirmation avant archivage ou réactivation. L’opération passe par la RPC backend partagée `nfc_archive_batch`, conserve les cartes et interdit les imports/écritures tant que le dossier est archivé. La réactivation recalcule un état cohérent à partir des cartes présentes.

Le détail propose également une consultation de l’historique d’audit du dossier via `nfc_list_audit`. Les événements sont lus côté serveur, réservés aux administrateurs, et affichés dans une boîte de dialogue dédiée. La migration backend `006_nfc_archive_history.sql` a été poussée dans le dépôt Web partagé.

### Partiel / non vérifié

Les migrations 005 et 006 doivent être appliquées dans Supabase. La compilation Flutter, les droits RLS/grants et la validation avec un dossier réel restent à effectuer.

### Commit

`7a423bd` — poussé sur `master`.

## Lot M9 — interface tablette, français obligatoire et thème clair — 2026-10-26 23:30 UTC

L’interface mobile utilise maintenant un conteneur responsive commun qui centre les contenus et limite leur largeur sur tablette et paysage. L’accueil présente les destinations en grille à deux colonnes sur les écrans larges. Les dossiers passent également en grille à deux colonnes, tandis que le tableau de bord, le détail de dossier et les réglages bénéficient d’une largeur de lecture adaptée aux grands écrans.

Le français est désormais explicitement sélectionné dans `MaterialApp` et le thème clair est forcé avec `ThemeMode.light`. Le mode sombre n’est pas proposé. La ressource anglaise `lib/l10n/app_en.arb` a été supprimée ; l’application reste exclusivement en français.

### Partiel / non vérifié

La compilation Flutter et le rendu sur une vraie tablette Android restent à vérifier lorsque l’environnement Android sera disponible. Les écrans ayant déjà une largeur maximale dédiée restent compatibles avec le nouveau conteneur.

### Commit

`3ddbd2c` — poussé sur `master`.


## Lot M10 — comparaison Web/mobile et cahier Android — 2026-10-27 00:17 UTC

### Terminé

- Lecture comparative des dépôts `izicard-managers-web` et `Izicard-Managers`; résumé des domaines fonctionnels communs, différences plateforme, éléments présents et validations manquantes.
- Document de référence ajouté : `MOBILE_ANDROID_RELEASE_BRIEF.md`. Il fixe le nom proposé « IziCard Manager », les frontières du schéma `nfc`, les risques autour de la base Supabase partagée, les contrôles à réaliser pour Android, le thème sombre, les icônes/splash, les liens profonds, l’authentification/email, les tests et le build/signature; il contient le prompt d’exécution complet pour l’agent IA.
- Inspection Supabase en lecture : projet cible `IziCard` (`thsedbhzhonemdhbndpf`), objets du schéma `nfc` présents; l’Edge Function existante `send-activation-emails` est explicitement hors périmètre et ne doit pas être modifiée. `create-client-user` est référencée par les clients et son code local est présent dans le dépôt Web, mais la liste distante ne la montre pas déployée.
- Migration NFC 003 (`nfc_data_type` ajoute `code`) appliquée séparément au projet cible via le connecteur. Les scripts 004–006 et leur état restent à confirmer avant exécution; aucune fonction d’activation/vente n’a été touchée.

### Partiel / non vérifié

La comparaison est statique. Les builds, Auth, emails et fonctionnalités NFC en production n’ont pas été testés. Le nom de package Android reste à confirmer avant publication. SMTP Resend, URLs de redirection et secrets de la fonction d’invitation ne sont pas encore configurés ou vérifiés.

### Reste à faire

Ajouter une bascule de thème système/clair/sombre avec prise en charge lisible sur toutes les pages, générer et valider la plateforme Android avec icône et splash, vérifier les migrations NFC restantes et les réglages Auth pertinents, puis lancer les analyses/builds/tests disponibles. Après chaque lot, consigner le résultat et pousser le commit.

### Commit

À renseigner après commit/push du lot documentaire.


## Lot M11 — thème clair/sombre et première validation Flutter — 2026-10-27 00:32 UTC

### Terminé dans le code mobile

- Préférence persistée `système / clair / sombre` dans `AppSettingsStore`, reliée au `MaterialApp`; choix exposé dans Réglages.
- Thèmes Material 3 clair et sombre distincts, avec ColorScheme/tokens pour fonds, cartes, dialogues, champs, boutons, navigation, menus, textes et états. Les écrans principaux (connexion, accueil, dossiers, détail carte/dossier, NFC, réglages, tableau de bord, erreurs) ont été adaptés là où les couleurs fixes empêchaient la lisibilité.
- Nom affiché « IziCard Manager » défini côté Flutter.
- Contrainte invalide `file_picker: ^10.3.11` remplacée par `^10.3.7`; la résolution Pub a abouti avec `file_picker 10.3.10`.
- Blocages de compilation préexistants corrigés sans changer les règles métier : parenthésage du formulaire de création de dossier et import explicite de `NdefMessage` depuis `nfc_manager/ndef_record.dart`.
- Les anciens fichiers de tests vides (`test/*_test.dart`) ont reçu des tests unitaires ciblés ; nouveaux tests pour les thèmes et la persistance des réglages.

### Vérification réalisée

- `flutter pub get` : réussi.
- `flutter test` : réussi, tous les tests passent.
- `flutter analyze` : aucune erreur Dart ; avertissements/info préexistants encore présents (dépréciations `withOpacity`, imports/fields inutilisés, usage déprécié `anonKey`), la commande retourne un statut non nul en raison de ces diagnostics.
- Aucun APK n’est encore construit dans ce lot; la plateforme Android complète, les permissions, icône, splash, liens profonds et validations appareil réel restent le lot suivant.
- Aucun changement appliqué dans Supabase pendant ce lot.

### Reste à faire

Générer puis configurer la plateforme Android (identifiant, SDK, permission NFC facultative pour permettre l’administration sur téléphones sans lecteur, liens profonds, icône et splash), construire APK debug/release quand la signature de production sera disponible, puis réaliser les vérifications Supabase strictement limitées au schéma NFC et aux réglages Auth de récupération/invitation requis.

### Commit

`c3b1d4f` — `feat(mobile): add adaptive light and dark themes`, poussé sur `master`.


## Correction du prompt Android — 2026-10-27 00:45 UTC

`MOBILE_ANDROID_RELEASE_BRIEF.md` a été remplacé par un prompt limité à la génération du dossier Android, à la configuration, aux icônes/splash, aux permissions, aux liens d’application, aux vérifications, au build et à la remise de l’APK. La comparaison de dépôts et les sujets hors de ce périmètre ont été retirés. Le document a été vérifié : aucune mention du service externe n’y reste.

`a3defb3` — `docs: narrow Android delivery prompt`, poussé sur `master`.


## Lot Supabase partagé M12 — backend NFC et invitation — 2026-10-27 00:56 UTC
### Terminé
- Projet cible confirmé : Supabase `IziCard` (`thsedbhzhonemdhbndpf`), schéma métier `nfc` uniquement.
- Les migrations partagées `004_nfc_formats_rules`, `005_nfc_realtime` et `006_nfc_archive_history` sont appliquées et vérifiées.
- Les RPC d’import, de création avec réglages, d’archivage et d’audit sont présentes ; `nfc_batches` et `nfc_tags` sont publiées dans Realtime.
- Edge Function `create-client-user` déployée avec JWT obligatoire ; l’Edge Function historique `send-activation-emails` est restée inchangée.
### Partiel / non vérifié
- Aucun parcours réel d’invitation, récupération, Realtime, RLS ou NFC physique n’a été exécuté.
- SMTP Resend, OTP à 8 chiffres, templates email, URLs Web/deep link et secret `INVITE_REDIRECT_TO` restent à configurer/vérifier dans Supabase.
- Flutter/Android, build, liens profonds et tests sur appareil restent hors de ce lot.
### Reste à faire
- Configurer les éléments Auth/SMTP manuels, puis tester invitation et récupération avec un compte réel.
- Compiler l’application Android et tester les RPC/RLS, import, archivage/audit, Realtime, écriture et synchronisation sur appareil.
### Commit
Commit : 105271e — docs: record Supabase NFC deployment
