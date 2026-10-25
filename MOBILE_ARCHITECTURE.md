# IziCard NFC Encoder — App Android (Flutter)

Objectif : encoder des cartes/tags NFC en série (100+), depuis un téléphone Android, avec les mêmes dossiers, clients et règles que la plateforme web. Même base Supabase (tables nfc_), mêmes fonctions : nfc_create_batch, nfc_import_rows, nfc_mark_written, nfc_set_access.

## Principes
- **Android uniquement** (pas d'iOS, pas de web dans ce dépôt).
- **Supabase Auth** : connexion par adresse email et code OTP de 8 chiffres, sans mot de passe dans le parcours mobile. Les droits sont appliqués par la base (RLS). Aucune clé service_role dans l'app.
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
