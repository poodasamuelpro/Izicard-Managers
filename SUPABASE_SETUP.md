# Configuration Supabase obligatoire

## 0. Variables de l'application (obligatoires au build)

L'application Flutter exige `SUPABASE_URL` (Project URL) et `SUPABASE_ANON_KEY` (clé `anon` / public) **au moment de la compilation** (`--dart-define-from-file=env.json`), pour les builds debug et release. Jamais la clé `service_role`. Voir [`GUIDE_DEPLOIEMENT.md`](GUIDE_DEPLOIEMENT.md).

## 1. Authentification

Dans le projet Supabase `thsedbhzhonemdhbndpf`, ouvrir **Authentication > Providers > Email** et activer Email provider. Le parcours de l’application utilise `signInWithPassword`, `resetPasswordForEmail`, `verifyOTP` avec `OtpType.recovery`, puis `updateUser`. Les utilisateurs sont créés depuis **Authentication > Users** ou par le processus d’administration prévu ; l’application ne crée pas automatiquement de compte.

## 2. OTP de récupération à 8 chiffres

Le serveur Auth doit avoir `mailer_otp_length` réglé à `8`. Ce réglage est une configuration Auth, pas une table SQL. Dans un environnement géré, le réglage peut être fait dans le Dashboard ou avec la Management API du projet. La valeur doit rester entre 6 et 10.

Exemple Management API à exécuter uniquement avec un access token Supabase de gestion, jamais avec la clé anon :

```bash
export SUPABASE_ACCESS_TOKEN='TOKEN_DE_GESTION_SUPABASE'
export PROJECT_REF='thsedbhzhonemdhbndpf'

curl -X PATCH "https://api.supabase.com/v1/projects/${PROJECT_REF}/config/auth" \
  -H "Authorization: Bearer ${SUPABASE_ACCESS_TOKEN}" \
  -H "Content-Type: application/json" \
  -d '{"mailer_otp_length":8,"mailer_otp_exp":3600}'
```

## 3. SMTP Resend

Dans **Authentication > SMTP Settings**, activer le SMTP personnalisé Supabase avec les valeurs données par Resend : hôte SMTP, port, utilisateur SMTP, mot de passe SMTP, email expéditeur vérifié et nom `IziCard`. Ne mettre aucune de ces valeurs dans Flutter, dans le dépôt ou dans le fichier `.env.example`.

Le SMTP par défaut Supabase est adapté aux tests mais limité et réservé aux adresses autorisées. Resend doit être utilisé pour les envois réels.

## 4. Template de récupération

Dans **Authentication > Email Templates > Recovery**, utiliser un template qui affiche le token à 8 chiffres. Le code `{{ .Token }}` est fourni par Supabase Auth :

```html
<h2>Réinitialisation de votre mot de passe IziCard</h2>

<p>Voici votre code de récupération :</p>

<p style="font-size:32px;letter-spacing:8px;font-weight:700;color:#01A3CA">
  {{ .Token }}
</p>

<p>Ce code est valable pendant la durée configurée dans Supabase.</p>
```

Le même principe peut être appliqué au template de confirmation si la confirmation d’adresse est activée. L’adresse du logo doit être une URL HTTPS publique ; ne pas utiliser un chemin local.

## 5. Schéma métier NFC

La migration Supabase vers le schéma `nfc` est confirmée comme déployée (2026-10-25, selon le propriétaire). Toutes les tables, types, vues et fonctions métier NFC doivent être lues/appelées dans `nfc`, sans repli vers `public`. Ne pas rejouer le bootstrap historique `001_nfc.sql` : il ne décrit pas l’état actuellement installé.

Les scripts de règles de formats donnés avec la consigne sont des prérequis avant les essais de ces écrans :

1. Exécuter `003_nfc_enum_code.sql` seul dans une exécution du SQL Editor pour ajouter la valeur enum `code`.
2. Après la réussite de 003, exécuter `004_nfc_formats_rules.sql` dans une autre exécution du SQL Editor. Il ajoute `rules`/`settings`, les formats, le contrôle client de `can_create_batches`, `p_settings` et la RPC `nfc_import_rows`.

Ne pas exécuter les deux scripts dans une même transaction/exécution. Le code mobile n’embarque aucune logique `service_role`. L’Admin seul invite des clients et peut créer un dossier pour tout client; un client peut créer uniquement pour son propre client si l’Admin active `nfc.nfc_clients.can_create_batches` (faux par défaut), avec le contrôle final effectué côté fonction/RLS. Web et mobile partagent le même schéma et les mêmes RPC. Au moment de ce lot, l’application mobile n’a pas été compilée et aucune connexion/test Supabase n’a été lancé.

## 6. Redirection et sécurité

Le flux de récupération par code ne dépend pas d’un lien de redirection. Si Supabase est configuré en mode lien, ajouter l’URL web et le deep link Android dans **Authentication > URL Configuration** et utiliser la page de changement de mot de passe correspondante.

La clé publishable/anon peut être présente côté client. Une clé `service_role`, le token Management API et les identifiants SMTP Resend sont des secrets serveur et ne doivent jamais être exposés.
