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
- Configuration Brevo non effectuée côté Supabase.
- Aucun secret serveur ou clé `service_role` ne doit être ajouté au dépôt.

### Prochaine étape validée

Finaliser et valider le socle OTP Supabase côté mobile :

1. configuration par variables de build ;
2. initialisation du client Supabase ;
3. envoi du code OTP par email ;
4. validation d’un code à 8 chiffres ;
5. déconnexion et nettoyage local ;
6. tests et mise à jour de ce fichier.

## Plan Supabase et Brevo

- L’application utilisera uniquement l’URL Supabase et la clé publishable/anon côté client.
- La clé `service_role` restera exclusivement côté serveur et ne sera jamais embarquée dans Flutter.
- Les règles RLS et les fonctions SQL resteront l’autorité pour les droits d’accès.
- Supabase Auth gérera les sessions, la connexion, la déconnexion et les tokens.
- Le parcours retenu est un accès par code OTP ; aucune réinitialisation par mot de passe n’est prévue dans cette phase.
- Brevo sera utilisé uniquement comme fournisseur d’envoi SMTP de Supabase Auth pour le code OTP et, si activée, la confirmation de compte.
- Aucune clé API Brevo ne sera stockée dans l’application mobile.
- Les clés publishable fournies seront injectées via configuration de build ou fichier local ignoré par Git, jamais via une clé serveur.

## Documentation et suivi — 2026-10-25 08:47:09 UTC

### Terminé

Le fichier de suivi racine a été créé. Le README documente désormais la règle de traçabilité, la séparation des responsabilités web/mobile, la configuration Supabase côté client et l’usage minimal de Brevo. Le fichier `.env.example` contient uniquement des placeholders pour l’URL et la clé publishable Supabase.

### Partiel / non terminé

La configuration SMTP Brevo doit être effectuée dans le projet Supabase, sans ajouter de clé Brevo au dépôt. La longueur de 8 chiffres doit être configurée et vérifiée côté Supabase ; l’application refuse tout code qui ne comporte pas exactement 8 chiffres.

### Reste à faire

Tester sur un appareil Android le socle Auth Supabase : envoi OTP, validation, session, déconnexion et gestion des erreurs.

### Commit

Commit : à renseigner après le commit de l’implémentation OTP.

## Authentification OTP — 2026-10-25 08:50:30 UTC

### Terminé

Supabase Flutter natif est initialisé via `SUPABASE_URL` et `SUPABASE_PUBLISHABLE_KEY`. Le flux comprend la saisie d’email, l’envoi d’un OTP, la saisie et validation d’un code de 8 chiffres, la persistance de session via Supabase Auth, la déconnexion et l’écran d’accueil de session. Le logo et la charte IziCard sont utilisés par les écrans de connexion et d’accueil.

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

Configurer Supabase Auth et SMTP Brevo, vérifier la longueur réelle de l’OTP côté serveur, tester le parcours sur Android, puis ajouter la gestion des rôles et des écrans dossiers/NFC.

### Commit

Commit : 001c266
