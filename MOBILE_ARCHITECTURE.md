# IziCard NFC Encoder — App Android (Flutter)

Objectif : fournir une application Android d’encodage NFC en série (100+) et une interface mobile complète de l’écosystème IziCard. L’application et l’espace admin Web ont la même parité fonctionnelle métier et utilisent un backend/API unique : même projet Supabase, mêmes tables `nfc_`, mêmes fonctions serveur/RPC (dont `nfc_create_batch`, `nfc_import_rows`, `nfc_mark_written`, `nfc_set_access`) et mêmes politiques RLS. Il n’existe pas de backend métier mobile distinct.

En mode administrateur, le mobile doit pouvoir réaliser les opérations disponibles dans l’espace admin Web : gestion des clients et accès, création et suivi des dossiers, import/export et autres opérations métier. Toute logique métier partagée réside côté backend et est appelée par les deux interfaces ; elle ne doit pas être dupliquée dans Flutter. Les différences sont limitées à l’interface et aux intégrations natives, notamment le NFC Android.

## Schéma Supabase et sécurité
Toutes les données et opérations métier NFC doivent utiliser le schéma `nfc` du projet Supabase commun (`nfc.nfc_profiles`, `nfc.nfc_batches`, fonctions RPC qualifiées dans `nfc`, etc.). Le client PostgREST mobile est configuré avec `nfc` par défaut et les lectures de profil le qualifient explicitement. Ne jamais supposer `public` ni basculer silencieusement vers ce schéma. La migration Supabase vers `nfc` est confirmée comme déployée (2026-10-25, selon le propriétaire) ; le script SQL historique du dépôt Web reste à réaligner pour les installations futures. L’exposition PostgREST/RPC, les privilèges et RLS devront être vérifiés lors des tests autorisés. Aucun test de connexion n’est exécuté dans ce lot.

Charger le profil/rôle depuis `nfc.nfc_profiles` et traiter côté serveur les statuts actif/révoqué et les permissions. L’Admin seul ajoute/invite des clients et peut créer un dossier pour n’importe quel client. Un client invité peut créer un dossier uniquement pour son propre `client_id` si `nfc.nfc_clients.can_create_batches = true`; l’Admin gère ce droit, désactivé par défaut. Cette règle remplace toutes les anciennes mentions « Admin seulement » pour la création de dossiers. Il n’y a pas d’auto-inscription : un client non invité ne peut pas accéder à l’app. L’invitation réutilise la même Edge Function `create-client-user` que le Web; aucune clé privilégiée n’est intégrée à Flutter. La visibilité des dossiers reste contrôlée par RLS.

## Exigences d’interface
UI/UX de qualité professionnelle, alignée sur la charte IziCard (cyan `#01A3CA`, bleu `#0299E2`, blanc), claire et intuitive. Prévoir un accueil distinct selon le rôle, une navigation cohérente avec bouton retour sur les écrans secondaires où nécessaire, et des états de chargement, erreur, liste vide et accès révoqué. Demander confirmation avant une action sensible (par exemple verrouillage définitif), donner un retour visible après chaque action et respecter lisibilité, tailles tactiles et accessibilité.

## Principes
- **Android uniquement** (pas d'iOS, pas de web dans ce dépôt).
- **Supabase Auth** : connexion par adresse email + mot de passe. Le mot de passe oublié envoie un code de récupération email de 8 chiffres ; les droits sont appliqués par la base (RLS). Aucune clé service_role dans l'app.
- **Hors-ligne d'abord** : le dossier est téléchargé sur le téléphone ; chaque résultat d'écriture est enregistré localement puis envoyé dès que le réseau revient.
- **Deux modes** (comme le web) : lien vers un profil, ou données réelles écrites directement.
- Charte IziCard : cyan #01A3CA, bleu #0299E2, blanc.

## Écrans et périmètre mobile actuel
Connexion · Accès révoqué · Accueil (selon rôle) · Clients et accès (Admin, incluant l’interrupteur de création) · Création de dossier (Admin ou client autorisé) · Liste/détail des dossiers · Import `.xlsx`/`.xls`/`.csv` (choix dossier/feuille, mapping modifiable, aperçu, lots de 500, bilan et export CSV des erreurs) · Saisie manuelle d’une carte · modèle Excel par format avec feuille Instructions. Ces parcours sont codés mais restent non compilés/non testés.

L’écriture NFC en série, la relecture physique, l’export métier général et la synchronisation hors ligne sont hors périmètre de cette étape; leur présence dans les sections suivantes décrit uniquement la cible, pas un fonctionnement livré.

## Formats et import
Les écrans ne codent pas les champs par format : ils lisent `code`, `label`, `default_data_type`, `payload_template`, `chip`, `capacity_bytes`, `field_schema` et `rules` depuis `nfc.nfc_card_formats`. Le même `field_schema` pilote le formulaire manuel, le modèle, la reconnaissance des en-têtes et les labels de l’aperçu. Les cellules sont lues comme texte; les valeurs sont envoyées avec les clés techniques définies par le format à `nfc_import_rows` par paquets de 500. Les validations de contenu et le nettoyage restent à Supabase; l’application bloque seulement les associations manquantes des champs `required`/`required_any` avant envoi.

Le format dont `default_data_type = 'code'` expose les réglages `code_charset`, `code_min` et `code_max`; le client transmet `p_settings` au RPC de création. Les autres formats n’envoient pas `p_settings`.

## Boucle d'écriture
1. Charger la prochaine carte « à écrire » du dossier (cache local).
2. Afficher « Pose le tag n° 37 / 120 ».
3. Écrire l'enregistrement NDEF selon le type de donnée.
4. Relire le tag et comparer avec la donnée attendue.
5. Enregistrer localement (statut vérifié ou erreur, UID, verrou) puis passer à la suivante, avec bip et vibration.
6. En arrière-plan : envoi à `nfc_mark_written`.
Erreur : bandeau rouge + Réessayer. Un UID déjà associé à une autre carte est refusé par la base : l'app le signale et ne passe pas à la carte suivante.

## NDEF par type de donnée
url → enregistrement URI · text → enregistrement texte · phone / email / sms → URI tel: / mailto: / sms: (déjà construits côté base) · geo → URI geo: · contact → vCard. Pour `code`, la base fournit soit le code, soit un lien rendu via le modèle. La donnée finale est calculée côté base et stockée dans `nfc.nfc_tags.payload`; lorsqu’elle sera implémentée, l’app devra l’écrire telle quelle. L’écriture elle-même n’est pas dans le lot actuel.

## Hors-ligne et conflits
Table locale « file d'attente » : tag, statut, UID, erreur, verrou, date. Envoi dans l'ordre, nouvelle tentative automatique. Si l'accès a été révoqué entre-temps, l'envoi échoue : l'app affiche l'écran « accès révoqué » et garde la file pour l'admin.

## Sécurité
Jeton de session stocké de façon sécurisée (stockage chiffré Android). Données hors-ligne limitées aux dossiers téléchargés. Déconnexion = effacement du cache local. Verrouillage définitif jamais activé par défaut, avec confirmation.

## Construction sans terminal
GitHub Actions construit l'APK/AAB (workflows fournis). La clé de signature et les clés Supabase sont dans les secrets GitHub, jamais dans le dépôt.

## Android
Après génération du dossier android/ : ajouter la permission NFC et la déclaration de fonctionnalité NFC dans AndroidManifest.xml (voir android/README.md).

## Bibliothèques utilisées ou prévues
`supabase_flutter`, `sqflite`, `connectivity_plus`, `excel`, `excel2003`, `file_picker`, `cross_file`, `share_plus`. Les plugins NFC et la compilation doivent être évalués séparément au moment du lot écriture.

## Limites
L'écriture sur plusieurs lecteurs en parallèle (encodeur PC) n'est pas dans ce dépôt : prévue plus tard côté agent PC. La disponibilité exacte de chaque fonction NFC (relecture, verrouillage) dépend de la bibliothèque et du téléphone : à tester sur appareil réel avec 5 à 10 tags avant production.
