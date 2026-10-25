# IziCard NFC Encoder — application Android Flutter

Application mobile Android d’encodage NFC en série. Le dépôt web porte l’administration, les clients, les dossiers, l’import et l’API ; le mobile utilise les mêmes données, la même API Supabase et les mêmes règles métier pour charger les dossiers et écrire les tags sur le terrain.

## Règle obligatoire de suivi

Toute modification, correction ou fonctionnalité doit être reportée dans [`PROJECT_PROGRESS.md`](PROJECT_PROGRESS.md) avec la date et l’heure UTC, le périmètre modifié, ce qui est terminé, ce qui reste partiel ou non terminé, les prochaines étapes et le commit Git correspondant. Cette mise à jour doit accompagner chaque changement avant de le considérer comme terminé.

## Supabase et authentification

Le mobile utilise Supabase Auth pour la connexion par adresse email et mot de passe, la déconnexion et la réinitialisation. Le mot de passe oublié reçoit un code email de 8 chiffres avant la définition du nouveau mot de passe. L’URL Supabase et la clé anon peuvent être utilisées côté client ; aucune clé `service_role` ne doit être embarquée dans l’application. Les permissions fonctionnelles seront imposées par les politiques RLS et les fonctions SQL côté Supabase.

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
