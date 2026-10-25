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

- Supabase n’est pas encore initialisé dans le code Flutter.
- Connexion utilisateur non implémentée.
- Déconnexion non implémentée.
- Réinitialisation de mot de passe non implémentée.
- Écrans UI/UX finaux non implémentés.
- Configuration Brevo non effectuée côté Supabase.
- Aucun secret serveur ou clé `service_role` ne doit être ajouté au dépôt.

### Prochaine étape validée

Mettre en place le socle Supabase côté mobile :

1. configuration par variables de build ;
2. initialisation du client Supabase ;
3. connexion email/mot de passe ;
4. déconnexion et nettoyage local ;
5. demande de réinitialisation de mot de passe ;
6. écrans de connexion, oubli du mot de passe et accès révoqué ;
7. tests et mise à jour de ce fichier.

## Plan Supabase et Brevo

- L’application utilisera uniquement l’URL Supabase et la clé publishable/anon côté client.
- La clé `service_role` restera exclusivement côté serveur et ne sera jamais embarquée dans Flutter.
- Les règles RLS et les fonctions SQL resteront l’autorité pour les droits d’accès.
- Supabase Auth gérera les sessions, la connexion, la déconnexion et les tokens.
- La réinitialisation appellera `resetPasswordForEmail` avec une URL de redirection mobile contrôlée.
- Brevo sera utilisé uniquement comme fournisseur d’envoi SMTP de Supabase Auth pour les emails nécessaires : confirmation de compte, réinitialisation de mot de passe et éventuellement changement d’email.
- Aucune clé API Brevo ne sera stockée dans l’application mobile.
- Les clés publishable fournies seront injectées via configuration de build ou fichier local ignoré par Git, jamais via une clé serveur.

## Documentation et suivi — 2026-10-25 08:47:09 UTC

### Terminé

Le fichier de suivi racine a été créé. Le README documente désormais la règle de traçabilité, la séparation des responsabilités web/mobile, la configuration Supabase côté client et l’usage minimal de Brevo. Le fichier `.env.example` contient uniquement des placeholders pour l’URL et la clé publishable Supabase.

### Partiel / non terminé

L’authentification Flutter et les écrans associés ne sont pas encore codés. La configuration SMTP Brevo doit être effectuée dans le projet Supabase, sans ajouter de clé Brevo au dépôt.

### Reste à faire

Implémenter puis tester le socle Auth Supabase : connexion, déconnexion, réinitialisation du mot de passe, gestion de session et écrans UI/UX correspondants.

### Commit

Commit : 292eb4e
