# API commerciale IziCard — étude de faisabilité et plan

> Statut : **étude** (aucun code d'API publique n'existe encore). Document rédigé le 28/10/2026.
> Les estimations de durée sont des hypothèses pour un développeur seul, à réviser après la phase 0.
> Rien de ce qui est décrit ici n'a été testé en conditions réelles.

## 1. Objectif

Proposer, en plus de l'application IziCard Manager et du site web, une **API privée puis commerciale** qui permet à d'autres logiciels (ERP, boutiques en ligne, outils de gestion d'événements, imprimeurs de cartes) de :

- préparer des cartes NFC (dossiers, données) ;
- piloter leur **encodage** (écriture sur les puces) par une machine ou un téléphone ;
- **vérifier** les cartes et suivre l'avancement ;
- être prévenus automatiquement (webhooks) ;
- le tout vendu avec des clés API, des quotas et une facturation.

Hors périmètre de ce document : refonte de l'application mobile, choix d'un prestataire de paiement précis, rédaction juridique (à confier à un juriste).

## 2. Ce qui existe déjà et ce qui manque

| Élément | État | Réutilisable pour l'API |
|---|---|---|
| Dossiers, cartes, formats, import de lignes | Existe (base `nfc`, fonctions de création/import) | Oui, via la passerelle |
| Enregistrement du résultat d'écriture (fonction de marquage) | Existe | Oui |
| Droits par client (RLS, rôles admin/client) | Existe | Oui, mais voir §10 (isolation multi-clients) |
| Écriture, relecture et verrouillage NFC | Existe, **uniquement dans l'application Android** | Non tel quel : il faut un agent d'encodage (§8) |
| Clés API, quotas, limites de débit | N'existe pas | À créer |
| Webhooks | N'existe pas | À créer |
| Facturation / plans | N'existe pas | À créer |
| Documentation publique (OpenAPI), mode test | N'existe pas | À créer |
| Journal d'audit | Existe (audit des actions) | À étendre aux appels API |

## 3. Architecture cible

```
 Logiciel du client (ERP, boutique…)          Agent d'encodage (PC + lecteur USB / boîtier / app Android)
              │  clé API  (izk_live_…)                      │  jeton d'appareil (izd_…)
              ▼                                             ▼
        ┌───────────────────────────────────────────────────────┐
        │  Passerelle API  (Cloudflare Worker + Hono)           │
        │  • authentification, droits (scopes)                  │
        │  • limites de débit, quotas, idempotence              │
        │  • journal d'usage, webhooks sortants                 │
        └───────────────────────────┬───────────────────────────┘
                                    │  clé de service (secret côté serveur uniquement)
                                    ▼
                      Supabase  (base Postgres, schéma nfc)
```

Règles non négociables :

1. **Les clients de l'API n'accèdent jamais à Supabase directement.** Seule la passerelle parle à la base.
2. **La clé de service Supabase reste dans les secrets du Worker.** Jamais dans une application, un dépôt, un navigateur ni un agent d'encodage.
3. Chaque requête est rattachée à un **locataire** (le client payant) ; toute lecture ou écriture est filtrée par ce locataire (voir §10).

## 4. Modèle de données à ajouter (schéma `api`, séparé de `nfc`)

| Table | Rôle | Champs principaux |
|---|---|---|
| `api.tenants` | Le client payant | id, nom, plan, statut (actif / suspendu), pays, e-mail de facturation, lien vers `nfc_clients` |
| `api.keys` | Clés API | id, tenant_id, préfixe visible (`izk_live_ab12`), **hash** de la clé, environnement (`test` / `live`), scopes, expiration, dernière utilisation, révoquée le |
| `api.usage_daily` | Compteurs | tenant_id, jour, endpoint, nombre d'appels, cartes créées, cartes encodées |
| `api.idempotency` | Anti-doublon | tenant_id, clé d'idempotence, empreinte de la requête, réponse stockée, expire le |
| `api.webhooks` | Abonnements | id, tenant_id, URL, secret de signature, événements, actif |
| `api.webhook_deliveries` | Envois | id, webhook_id, événement, charge, tentative, statut, prochaine tentative |
| `api.devices` | Agents d'encodage | id, tenant_id, nom, hash du jeton, dernière activité, version de l'agent, révoqué le |
| `api.encode_jobs` | Travaux d'encodage | id, tenant_id, dossier, carte, état (voir §8), appareil, tentative, dernier message |
| `api.plans` / `api.invoices` | Facturation | plan, prix, quotas ; factures mensuelles |

Principes : les clés ne sont **jamais** stockées en clair (hash + « poivre » secret du serveur), et sont affichées **une seule fois** à la création.

## 5. Authentification et clés

- Format : `izk_live_<32 caractères aléatoires>` (production), `izk_test_…` (bac à sable). Le préfixe permet de repérer une clé dans un dépôt public.
- En-tête : `Authorization: Bearer izk_live_…`.
- **Scopes** (droits) : `batches:read`, `batches:write`, `cards:read`, `cards:write`, `encode:manage`, `verify:read`, `webhooks:manage`, `usage:read`. Une clé reçoit le minimum nécessaire.
- **Rotation** : deux clés actives possibles en même temps pour changer sans coupure ; révocation immédiate.
- **Cas : clé perdue ou divulguée** → révocation immédiate depuis le tableau de bord ; toutes les requêtes avec cette clé échouent ; alerte envoyée au locataire.
- **Cas : clé de test utilisée en production** → refus (les environnements ne se mélangent jamais ; les données de test sont séparées).
- Les **agents d'encodage** n'utilisent pas la clé du locataire : ils ont un **jeton d'appareil** (`izd_…`) limité à l'encodage (réclamer un travail, rendre un résultat), révocable individuellement.

## 6. Contrat de l'API (v1)

Principes généraux :

- Préfixe : `https://api.<domaine>/v1/…` ; version dans l'URL.
- JSON partout, dates ISO 8601 UTC.
- **Pagination** par curseur (`?limit=100&cursor=…`).
- **Idempotence** : en-tête `Idempotency-Key` obligatoire sur les créations ; rejouer la même requête renvoie la même réponse sans rien recréer.
- **Limites de débit** : en-têtes `X-RateLimit-Limit`, `X-RateLimit-Remaining`, `Retry-After` (réponse 429).
- **Erreurs** uniformes :

```json
{ "error": { "code": "validation_failed", "message": "Numéro de téléphone invalide", "field": "rows[12].phone", "request_id": "req_8f3a…" } }
```

### Endpoints

| Méthode | Chemin | Rôle | Scope |
|---|---|---|---|
| POST | `/v1/batches` | Créer un dossier (nom, format, options) | `batches:write` |
| GET | `/v1/batches` · `/v1/batches/{id}` | Lister / lire (avec compteurs) | `batches:read` |
| POST | `/v1/batches/{id}/cards` | Ajouter des cartes (jusqu'à 2000 lignes par appel) | `cards:write` |
| GET | `/v1/batches/{id}/cards` | Lister les cartes et leur statut | `cards:read` |
| POST | `/v1/batches/{id}/archive` | Archiver / réactiver | `batches:write` |
| POST | `/v1/batches/{id}/encode-jobs` | Demander l'encodage (crée les travaux) | `encode:manage` |
| GET | `/v1/encode-jobs/{id}` | Suivre un travail | `encode:manage` |
| POST | `/v1/verify` | Vérifier une carte par UID ou par identifiant public | `verify:read` |
| GET | `/v1/batches/{id}/export` | Export CSV | `batches:read` |
| POST/GET/DELETE | `/v1/webhooks` | Gérer les abonnements | `webhooks:manage` |
| GET | `/v1/usage` | Consommation du mois | `usage:read` |
| POST | `/v1/devices/claim` · `/v1/devices/jobs/next` · `/v1/devices/jobs/{id}/result` | Réservé aux agents d'encodage | jeton d'appareil |

Exemple — créer des cartes :

```http
POST /v1/batches/b_123/cards
Authorization: Bearer izk_live_…
Idempotency-Key: 6f1c…
Content-Type: application/json

{ "rows": [ { "url": "https://exemple.com/c/001", "ref": "A-001" }, { "url": "https://exemple.com/c/002", "ref": "A-002" } ] }
```

```json
{ "inserted": 2, "failed": 0, "errors": [] }
```

## 7. Webhooks (notifications automatiques)

| Événement | Quand |
|---|---|
| `card.encoded` | Une carte est écrite et relue avec succès |
| `card.failed` | Échec d'écriture ou de relecture |
| `batch.completed` | Toutes les cartes d'un dossier sont vérifiées |
| `device.offline` | Un agent d'encodage ne répond plus |
| `quota.warning` | 80 % puis 100 % du quota atteint |

- **Signature** : en-tête `IziCard-Signature` = HMAC-SHA256 du corps avec le secret du webhook, avec horodatage (protection contre le rejeu au-delà de 5 minutes).
- **Reprises** : en cas d'échec, nouvelles tentatives à 1 min, 5 min, 30 min, 2 h, 12 h, puis abandon et alerte. Chaque envoi est consultable.
- **Cas : l'URL du client est en panne** → les événements sont mis en file et rejoués ; rien n'est perdu pendant 72 h.
- **Cas : événement reçu deux fois** → le client doit dédoublonner avec l'identifiant d'événement (documenté).

## 8. Machine d'encodage (agent d'encodage)

**Principe : une API ne peut pas écrire sur une carte à distance.** Il faut un lecteur NFC physique à côté de la carte. On installe donc un **agent** sur la machine qui tient le lecteur, et l'API sert de file de travaux (modèle « l'agent vient chercher »).

### Formes possibles de l'agent

| Forme | Avantages | Limites |
|---|---|---|
| Application Android existante (mode « connecté à l'API ») | Déjà écrite ; aucun matériel à acheter | Une carte à la fois, vitesse limitée par l'opérateur |
| Programme PC + lecteur USB (type ACR122U / ACR1252U, modèles à valider) | Plus rapide, confortable pour des milliers de cartes | À développer, installation, pilotes selon le système |
| Boîtier autonome (microcontrôleur + lecteur) | Cadence industrielle, peut être couplé à un chargeur de cartes | Matériel et développement les plus lourds |

### États d'un travail d'encodage

```
en_attente → réservé (par un appareil) → en_cours → écrit → vérifié
                                         └─→ échec (tentatives) → abandonné / à revoir
```

- Un appareil **réserve** un travail pour une durée limitée (ex. 2 minutes) ; s'il disparaît, le travail redevient disponible.
- Le résultat envoyé est **idempotent** : le renvoyer deux fois ne change rien.
- Garde-fous repris de l'application : refus d'un tag (UID) déjà associé à une autre carte, confirmation avant d'écraser un contenu existant, relecture comparée avant de valider, verrouillage définitif seulement après relecture réussie et seulement si le locataire l'a demandé.

### Cas documentés

| Cas | Comportement attendu |
|---|---|
| Coupure réseau pendant la série | L'agent garde les résultats localement et les renvoie à la reconnexion, dans l'ordre |
| Deux agents sur le même dossier | Chacun réserve ses propres travaux ; aucune carte n'est donnée deux fois |
| Même puce présentée deux fois | Refusée (UID déjà utilisé), message clair |
| Puce vierge non formatée | Formatée puis écrite ; seconde présentation pour la vérification |
| Puce trop petite pour la donnée | Refus avant écriture (capacité NDEF contrôlée) ; la carte passe en « à revoir » |
| Puce déjà verrouillée | Écriture impossible, signalée ; **un verrouillage est définitif et ne se défait pas** |
| Agent volé ou compromis | Révocation du jeton d'appareil ; les travaux réservés sont libérés |

## 9. Scénarios d'intégration

1. **ERP / boutique en ligne** : à chaque commande de cartes, le logiciel crée un dossier et envoie les lignes ; un webhook `batch.completed` le prévient pour lancer l'expédition.
2. **Encodage de masse (5 000 cartes)** : dossier créé par API, travaux d'encodage créés, un ou plusieurs agents consomment la file ; le tableau de bord montre l'avancement et les échecs.
3. **Revendeur avec plusieurs clients finaux** : un locataire « revendeur » crée des sous-comptes ; chaque sous-compte a ses propres clés et ses quotas (à prévoir en phase 3 ; complexité d'isolation plus élevée).
4. **Vérification publique** : un site tiers demande à l'API si un UID ou un identifiant public correspond à une carte valide (réponse minimale : valide/non valide, sans données personnelles).
5. **Carte unique à la demande** : une application tierce crée une carte et la fait encoder en un seul appel + travail d'encodage.
6. **Mode test** : clés `izk_test_…`, données séparées, aucun agent physique requis (un simulateur renvoie des résultats de test).

## 10. Sécurité : menaces et mesures

| Menace | Mesure |
|---|---|
| **Fuite de données entre clients** (risque n°1) | Filtre par locataire dans toutes les requêtes, règles RLS dédiées, tests automatiques qui tentent d'accéder aux données d'un autre locataire, revue avant chaque mise en production |
| Clé API volée | Hash en base, scopes minimaux, rotation, révocation immédiate, alerte sur usage inhabituel (pays, volume) |
| Abus / envois massifs | Limites de débit par clé et par IP, quotas par plan, plafond de dépenses, coupure automatique et alerte |
| Rejeu d'une requête ou d'un webhook | Idempotence, horodatage signé, expiration à 5 min |
| Injection / données malveillantes | Validation stricte de chaque champ (types, longueurs, formats), requêtes paramétrées, taille maximale des corps |
| Clé de service Supabase exposée | Secret du Worker uniquement ; jamais dans l'agent, l'application ou un dépôt ; rotation planifiée |
| Agent d'encodage détourné | Jeton limité à l'encodage, révocable, association à un locataire, journal de chaque action |
| **Cartes contrefaites** | Un UID simple peut être **copié** sur des tags dits « magiques ». Pour une vraie protection : puces **NTAG 424 DNA** (signature chiffrée différente à chaque lecture), à proposer comme option premium. À valider avec un test matériel avant toute promesse commerciale |
| Panne du fournisseur (Supabase / Cloudflare) | Reprises côté agents et webhooks, état des travaux conservé ; communiquer un objectif de disponibilité réaliste (pas de promesse « 99,99 % » au départ) |

Journal d'audit : chaque appel enregistre locataire, clé (préfixe), route, résultat, durée, identifiant de requête, sans jamais journaliser le contenu sensible des cartes.

## 11. Difficultés et risques

| Sujet | Niveau | Détail |
|---|---|---|
| Isolation multi-locataires | **Élevé** | Une seule faille expose les données d'un client à un autre : à tester le plus tôt possible |
| Agent d'encodage PC / boîtier | **Élevé** | Pilotes, systèmes d'exploitation, matériel ; commencer par l'application Android |
| Fiabilité (reprises, idempotence) | Moyen | Bien défini, mais demande des tests de coupure réseau |
| Facturation et paiements | Moyen | Dépend des pays de tes clients ; solution locale (mobile money) ou carte bancaire selon le cas |
| Support et documentation | Moyen | Un produit public demande une doc claire, des exemples, un canal de support |
| Légal | Moyen | Conditions générales, protection des données (loi 09-08 au Maroc, loi applicable au Burkina), responsabilité en cas de cartes erronées ; **à valider par un juriste** |
| Coûts d'infrastructure | Faible à moyen | Surveiller les limites des offres Supabase et Cloudflare ; les intégrer au prix |
| Charge de travail solo | Moyen | Astreinte, incidents, mises à jour : prévoir du temps après le lancement |

## 12. Modèles de prix (à choisir)

| Modèle | Principe | Pour qui |
|---|---|---|
| Abonnement par paliers | X cartes encodées/mois incluses, puis tarif unitaire | Clients réguliers |
| Paiement à la carte | Prix par carte encodée et vérifiée | Petits volumes, pilotes |
| Licence d'agent d'encodage | Forfait annuel par machine | Imprimeurs, gros volumes |
| Option premium sécurité | Supplément pour puces NTAG 424 DNA + vérification d'authenticité | Billetterie, identité, luxe |

Les prix chiffrés ne sont pas fixés ici : ils dépendent de tes coûts réels (infrastructure, puces, support) et du marché visé.

## 13. Plan de réalisation (hypothèses, développeur seul)

| Phase | Contenu | Durée indicative |
|---|---|---|
| 0. Cadrage | Choix des scénarios prioritaires, modèle de prix, test matériel (lecteur, NTAG 424 DNA) | 1 semaine |
| 1. API privée | Passerelle, clés, scopes, endpoints de base (dossiers, cartes, vérification), journal d'usage, tests d'isolation ; utilisée d'abord par tes propres applications | 3 à 5 semaines |
| 2. Encodage via API | Travaux d'encodage, jetons d'appareil, mode « connecté » de l'application Android, webhooks | 3 à 4 semaines |
| 3. Pilote | 1 à 2 partenaires, documentation OpenAPI, bac à sable, tableau de bord de clés et d'usage | 3 à 4 semaines |
| 4. Commercialisation | Facturation, conditions générales, support, supervision, agent PC si la demande existe | 4 à 8 semaines |

## 14. Décisions à prendre avant de commencer

1. Quels scénarios (§9) sont prioritaires pour tes premiers clients ?
2. Agent d'encodage : Android seulement au début, ou développer tout de suite l'agent PC ?
3. Pays de vente et moyens de paiement des clients cibles ?
4. Les sous-comptes (revendeurs) sont-ils nécessaires dès le lancement ?
5. Option puces NTAG 424 DNA : promesse commerciale ou simple piste ?
6. Qui assure le support (toi, partenaire) et avec quel engagement de disponibilité ?

## 15. Ce qui n'est pas vérifié

- Les durées et la liste de matériel sont des **hypothèses**, sans test réel de lecteurs USB ni de puces NTAG 424 DNA.
- La fonction d'enregistrement des résultats utilisée par l'application est définie dans le dépôt web pour l'ancienne version de la base ; la version en production n'a pas été relue ici.
- Les limites exactes des offres Supabase et Cloudflare, et les règles légales de chaque pays, sont à vérifier à la source avant de s'engager.
