# IziCard NFC Encoder — App Android (Flutter)

Objectif : fournir une application Android d’encodage NFC en série (100+) et une interface mobile complète de l’écosystème IziCard. L’application et l’espace admin Web ont la même parité fonctionnelle métier et utilisent un backend/API unique : même projet Supabase, mêmes tables `nfc_`, mêmes fonctions serveur/RPC (dont `nfc_create_batch`, `nfc_import_rows`, `nfc_mark_written`, `nfc_set_access`) et mêmes politiques RLS. Il n’existe pas de backend métier mobile distinct.

En mode administrateur, le mobile doit pouvoir réaliser les opérations disponibles dans l’espace admin Web : gestion des clients et accès, création et suivi des dossiers, import/export et autres opérations métier. Toute logique métier partagée réside côté backend et est appelée par les deux interfaces ; elle ne doit pas être dupliquée dans Flutter. Les différences sont limitées à l’interface et aux intégrations natives, notamment le NFC Android.

## Schéma Supabase et sécurité
Toutes les données et opérations métier NFC doivent utiliser le schéma `nfc` du projet Supabase commun (`nfc.nfc_profiles`, `nfc.nfc_batches`, fonctions RPC qualifiées dans `nfc`, etc.). Ne jamais supposer `public` ni basculer silencieusement vers ce schéma. La migration existante est encore en `public` et doit être adaptée avant les appels de production : tables/types/vues/fonctions, références SQL, RLS, privilèges et exposition PostgREST/RPC. Aucun test de connexion n’est requis à cette étape.

Charger le profil/ rôle depuis `nfc.nfc_profiles` et traiter côté serveur les statuts actif/révoqué et les permissions. L’accueil et les routes reflètent le rôle, mais seul le backend/RLS autorise les données et mutations. Ne jamais embarquer `service_role` ou un secret serveur.

## Exigences d’interface
UI/UX de qualité professionnelle, alignée sur la charte IziCard (cyan `#01A3CA`, bleu `#0299E2`, blanc), claire et intuitive. Prévoir un accueil distinct selon le rôle, une navigation cohérente avec bouton retour sur les écrans secondaires où nécessaire, et des états de chargement, erreur, liste vide et accès révoqué. Demander confirmation avant une action sensible (par exemple verrouillage définitif), donner un retour visible après chaque action et respecter lisibilité, tailles tactiles et accessibilité.

## Principes
- **Android uniquement** (pas d'iOS, pas de web dans ce dépôt).
- **Supabase Auth** : connexion par adresse email + mot de passe. Le mot de passe oublié envoie un code de récupération email de 8 chiffres ; les droits sont appliqués par la base (RLS). Aucune clé service_role dans l'app.
- **Hors-ligne d'abord** : le dossier est téléchargé sur le téléphone ; chaque résultat d'écriture est enregistré localement puis envoyé dès que le réseau revient.
- **Deux modes** (comme le web) : lien vers un profil, ou données réelles écrites directement.
- Charte IziCard : cyan #01A3CA, bleu #0299E2, blanc.

## Écrans
Connexion · Accès révoqué · Accueil (selon rôle) · Clients et accès (admin) · Création de dossier · Liste des dossiers · Détail du dossier · Import Excel (fichier, correspondance des colonnes, aperçu, bilan) · **Écriture en série** · Vérifier un tag · Synchro en attente · Réglages.

## Boucle d'écriture
1. Charger la prochaine carte « à écrire » du dossier (cache local).
2. Afficher « Pose le tag n° 37 / 120 ».
3. Écrire l'enregistrement NDEF selon le type de donnée.
4. Relire le tag et comparer avec la donnée attendue.
5. Enregistrer localement (statut vérifié ou erreur, UID, verrou) puis passer à la suivante, avec bip et vibration.
6. En arrière-plan : envoi à `nfc_mark_written`.
Erreur : bandeau rouge + Réessayer. Un UID déjà associé à une autre carte est refusé par la base : l'app le signale et ne passe pas à la carte suivante.

## NDEF par type de donnée
url → enregistrement URI · text → enregistrement texte · phone / email / sms → URI tel: / mailto: / sms: (déjà construits côté base) · geo → URI geo: · contact → vCard. La donnée finale est calculée côté base et stockée dans `nfc_tags.payload` : l'app n'a qu'à l'écrire telle quelle.

## Hors-ligne et conflits
Table locale « file d'attente » : tag, statut, UID, erreur, verrou, date. Envoi dans l'ordre, nouvelle tentative automatique. Si l'accès a été révoqué entre-temps, l'envoi échoue : l'app affiche l'écran « accès révoqué » et garde la file pour l'admin.

## Sécurité
Jeton de session stocké de façon sécurisée (stockage chiffré Android). Données hors-ligne limitées aux dossiers téléchargés. Déconnexion = effacement du cache local. Verrouillage définitif jamais activé par défaut, avec confirmation.

## Construction sans terminal
GitHub Actions construit l'APK/AAB (workflows fournis). La clé de signature et les clés Supabase sont dans les secrets GitHub, jamais dans le dépôt.

## Android
Après génération du dossier android/ : ajouter la permission NFC et la déclaration de fonctionnalité NFC dans AndroidManifest.xml (voir android/README.md).

## Bibliothèques candidates (à valider à la construction, versions comprises)
supabase_flutter · nfc_manager · flutter_riverpod · go_router · drift ou sqflite · connectivity_plus · excel · file_picker · share_plus · flutter_secure_storage · vibration · audioplayers.

## Limites
L'écriture sur plusieurs lecteurs en parallèle (encodeur PC) n'est pas dans ce dépôt : prévue plus tard côté agent PC. La disponibilité exacte de chaque fonction NFC (relecture, verrouillage) dépend de la bibliothèque et du téléphone : à tester sur appareil réel avec 5 à 10 tags avant production.
