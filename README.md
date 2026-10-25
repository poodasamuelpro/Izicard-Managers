# IziCard NFC Encoder — application Android Flutter

Application Android d’encodage NFC en série et interface de l’écosystème IziCard. L’application mobile et l’espace admin Web doivent proposer les mêmes fonctions métier et utiliser un backend/API unique : même projet Supabase, mêmes données, mêmes fonctions serveur/RPC et mêmes règles d’accès. Le mobile n’a pas son propre backend ni ses propres règles métier.

En mode administrateur, l’application mobile doit pouvoir faire tout ce que l’espace admin Web permet, notamment gérer les clients et accès, créer et suivre les dossiers, gérer les imports et exports et utiliser les autres opérations métier disponibles. Seul l’Admin peut créer un client et un dossier ; le client reçoit une invitation email, se connecte sur Web ou Android et ne voit que les dossiers associés à son profil. L’auto-inscription client est interdite. Les deux interfaces appellent les mêmes opérations côté serveur ; seule la présentation et l’intégration du NFC peuvent être propres à chaque plateforme. Toute fonction métier doit être partagée plutôt que réimplémentée séparément.

## Schéma Supabase obligatoire

Tous les objets métier IziCard NFC (tables, vues, types et fonctions/RPC) doivent être lus et utilisés dans le schéma PostgreSQL `nfc`, jamais via `public` en repli. Exemple : `nfc.nfc_profiles`, `nfc.nfc_batches` et les RPC du schéma `nfc`. Le code mobile et le Web visent ce même schéma et le backend commun. La migration Supabase vers `nfc` est maintenant confirmée comme déployée (2026-10-25). Le script historique `001_nfc.sql` du dépôt Web emploie encore `public` et doit être réaligné pour les installations futures ; les droits, RLS et RPC restent à confirmer avant les tests fonctionnels.

Le mobile doit charger le profil et le rôle depuis `nfc.nfc_profiles`, puis présenter un accueil et une navigation adaptés au rôle et à l’état d’accès. La sécurité est appliquée côté backend par RLS/fonctions, pas seulement par masquage des écrans. L’interface doit suivre la charte IziCard et offrir une UX professionnelle, intuitive et accessible : boutons retour cohérents, états de chargement/erreur/vide et confirmations lorsque nécessaire. Les tests de connexion sont différés pour le moment.

## Règle obligatoire de suivi

Toute modification, correction ou fonctionnalité doit être reportée dans [`PROJECT_PROGRESS.md`](PROJECT_PROGRESS.md) avec la date et l’heure UTC, le périmètre modifié, ce qui est terminé, ce qui reste partiel ou non terminé, les prochaines étapes et le commit Git correspondant. Cette mise à jour doit accompagner chaque changement avant de le considérer comme terminé.

## Supabase et authentification

Le mobile utilise Supabase Auth pour la connexion par adresse email et mot de passe, la déconnexion et la réinitialisation. Le mot de passe oublié reçoit un code email de 8 chiffres avant la définition du nouveau mot de passe. Les comptes client sont invités uniquement par l’Admin via la fonction Supabase partagée ; aucun parcours d’auto-inscription n’est exposé. L’URL Supabase et la clé anon peuvent être utilisées côté client ; aucune clé `service_role` ne doit être embarquée dans l’application. Les permissions fonctionnelles seront imposées par les politiques RLS et les fonctions SQL côté Supabase.

Les emails nécessaires sont celui de récupération avec code OTP et, si activée, la confirmation de compte. Les messages seront envoyés par Supabase Auth via SMTP Resend configuré dans le tableau de bord Supabase. La clé API Resend ne sera jamais stockée dans Flutter.

## Configuration locale

Copier [`.env.example`](.env.example) vers un fichier local ignoré par Git, ou fournir les mêmes valeurs par `--dart-define` lors du build. Ne jamais ajouter de secret serveur au dépôt.

```bash
flutter pub get
flutter run --dart-define=SUPABASE_URL=https://votre-projet.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=votre_cle_anon
```

## Responsabilités prévues

Le socle mobile couvre d’abord la connexion par mot de passe, la déconnexion, le mot de passe oublié avec OTP de 8 chiffres et la session. Il couvrira ensuite l’accès selon le rôle, le téléchargement de dossiers, l’import et la vérification des données, l’écriture NFC en série, la relecture, la file hors ligne et la synchronisation. Les écrans suivent la charte IziCard : cyan `#01A3CA`, bleu `#0299E2`, fond blanc, états de succès/erreur/attente lisibles et logo fourni dans `assets/images/logo.jpg`.

Voir [`MOBILE_ARCHITECTURE.md`](MOBILE_ARCHITECTURE.md) et [`PROJECT_PROGRESS.md`](PROJECT_PROGRESS.md) pour le détail et l’état réel d’avancement.
