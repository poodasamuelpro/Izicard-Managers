# Mobile — ce qui manque selon les attentes (audit du 2026-10-26, mis à jour après le lot M4 à 21:07 UTC)

Légende : ✅ fait et branché · ⚠️ fait mais incomplet · ❌ absent · 🔒 attend une décision du propriétaire · 🛠 attend la phase compilation/Android.
Aucune ligne ✅ n'a été compilée ni testée.

## 1. Écrans
| Écran | État |
|---|---|
| Connexion, mot de passe oublié (code 8 chiffres), activation par invitation, accès révoqué | ✅ |
| Accueil par rôle (9 destinations) | ✅ |
| Clients et accès (liste, invitation, actif/révoqué, expiration, droit de création) | ✅ |
| Création de dossier, liste des dossiers, détail avec cartes paginées | ✅ |
| Import fichier (mapping, aperçu, bilan, modèle), saisie manuelle | ✅ |
| Écriture en série, vérification d'un tag, export CSV, réglages, synchronisation | ✅ |
| Liste des dossiers **hors connexion** (dossiers téléchargés ; bandeau, détail et cartes lus dans le cache) | ✅ |
| Détail d'une carte (champs, donnée copiable, UID, tentatives, dernière erreur, verrouillage) | ✅ |
| Écrire **une seule carte** précise (depuis le détail d'une carte ou « Encoder une seule carte » dans l'écriture ; hors connexion possible) | ✅ |
| Compte dans Réglages (changer le mot de passe, déconnexion avec alerte si résultats non synchronisés, version) | ✅ |
| Modifier un client (nom, contact, e-mail de contact, téléphone) | ✅ |
| Tableau de bord admin (totaux cartes et clients, dossiers avec erreurs, volume par client) | ✅ |
| Aide si le NFC est désactivé (bandeau + bouton vers les réglages NFC d'Android : écriture, une carte, vérification) | ✅ |

## 2. Fonctionnalités et logique
| Point | État |
|---|---|
| Choix du dossier à l'écriture et liste des dossiers hors connexion (dossiers déjà téléchargés) | ✅ |
| Annuler (« void ») ou réactiver une carte | 🔒 ❌ (règle à confirmer : écriture directe en table ou RPC) |
| Retraitement d'une carte déjà vérifiée par l'admin (la base l'autorise) | ❌ |
| Confirmation avant d'écraser un tag qui contient déjà des données | ❌ |
| Synchronisation quand l'application est fermée (tâche de fond) | ❌ (premier plan seulement) |
| Rafraîchissement automatique des compteurs (temps réel) | ❌ (tirer pour actualiser) |
| Nettoyage automatique des dossiers téléchargés terminés | ❌ |
| Import hors connexion | ❌ (réseau requis, par conception) |
| Génération automatique de codes, QR codes, liaison avec les commandes du site | hors périmètre |
| Ouverture directe de l'application depuis le lien d'invitation (deep link) | ❌ 🛠 |
| Anglais | interdit — application exclusivement française |

### Points à signaler (lot M4)
- Le champ `can_create_batches` de `nfc_clients` est marqué « legacy, ignoré par les autorisations » dans la migration 001 : l'interrupteur du dialogue d'accès l'écrit toujours mais n'a peut-être aucun effet. À trancher avec le propriétaire.
- Modifier un client change `nfc_clients` seulement, pas l'e-mail de connexion (Supabase Auth).
- Hors connexion, la création de dossier est masquée ; l'import exige le réseau.
- Rien n'a été compilé : `package_info_plus` et `app_settings` sont nouveaux dans `pubspec.yaml`.

## 3. Sécurité
| Point | État |
|---|---|
| Aucune clé privilégiée dans l'application, droits appliqués par la base | ✅ |
| Accès recontrôlé toutes les 2 min, file conservée, cloisonnement par utilisateur | ✅ |
| **Cache hors-ligne en clair** (données santé IziCare lisibles dans la base SQLite) : chiffrement à prévoir | ❌ |
| **Session Supabase stockée par défaut en clair** (préférences) : stockage chiffré à prévoir | ❌ |
| Option « effacer les données de cet appareil » (dossiers téléchargés) à la déconnexion | ❌ |
| Verrouillage de l'application (PIN/biométrie) | ❌ |
| Vérification réelle des droits (RLS, grants) dans Supabase | 🛠 non testée |

## 4. Interface et responsive
| Point | État |
|---|---|
| Charte IziCard, états chargement / vide / erreur, couleurs d'état | ✅ |
| Tablette et paysage : largeur de contenu limitée, mise en page à deux colonnes | ⚠️ (seulement connexion et accueil) |
| Thème sombre (réglage système / clair / sombre, couleurs d'état lisibles, barre d'état) | ✅ 24 écrans actifs relus un par un (aucun texte ou fond clair fixe restant) ; 6 widgets jamais utilisés (`batch_progress_card`, `tag_list_tile`, `last_tags_list`, `lock_confirm_dialog`, `tag_status_banner`, `access_dialog`) non adaptés ; rendu non vérifié sur appareil |
| Audit d'accessibilité (contrastes, lecteur d'écran, grandes polices) | ❌ |
| Icône, nom et écran de démarrage de l'application | ✅ lot M16 — icône adaptative/monochrome + splash natif générés depuis le logo, non vérifiés sur appareil réel |

## 5. Plateforme, build, qualité
| Point | État |
|---|---|
| Dossier `android/` et permission NFC (`android.permission.NFC`, `android.hardware.nfc`), `minSdk` | ✅ lot M16 — généré, NFC facultatif déclaré, vérifié avec aapt2 |
| Compilation, `flutter analyze`, noms exacts de l'API `nfc_manager` | ✅ lot M16 — `flutter analyze` 0 erreur, `flutter test` 11/11, APK debug construit et vérifié |
| Workflows GitHub Actions (`analyze_test.yml`, `build_apk.yml`) | présents, jamais exécutés |
| Signature de l'APK | ❌ 🛠 build debug non signé livré (lot M16) ; signature release à fournir par le propriétaire |
| Tests (`test/` = 4 fichiers vides) | ✅ tests écrits (lots précédents), tous passent (lot M16) |
| Essais sur 5 à 10 vrais tags (écriture, relecture, verrouillage, hors-ligne, révocation) | ❌ 🛠 |

## 6. Dépendances hors du code mobile (actions du propriétaire)
- Appliquer `003_nfc_enum_code.sql` seul, puis `004_nfc_formats_rules.sql` dans Supabase.
- Déployer l'Edge Function `create-client-user` (sinon l'invitation d'un client échoue), configurer Resend, désactiver l'inscription publique.
- Vérifier les droits de lecture de `nfc_tags` (recherche par UID) et de `nfc_mark_written`.

## 7. Décisions ouvertes
1. `access_code` écrit en clair sur les cartes membre ?
2. Garder ou désactiver `izicare_direct` / `izipro_direct` ?
3. Annulation / réactivation d'une carte et archivage d'un dossier : par l'admin seulement, et avec quelle règle ?

## 8. Décisions confirmées par le propriétaire — 2026-10-26 23:16 UTC

- L’e-mail modifiable depuis la fiche client est uniquement un e-mail de contact. Il ne doit jamais modifier l’e-mail de connexion Supabase Auth.
- Un client peut créer lui-même un dossier lorsqu’il est autorisé, uniquement pour son propre compte/client. Cette règle est déjà contrôlée par le mobile et par la RPC `nfc_create_batch`.
- Les workflows GitHub Actions ne seront pas utilisés pour la validation. Les fichiers restent tels quels et la compilation/analyse seront exécutées depuis un terminal ou un autre environnement.
- Le projet Android complet est en attente jusqu’à la fin du développement fonctionnel.
- Le profil en cache hors connexion est conservé conformément à la politique produit.
- Les données de l’application sont des liens de profil IziCard ; aucune donnée sensible IziCare n’est traitée dans ce projet. Aucun chiffrement de cache ne sera ajouté s’il risque de fragiliser la synchronisation, mais la décision pourra être réévaluée si le périmètre de données change.
- Le stockage sécurisé spécifique de session Supabase n’est pas nécessaire à ce stade. Un PIN local optionnel pourra être ajouté ultérieurement ; s’il est activé, il devra être défini à 6 chiffres, et s’il ne l’est pas l’application ne sera pas bloquée.

## 9. Nouveau travail fonctionnel

| Fonction | État |
|---|---|
| Annulation explicite d’une lecture NFC | ✅ code ajouté, compilation à confirmer |
| Timeout de lecture NFC et fermeture propre de session | ✅ code ajouté, compilation à confirmer |
| Confirmation avant écrasement d’un tag contenant déjà des données | ❌ à ajouter |
| Archivage d’un dossier | ❌ nécessite RPC/backend partagé |
| Historique/audit consultable dans l’application | ❌ nécessite contrat backend partagé |
| Écoute Realtime Supabase pour les changements de dossiers/cartes | ❌ à ajouter |
| Synchronisation lorsque l’application est totalement fermée | ❌ à traiter après génération Android |

## 10. Lot M6 — confirmation d’écrasement — 2026-10-26 23:17 UTC

La lecture du contenu NDEF existant et la confirmation utilisateur sont maintenant branchées sur l’écriture en série et l’écriture d’une carte unique. Une annulation ne crée pas d’erreur dans la file de synchronisation. Il reste à compiler et tester sur des tags physiques lorsque l’environnement Android sera disponible.

## 11. Lot M7 — temps réel — 2026-10-26 23:18 UTC

✅ L’écran Dossiers écoute désormais `nfc.nfc_batches` et `nfc.nfc_tags` via le Realtime Supabase natif et rafraîchit les compteurs avec anti-rebond. Une migration backend partagée `005_nfc_realtime.sql` a été poussée dans le dépôt Web ; elle doit être appliquée dans Supabase. La compilation et le test avec une modification distante restent à effectuer.

## 12. Lot M8 — archivage et historique — 2026-10-26 23:19 UTC

✅ Archivage/réactivation réversible d’un dossier avec confirmation admin via RPC partagée. ✅ Consultation de l’historique d’audit d’un dossier via RPC sécurisée réservée aux admins. Le backend Web contient la migration `006_nfc_archive_history.sql`. À faire : appliquer les migrations Supabase 005/006 et compiler/tester avec des droits réels.


## 13. Lot M12 — backend Supabase appliqué — 2026-10-27 00:56 UTC
- ✅ `004_nfc_formats_rules.sql` appliquée dans `nfc`.
- ✅ `005_nfc_realtime.sql` appliquée pour `nfc_batches` et `nfc_tags`.
- ✅ `006_nfc_archive_history.sql` appliquée.
- ✅ Edge Function `create-client-user` déployée avec JWT obligatoire.
- ✅ `send-activation-emails` existante conservée inchangée.
- ⚠️ Restent à faire : configuration SMTP Resend, OTP à 8 chiffres, templates Recovery/Invite, URLs autorisées/deep link, secret `INVITE_REDIRECT_TO`, puis tests réels Auth/RLS/Realtime/NFC et build Android.


## 14. Lot M13 — invitations et comptes Auth existants — 2026-10-27 01:24 UTC
- ✅ L’Edge Function `create-client-user` vérifie le rôle admin et les URLs de redirection autorisées.
- ✅ Un compte déjà existant dans Supabase Auth est réutilisé sans suppression ni modification de son mot de passe ; seul le profil `nfc` est créé/rattaché.
- ⚠️ Tester avec un compte réel et vérifier les Redirect URLs du Dashboard sans retirer celles des autres applications.
