# Configuration Supabase obligatoire

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

Après la migration planifiée, toutes les tables, types, vues et fonctions métier NFC doivent être dans le schéma `nfc` et les clients doivent appeler les objets qualifiés de ce schéma. Mettre à jour migrations, références SQL, privilèges, RLS et exposition des fonctions en cohérence ; ne pas utiliser `public` en repli. Web et mobile partagent ce schéma et cette API. Les tests de connexion restent différés.

## 6. Redirection et sécurité

Le flux de récupération par code ne dépend pas d’un lien de redirection. Si Supabase est configuré en mode lien, ajouter l’URL web et le deep link Android dans **Authentication > URL Configuration** et utiliser la page de changement de mot de passe correspondante.

La clé publishable/anon peut être présente côté client. Une clé `service_role`, le token Management API et les identifiants SMTP Resend sont des secrets serveur et ne doivent jamais être exposés.
