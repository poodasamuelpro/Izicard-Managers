# Mobile — ce qui manque selon les attentes (audit du 2026-10-26)

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
| Liste des dossiers **hors connexion** (dossiers téléchargés) | ❌ |
| Détail d'une carte (champs, donnée, historique, erreurs) | ❌ |
| Écrire une seule carte précise | ❌ |
| Compte (changer le mot de passe, déconnexion, version) dans Réglages | ❌ |
| Modifier un client (nom, contact, téléphone) | ❌ |
| Tableau de bord admin (totaux, dossiers en retard, erreurs) | ❌ |
| Aide si le NFC est désactivé (bouton vers les réglages Android) | ❌ |

## 2. Fonctionnalités et logique
| Point | État |
|---|---|
| **Choix du dossier à l'écriture et liste des dossiers dépendent du réseau : impossible de commencer hors connexion** | ❌ (critique) |
| Annuler (« void ») ou réactiver une carte | 🔒 ❌ (règle à confirmer : écriture directe en table ou RPC) |
| Retraitement d'une carte déjà vérifiée par l'admin (la base l'autorise) | ❌ |
| Confirmation avant d'écraser un tag qui contient déjà des données | ❌ |
| Synchronisation quand l'application est fermée (tâche de fond) | ❌ (premier plan seulement) |
| Rafraîchissement automatique des compteurs (temps réel) | ❌ (tirer pour actualiser) |
| Nettoyage automatique des dossiers téléchargés terminés | ❌ |
| Import hors connexion | ❌ (réseau requis, par conception) |
| Génération automatique de codes, QR codes, liaison avec les commandes du site | hors périmètre |
| Ouverture directe de l'application depuis le lien d'invitation (deep link) | ❌ 🛠 |
| Anglais (fichiers de langue vides, tout est en français) | ❌ |

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
| Thème sombre | ❌ |
| Audit d'accessibilité (contrastes, lecteur d'écran, grandes polices) | ❌ |
| Icône, nom et écran de démarrage de l'application | ❌ 🛠 |

## 5. Plateforme, build, qualité
| Point | État |
|---|---|
| Dossier `android/` et permission NFC (`android.permission.NFC`, `android.hardware.nfc`), `minSdk` | ❌ 🛠 |
| Compilation, `flutter analyze`, noms exacts de l'API `nfc_manager` | ❌ 🛠 non vérifiés |
| Workflows GitHub Actions (`analyze_test.yml`, `build_apk.yml`) | présents, jamais exécutés |
| Signature de l'APK | ❌ 🛠 |
| Tests (`test/` = 4 fichiers vides) | ❌ à écrire après la compilation |
| Essais sur 5 à 10 vrais tags (écriture, relecture, verrouillage, hors-ligne, révocation) | ❌ 🛠 |

## 6. Dépendances hors du code mobile (actions du propriétaire)
- Appliquer `003_nfc_enum_code.sql` seul, puis `004_nfc_formats_rules.sql` dans Supabase.
- Déployer l'Edge Function `create-client-user` (sinon l'invitation d'un client échoue), configurer Resend, désactiver l'inscription publique.
- Vérifier les droits de lecture de `nfc_tags` (recherche par UID) et de `nfc_mark_written`.

## 7. Décisions ouvertes
1. `access_code` écrit en clair sur les cartes membre ?
2. Garder ou désactiver `izicare_direct` / `izipro_direct` ?
3. Annulation / réactivation d'une carte et archivage d'un dossier : par l'admin seulement, et avec quelle règle ?
