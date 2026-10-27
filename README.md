# IziCard NFC Encoder — application Android Flutter

Application Android d’encodage NFC en série et interface de l’écosystème IziCard. L’application mobile et l’espace admin Web doivent proposer les mêmes fonctions métier et utiliser un backend/API unique : même projet Supabase, mêmes données, mêmes fonctions serveur/RPC et mêmes règles d’accès. Le mobile n’a pas son propre backend ni ses propres règles métier.

L’Admin peut gérer les clients et accès, créer un dossier pour n’importe quel client et utiliser les opérations métier disponibles. Un client invité peut aussi créer un dossier uniquement pour son propre compte si `nfc.nfc_clients.can_create_batches = true`; l’Admin attribue ce droit, désactivé par défaut. L’Admin seul invite/ajoute les clients; l’auto-inscription reste interdite. Web et mobile appellent les mêmes opérations Supabase/RPC et règles RLS; l’interface ne remplace jamais les contrôles serveur.

## Schéma Supabase obligatoire

Tous les objets métier IziCard NFC (tables, vues, types et fonctions/RPC) sont lus et utilisés dans le schéma PostgreSQL `nfc`, jamais via `public` en repli. La migration du schéma est confirmée comme déployée. Ne pas rejouer le bootstrap historique `001_nfc.sql`; vérifier ultérieurement les droits/RLS sur une instance réelle.

Le mobile doit charger le profil et le rôle depuis `nfc.nfc_profiles`, puis présenter un accueil et une navigation adaptés au rôle et à l’état d’accès. La sécurité est appliquée côté backend par RLS/fonctions, pas seulement par masquage des écrans. L’interface doit suivre la charte IziCard et offrir une UX professionnelle, intuitive et accessible : boutons retour cohérents, états de chargement/erreur/vide et confirmations lorsque nécessaire. Les tests de connexion sont différés pour le moment.

## Règle obligatoire de suivi

Toute modification, correction ou fonctionnalité doit être reportée dans [`PROJECT_PROGRESS.md`](PROJECT_PROGRESS.md) avec la date et l’heure UTC, le périmètre modifié, ce qui est terminé, ce qui reste partiel ou non terminé, les prochaines étapes et le commit Git correspondant. Cette mise à jour doit accompagner chaque changement avant de le considérer comme terminé.

## Supabase et authentification

Le mobile utilise Supabase Auth pour la connexion par adresse email et mot de passe, la déconnexion et la réinitialisation. Le mot de passe oublié reçoit un code email de 8 chiffres avant la définition du nouveau mot de passe. Les comptes client sont invités uniquement par l’Admin via la fonction Supabase partagée ; aucun parcours d’auto-inscription n’est exposé. L’URL Supabase et la clé anon peuvent être utilisées côté client ; aucune clé `service_role` ne doit être embarquée dans l’application. Les permissions fonctionnelles seront imposées par les politiques RLS et les fonctions SQL côté Supabase.

Les emails nécessaires sont celui de récupération avec code OTP et, si activée, la confirmation de compte. Les messages seront envoyés par Supabase Auth via SMTP Resend configuré dans le tableau de bord Supabase. La clé API Resend ne sera jamais stockée dans Flutter.

## Configuration locale

Copier [`.env.example`](.env.example) vers un fichier local ignoré par Git, ou fournir les mêmes valeurs par `--dart-define` lors du build. Le lecteur XLS legacy nécessite Flutter >= 3.29.2 / Dart >= 3.7.2. Ne jamais ajouter de secret serveur au dépôt.

```bash
flutter pub get
flutter run --dart-define=SUPABASE_URL=https://votre-projet.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=votre_cle_anon
```

## Responsabilités prévues

Le code mobile contient maintenant les écrans Admin/client de dossiers, la permission `can_create_batches`, le chargement des formats/champs depuis `nfc`, la saisie manuelle, l’import `.xlsx`/`.xls`/`.csv` avec mapping, aperçu, envoi par lots via `nfc_import_rows`, bilan et export CSV des erreurs, ainsi qu’un modèle Excel à deux feuilles. Cette implémentation n’a pas encore été compilée ni testée; elle dépend de l’application préalable des scripts Supabase 003 puis 004. L’écriture NFC, l’export métier général et la synchronisation hors ligne restent hors périmètre de ce lot. Les écrans suivent la charte IziCard : cyan `#01A3CA`, bleu `#0299E2`, fond blanc et états lisibles.

Voir [`MOBILE_ARCHITECTURE.md`](MOBILE_ARCHITECTURE.md) et [`PROJECT_PROGRESS.md`](PROJECT_PROGRESS.md) pour le détail et l’état réel d’avancement.

## Décisions de validation et périmètre actuel

L’e-mail modifiable dans la fiche d’un client est un e-mail de contact métier ; il ne modifie jamais l’e-mail de connexion du compte Supabase Auth. Lorsqu’un client est autorisé à créer des dossiers, l’application ne lui permet de créer qu’un dossier pour son propre `client_id` et la RPC `nfc_create_batch` applique le même contrôle côté serveur.

Les workflows GitHub Actions présents dans `.github/workflows/` sont conservés comme documentation, mais ne seront pas utilisés pour la validation. L’analyse, la compilation et les vérifications seront exécutées depuis un terminal ou un autre environnement Flutter. Le projet Android complet est volontairement différé jusqu’à la fin du développement fonctionnel.

Le produit mobile encode des liens de profil IziCard ; aucune donnée sensible IziCare n’est traitée dans ce dépôt. Le profil hors connexion reste disponible selon la politique produit. Le chiffrement du cache et le stockage sécurisé spécifique de session ne sont pas ajoutés à ce stade afin de ne pas fragiliser la synchronisation ; ce choix sera réévalué si le périmètre des données change. Un PIN local optionnel à 6 chiffres pourra être ajouté ultérieurement sans bloquer les utilisateurs qui ne l’activent pas.

Avant toute écriture, le mobile lit le contenu NDEF déjà présent. Si le tag contient des enregistrements, une confirmation explicite est demandée en écriture série comme en écriture d’une carte unique. Une annulation ne crée ni erreur métier ni résultat à synchroniser.

La liste des dossiers écoute également les changements Realtime Supabase sur `nfc.nfc_batches` et `nfc.nfc_tags`. Appliquer la migration backend partagée `005_nfc_realtime.sql` avant la mise en production ; les opérations hors ligne et la file de synchronisation locale restent indépendantes de cette écoute.

Un administrateur peut archiver ou réactiver un dossier après confirmation. L’opération utilise la RPC partagée `nfc_archive_batch`; l’historique du dossier est consultable via `nfc_list_audit`. Appliquer `006_nfc_archive_history.sql` avant d’utiliser ces commandes.

L’application est exclusivement en français : aucune interface anglaise n’est autorisée. Le thème est clair, sombre ou suivi du système (Réglages) ; les couleurs sémantiques passent par `IzicardInk` pour rester lisibles dans les deux. Les écrans d’accueil, dossiers, tableau de bord, détail et réglages utilisent une mise en page responsive centrée, avec grilles à deux colonnes sur tablette et paysage lorsque l’espace le permet.
