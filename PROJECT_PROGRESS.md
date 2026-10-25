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

Modifications locales, commit à renseigner s’il est créé.
