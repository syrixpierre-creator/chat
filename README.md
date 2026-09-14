# SYRIX CHAT

## Rôle de chaque base de données

- **PostgreSQL** : source de vérité des comptes (identifiants, mot de passe
  hashé, solde wallet). Relationnel + transactions ACID, indispensable dès
  qu'il y a de l'argent (wallet, cadeaux, retraits — Day suivants).
- **MongoDB** : contenu à fort volume et schéma flexible — messages de chat,
  stories, posts (modèle `Message` déjà en place, branché à partir du Day 2).
- **Redis** : données éphémères — codes de vérification email (TTL 15 min),
  puis sessions/cache/rate-limiting sur les jours suivants.

## Lancer tout en une commande (API + 3 bases de données)

Prérequis : Node.js 20+, Docker.

```bash
bash setup.sh
```

Ce script :
1. démarre PostgreSQL, MongoDB, Redis, LiveKit et Ollama via Docker (volumes persistants)
2. attend que PostgreSQL soit prêt
3. installe les dépendances de l'API
4. **crée automatiquement les tables PostgreSQL** (`prisma generate` + `db push`)
5. démarre l'API avec **pm2** (gestionnaire de process) sur le port défini
   dans `apps/api/.env` (4000 par défaut)

**Pourquoi pm2 et pas juste `npm run dev` ?** Sans lui, l'API tourne au
premier plan et **s'arrête dès que tu fermes ton terminal SSH/Termius** —
c'est la source n°1 de confusion en environnement VPS ("ça marchait il y a
5 minutes puis plus rien"). Avec pm2, l'API continue de tourner en fond :
```bash
pm2 status              # l'API tourne-t-elle ?
pm2 logs syrix-api       # logs en direct (utile pour diagnostiquer)
pm2 restart syrix-api    # redémarrer après une modif du code
```

**Si le port 4000 est bloqué par ton hébergeur** (certains VPS/panneaux
n'ouvrent qu'une liste restreinte de ports), change-le simplement dans
`apps/api/.env` (`PORT=3000` par exemple, ou tout port autorisé chez toi),
puis relance `bash setup.sh`.

MongoDB et Redis n'ont pas besoin de migration : leurs structures se créent à
la première écriture (Mongo) ou sont de simples clés (Redis).

Sur un VPS neuf : installe Docker (`curl -fsSL https://get.docker.com | sh`)
et Node 20+, clone le projet, lance `bash setup.sh`. Toutes les bases se
créent seules.

## App mobile Flutter

```bash
cd apps/mobile
flutter create .
flutter pub get
bash scripts/post_create_setup.sh
```

`flutter create .` génère les dossiers `android/` et `ios/` (absents du zip,
générés localement chez toi). À faire une seule fois.

`scripts/post_create_setup.sh` ajoute automatiquement dans
`AndroidManifest.xml` toutes les permissions nécessaires (Internet, caméra,
micro, Bluetooth) et autorise temporairement le HTTP non chiffré
(`usesCleartextTraffic`, à retirer une fois l'API en HTTPS via `deploy.sh`).
**Sans la permission Internet, l'app échoue silencieusement sur toute
requête réseau** — c'est le bug le plus sournois du projet, alors ce script
existe justement pour ne plus jamais le rencontrer.

Pour iOS (pas automatisé, à faire à la main), ajoute dans
`ios/Runner/Info.plist` :
```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>SYRIX CHAT needs access to your photos to post stories</string>
<key>NSCameraUsageDescription</key>
<string>SYRIX CHAT needs camera access to go live</string>
<key>NSMicrophoneUsageDescription</key>
<string>SYRIX CHAT needs microphone access to go live</string>
```
Le SDK LiveKit (WebRTC) demande une plateforme iOS minimale de 13.0 —
vérifie/ajuste `platform :ios, '13.0'` en haut de `ios/Podfile`.

Vérifie aussi `minSdkVersion` (dans `android/app/build.gradle` ou
`build.gradle.kts`) — au moins **24**, requis par `flutter_webrtc`
(dépendance de LiveKit).

### Pointer l'app vers ton serveur (étape à ne jamais sauter)

Par défaut, `lib/services/api_client.dart` pointe vers
`http://localhost:4000` — ça ne fonctionne QUE sur un émulateur tournant
sur la même machine que l'API. Pour un vrai téléphone, remplace par l'IP ou
le domaine de ton serveur :
```bash
sed -i 's|http://localhost:4000/api|http://TON_IP_OU_DOMAINE:PORT/api|' lib/services/api_client.dart
sed -i 's|ws://localhost:4000/ws|ws://TON_IP_OU_DOMAINE:PORT/ws|' lib/services/api_client.dart
```
Oublier cette étape est la cause n°1 d'une app qui affiche "Something went
wrong" à chaque tentative de connexion, sans aucune erreur utile.

Puis :
```bash
flutter run
```

Pour générer les packages :
```bash
flutter build apk --release
flutter build appbundle --release
```

## Gmail (vérification email)

Sans configuration, les codes s'affichent dans les logs de l'API
(`[email:dev] code de verification pour ...`). Pour un vrai envoi, dans
`apps/api/.env` :
```
GMAIL_USER=ton.compte@gmail.com
GMAIL_APP_PASSWORD=mot_de_passe_application
```

## Day 2 — Page d'accueil

- Backend : `GET /api/chats` (liste des conversations, Mongo), `POST
  /api/chats/private` (démarrer un chat 1-to-1), `POST /api/chats/group`
  (créer groupe/communauté), `GET /api/users/search?q=` (trouver des amis,
  Postgres), `GET /api/stories` + `POST /api/stories` (Mongo, expiration 24h)
- Mobile : écran d'accueil avec barre de recherche fixe en haut, story bar
  (miniatures rondes), liste de chats, bouton "+" flottant en bas à droite
  (créer groupe/communauté), navigation inférieure à 5 icônes (Accueil,
  Explorer, Live au centre, Notifications, Profil) façon Telegram. Explorer,
  Live et Notifications sont des écrans stub pour le moment.

## Day 3 — Messagerie temps réel

- Backend : serveur WebSocket (`ws`) monté sur `/ws`, authentifié par
  token JWT en query param. Diffusion via Redis pub/sub (`syrix:messages`)
  — chaque message envoyé est persisté dans MongoDB puis publié sur Redis,
  qui pousse l'événement aux sockets ouvertes des participants concernés.
  Prêt pour plusieurs instances de l'API derrière un load balancer.
  Nouvelles routes : `GET /api/chats/:id/messages`,
  `POST /api/chats/:id/messages`.
- Mobile : écran de conversation — bulles de messages (alignées à droite
  pour l'utilisateur, à gauche pour l'interlocuteur), historique chargé au
  chargement, réception instantanée via WebSocket, barre de saisie en bas
  (pièce jointe, champ texte, cadeau, envoi — pièce jointe et cadeau sont
  des stubs "bientôt disponible" pour l'instant). Appui sur un chat ou un
  résultat de recherche ouvre directement la conversation.

## Day 4 — Stories & structure Live

- Backend : upload de médias (`multer`, stocké dans `apps/api/uploads/`,
  servi statiquement sur `/uploads`) — `POST /api/stories/upload`,
  `POST /api/stories/:id/view` (suivi des vues). Sessions live dans
  MongoDB (`LiveSession`) — `GET /api/live`, `POST /api/live/start`,
  `POST /api/live/:id/end`.
- Mobile : story bar avec "Ma story" (sélection photo galerie → upload →
  publication, expire après 24h) et viewer plein écran (barres de
  progression façon Instagram/WhatsApp, tap gauche/droite pour
  naviguer, avance automatique). Onglet Live : grille des lives actifs,
  bouton "Démarrer un live" (titre + création de session), salle de live
  avec bandeau LIVE et bouton "Terminer" pour l'hôte.

**Important** : le moteur vidéo temps réel (diffusion caméra réelle,
WebRTC/RTMP) n'est pas encore branché — la salle de live affiche pour
l'instant un espace réservé ("le moteur vidéo live arrive bientôt"). La
session (démarrage, arrêt, liste des lives actifs, compteur) est
fonctionnelle de bout en bout ; c'est la brique vidéo qui viendra ensuite,
une fois qu'on aura choisi le protocole (WebRTC via un SFU comme LiveKit/
mediasoup, ou RTMP + HLS).

## Day 5 — Profil & paramètres

- Backend : `User` (PostgreSQL) gagne `bio` et `avatarUrl`. Nouvelles
  routes : `PATCH /api/users/me` (bio, langue), `POST /api/users/me/avatar`
  (upload photo de profil, même mécanisme que l'upload de stories). Les
  avatars sont désormais renvoyés dans la liste de chats, la recherche
  d'amis et les stories.
- Mobile : écran Profil complet (avatar, nom, bio, bouton "Modifier le
  profil"), écran d'édition (changer la photo via la galerie, éditer la
  bio), bloc Paramètres (sélecteur de langue, déconnexion avec
  confirmation). Les avatars réels s'affichent maintenant dans la liste de
  chats, les résultats de recherche et la story bar (repli sur l'initiale
  du nom si pas de photo).

## Day 6 — Wallet & Stripe

- Backend : Stripe Checkout pour la recharge du wallet. `GET /api/wallet/packages`
  (4 packs prédéfinis), `POST /api/wallet/checkout` (crée une session Stripe
  Checkout, retourne l'URL de paiement), `GET /api/wallet/balance`,
  `GET /api/wallet/transactions` (historique). Le webhook
  `POST /api/wallet/webhook` vérifie la signature Stripe sur le **corps
  brut** de la requête (monté avant `express.json()` dans `server.ts` —
  c'est la partie la plus facile à casser si on la déplace) et crédite le
  wallet + enregistre une `WalletTransaction` de type `topup` uniquement
  après confirmation `checkout.session.completed`. Deux pages HTML minimales
  (`/wallet/success`, `/wallet/cancel`) accueillent l'utilisateur après le
  paiement, le temps qu'il revienne dans l'app.
- Mobile : écran Portefeuille (solde en évidence, grille de packs de
  recharge, historique des transactions), accessible depuis une carte
  dédiée sur l'écran Profil. Le paiement s'ouvre dans le navigateur externe
  (`url_launcher`) sur la page Stripe Checkout hébergée — pas de saisie de
  carte dans l'app, donc pas de conformité PCI à gérer côté SYRIX CHAT.

### Configurer Stripe (obligatoire pour que la recharge fonctionne)

1. Crée un compte Stripe (mode test suffit) et récupère ta clé secrète
   `sk_test_...` sur https://dashboard.stripe.com/test/apikeys
2. Mets-la dans `apps/api/.env` (`STRIPE_SECRET_KEY`)
3. Pour tester le webhook en local, installe la Stripe CLI puis :
   ```bash
   stripe listen --forward-to localhost:4000/api/wallet/webhook
   ```
   Elle affiche un `whsec_...` à coller dans `STRIPE_WEBHOOK_SECRET`
4. Sur le VPS en production, crée un vrai endpoint webhook dans le
   dashboard Stripe pointant vers `https://tondomaine.com/api/wallet/webhook`
   et utilise le secret qu'il génère
5. `PUBLIC_API_URL` doit être l'URL publique de l'API (pas localhost une
   fois en prod), sinon les pages de retour après paiement ne seront pas
   accessibles au client

Sans `STRIPE_SECRET_KEY` valide, `POST /api/wallet/checkout` échoue — c'est
attendu, pas un bug.

## Day 7 — `/setup`, admin & domaine

- Backend : `GET /api/setup/status` (indique si l'admin existe et si un
  domaine est configuré — appelé au chargement du panneau admin),
  `POST /api/setup/init` (crée le tout premier compte admin, refuse si un
  admin existe déjà — un seul passage possible), `POST /api/setup/domain`
  (admin uniquement, enregistre domaine + nom du site dans la table
  `AppConfig`, une ligne singleton). Back-office : `GET /api/admin/stats`
  (comptes utilisateurs, messages, conversations, lives actifs, stories
  actives) et `GET /api/admin/users` (liste paginée), protégés par un
  middleware `requireAdmin`.
- **Panneau admin** : mini application web servie directement par l'API sur
  `/admin` (`apps/api/public/admin/index.html`, HTML/JS vanilla, pas de
  build séparé). Au premier accès : assistant en 2 étapes — créer le compte
  admin, puis attacher le domaine (ou "Skip for now" pour le faire plus
  tard). Ensuite : écran de connexion (réservé aux comptes admin), puis
  tableau de bord avec statistiques, champ domaine modifiable, et table des
  utilisateurs.

Accès une fois l'API lancée : `http://localhost:4000/admin` (ou
`https://tondomaine.com/admin` en prod).

## Day 8 — Déploiement VPS & builds signés

### Déployer sur le VPS (une seule commande)

Prérequis : un VPS Ubuntu/Debian neuf, un nom de domaine dont le
enregistrement DNS **A** pointe déjà vers l'IP du VPS (obligatoire — Certbot
vérifie ça avant de délivrer le certificat HTTPS).

```bash
git clone <ton-repo> syrix-chat   # ou uploade le zip et décompresse-le
cd syrix-chat
sudo bash deploy.sh chat.tondomaine.com toi@tondomaine.com
```

Ce script (idempotent, rejouable sans risque) :
1. installe Docker, Node.js 20, Nginx, Certbot si absents
2. démarre PostgreSQL, MongoDB, Redis (Docker) et attend qu'ils soient prêts
3. met à jour `apps/api/.env` avec le domaine (`APP_DOMAIN`, `PUBLIC_API_URL`)
4. build l'API (`npm ci`, `prisma generate`, `prisma db push`, `tsc`)
5. crée un service **systemd** (`syrix-api`) qui garde l'API en vie et la
   relance automatiquement en cas de crash ou de reboot du serveur
6. configure Nginx en reverse proxy (avec le support WebSocket pour `/ws`)
7. obtient un certificat **HTTPS gratuit** (Let's Encrypt) et force la
   redirection HTTP → HTTPS

Après le script, complète manuellement les secrets de production dans
`apps/api/.env` (`STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET`, `JWT_SECRET`,
`GMAIL_USER`/`GMAIL_APP_PASSWORD`), puis :
```bash
sudo systemctl restart syrix-api
```

Commandes utiles :
```bash
journalctl -u syrix-api -f       # logs en direct
sudo systemctl restart syrix-api # redémarrer après un git pull
```

### Build `.apk`/`.aab` signés

Le zip ne contient pas `android/` (généré par Flutter). Avant la première
signature :
```bash
cd apps/mobile
flutter create .
flutter pub get
bash scripts/post_create_setup.sh
```
Et n'oublie pas de pointer `lib/services/api_client.dart` vers ton
serveur (voir section "App mobile Flutter" plus haut) **avant** de
compiler — sinon l'APK compilé pointera vers `localhost` et personne ne
pourra se connecter avec.

1. **Générer le keystore** (une seule fois, à conserver précieusement — le
   perdre empêche de publier des mises à jour futures sous le même nom de
   package) :
   ```bash
   SYRIX_KEY_ALIAS=syrix-upload \
   SYRIX_KEYSTORE_PASSWORD=choisis_un_mot_de_passe_solide \
   SYRIX_KEY_PASSWORD=choisis_un_mot_de_passe_solide \
     bash scripts/generate_keystore.sh
   ```

2. **Brancher la signature dans Gradle.** Flutter génère soit
   `android/app/build.gradle` (Groovy), soit `build.gradle.kts` (Kotlin DSL)
   selon la version — ouvre le fichier présent et applique la version
   correspondante :

   **Groovy** (`build.gradle`), ajouter avant le bloc `android {` :
   ```groovy
   def keystoreProperties = new Properties()
   def keystorePropertiesFile = rootProject.file('key.properties')
   if (keystorePropertiesFile.exists()) {
       keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
   }
   ```
   puis dans `android { ... }`, ajouter :
   ```groovy
   signingConfigs {
       release {
           keyAlias keystoreProperties['keyAlias']
           keyPassword keystoreProperties['keyPassword']
           storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
           storePassword keystoreProperties['storePassword']
       }
   }
   buildTypes {
       release {
           signingConfig signingConfigs.release
       }
   }
   ```

   **Kotlin DSL** (`build.gradle.kts`), équivalent :
   ```kotlin
   import java.util.Properties
   import java.io.FileInputStream

   val keystoreProperties = Properties()
   val keystorePropertiesFile = rootProject.file("key.properties")
   if (keystorePropertiesFile.exists()) {
       keystoreProperties.load(FileInputStream(keystorePropertiesFile))
   }

   android {
       signingConfigs {
           create("release") {
               keyAlias = keystoreProperties["keyAlias"] as String?
               keyPassword = keystoreProperties["keyPassword"] as String?
               storeFile = keystoreProperties["storeFile"]?.let { file(it as String) }
               storePassword = keystoreProperties["storePassword"] as String?
           }
       }
       buildTypes {
           getByName("release") {
               signingConfig = signingConfigs.getByName("release")
           }
       }
   }
   ```

3. **Builder** :
   ```bash
   bash scripts/build_release.sh
   ```
   Produit `apps/mobile/dist/syrix-chat.aab` (Play Store) et
   `syrix-chat.apk` (installation directe).

### Rendre l'APK téléchargeable depuis le site

Pour satisfaire "le site et l'apk sera disponible sur le VPS" : copie l'APK
buildé dans `apps/api/public/downloads/` sur le VPS (via `scp`), il devient
alors accessible sur `https://tondomaine.com/downloads/syrix-chat.apk`
(le dossier est déjà servi statiquement par l'API). Le `.aab` n'est pas fait
pour être téléchargé directement — il se soumet au Play Store, qui génère
lui-même les APK optimisés par appareil pour les utilisateurs.

## Day 9 — Vidéo live temps réel (LiveKit / WebRTC)

- **Infra** : serveur LiveKit auto-hébergé ajouté au `docker-compose.yml`
  (image officielle `livekit/livekit-server`), configuré via
  `deploy/livekit.yaml`. Démarré automatiquement par `bash setup.sh` et par
  `sudo bash deploy.sh` comme les autres bases de données.
- **Backend** : `GET /api/live/:id/token` génère un jeton d'accès LiveKit
  (`livekit-server-sdk`) — l'hôte reçoit `canPublish: true` (peut diffuser
  caméra/micro), les spectateurs reçoivent `canPublish: false` (lecture
  seule). Chaque session live correspond à une "room" LiveKit nommée
  `live-<id>`.
- **Mobile** : `LiveRoomScreen` réécrit avec le SDK `livekit_client` — vraie
  connexion WebRTC, demande des permissions caméra/micro à l'hôte, affichage
  en grille des flux vidéo de tous les participants (`VideoTrackRenderer`),
  boutons couper micro/caméra pour l'hôte, déconnexion propre en quittant
  l'écran. Le SDK `livekit_client` évolue vite ; si `flutter pub get` remonte
  des erreurs d'API après une mise à jour de version, compare avec le
  quickstart officiel sur pub.dev/packages/livekit_client.

### Limites à connaître avant la mise en production

- **Clés de dev à changer.** `deploy/livekit.yaml` et `.env.example`
  contiennent des clés de développement identiques (`syrixdevkey` /
  `syrixdevsecret_change_me_before_prod`). Avant toute mise en ligne
  publique : génère une vraie paire de clés (`livekit-cli create-token`
  documente le format, ou simplement une chaîne aléatoire de 32+
  caractères) et remplace-la **aux deux endroits en même temps** (le fichier
  yaml et `apps/api/.env`) — sinon les tokens émis par l'API ne seront plus
  acceptés par le serveur LiveKit.
- **Ports supplémentaires à ouvrir sur le VPS/pare-feu cloud** :
  7880 (signaling), 7881 (TCP WebRTC), 7882 et 50000-50100 (UDP, médias). Le
  script `deploy.sh` ne gère pas encore le pare-feu (`ufw`/groupe de
  sécurité cloud) — à faire manuellement selon ton hébergeur.
- **TURN en production.** Sans serveur TURN, les connexions échouent pour
  les utilisateurs derrière certains NAT/pare-feu restrictifs (réseaux
  d'entreprise, certains opérateurs mobiles). En dev/test ça passe presque
  toujours ; en production avec un public large, prévoir un TURN (LiveKit
  peut en embarquer un, ou utiliser Coturn) pour un taux de connexion
  fiable.
- **`LIVEKIT_URL` doit être joignable depuis le téléphone**, pas juste
  depuis le serveur — même règle que `PUBLIC_API_URL` : en local
  `ws://localhost:7880` ne fonctionne que sur émulateur/même machine, en
  prod il faut `wss://tondomaine.com:7880` (ou un sous-domaine dédié) avec
  un certificat TLS valide sur ce port.

## Day 10 — Assistant IA local (Ollama)

- **Infra** : serveur **Ollama** auto-hébergé ajouté au `docker-compose.yml`
  (données/modèles persistés dans un volume Docker). `setup.sh` et
  `deploy.sh` démarrent le conteneur et téléchargent automatiquement le
  modèle par défaut (`llama3.2:3b`, ~2 Go, tourne sur CPU sans carte
  graphique — plus lent qu'avec GPU mais suffisant pour un usage
  conversationnel léger). Pour changer de modèle : modifie `OLLAMA_MODEL`
  dans `apps/api/.env` puis `docker exec syrix-ollama ollama pull
  <nouveau-modele>` (ex: `qwen2.5:1.5b` pour un VPS très limité en RAM, ou
  un modèle plus gros si tu as plus de ressources).
- **Backend** : un compte utilisateur spécial `syrix_assistant` (`isBot:
  true`) est créé automatiquement au premier besoin. Chaque nouvel
  utilisateur reçoit une conversation avec lui dès l'inscription, avec un
  message de bienvenue. Quand un utilisateur écrit dans cette conversation,
  l'API envoie l'historique récent (20 derniers messages) à Ollama
  (`/api/chat`, sans streaming) et publie la réponse comme un message
  normal — donc elle apparaît en temps réel via le même circuit WebSocket
  que les messages humains, sans rien à changer côté mobile.
- **Mobile** : petit badge "AI" à côté du nom dans la liste de chats pour
  identifier l'assistant, icône robot si pas d'avatar personnalisé. Le
  reste de l'écran de conversation (Day 3) fonctionne sans modification.

### Limites à connaître

- **Latence.** Sur un VPS CPU-only modeste, une réponse peut prendre
  plusieurs secondes (voire davantage sur les premiers appels, le temps que
  le modèle soit chargé en mémoire). Pas d'indicateur "en train d'écrire"
  pour l'instant — l'utilisateur voit juste le message apparaître quand il
  est prêt.
- **RAM nécessaire.** `llama3.2:3b` a besoin d'environ 3-4 Go de RAM libre
  pour tourner correctement. Sur un VPS avec moins de RAM, utilise un
  modèle plus petit (`qwen2.5:0.5b` ou `1.5b`, `phi3:mini`) — la qualité des
  réponses sera plus limitée en contrepartie.
- **Pas de modération intégrée.** Le prompt système garde l'assistant
  poli et concis, mais rien n'empêche un utilisateur de le pousser vers du
  contenu indésirable — un vrai filtrage de contenu (entrée et sortie)
  reste un chantier à part si l'app grandit.
- **Pas de contexte au-delà de la conversation.** L'assistant ne connaît
  rien du profil, des amis ou de l'historique global de l'utilisateur — il
  ne voit que les 20 derniers messages de la conversation en cours.

## Day 11 — Politique de confidentialité, CGU & fiche stores

- **Pages légales hébergées** : `apps/api/public/legal/privacy.html` et
  `terms.html`, servies par l'API sur `/legal/privacy.html` et
  `/legal/terms.html` (raccourcis `/privacy` et `/terms` qui redirigent
  vers ces pages). Ce sont des **brouillons complets et cohérents avec ce
  que l'app fait réellement** (compte, messages, stories, live, wallet
  Stripe, assistant IA auto-hébergé) — mais plusieurs champs sont
  volontairement marqués `[À COMPLÉTER]` (nom légal de l'entreprise, email
  de support, droit applicable...). À remplir, puis à faire relire par un
  juriste avant toute publication — ce n'est pas un avis juridique, et les
  paiements + le contenu généré par les utilisateurs augmentent le risque
  d'une erreur coûteuse si on saute cette étape.
- **`store/listing.md`** : dossier prêt à l'emploi pour la soumission —
  textes de fiche (nom, description courte/longue), mapping "Data Safety"
  (Google Play) et "App Privacy" (Apple), liste des captures d'écran à
  préparer, et repères pour la classification par âge.
- **Vérification d'âge ajoutée** (comblait un vrai trou signalé dans le
  brouillon légal) : le signup demande maintenant une date de naissance,
  refusée côté serveur si l'utilisateur a moins de 16 ans
  (`MINIMUM_AGE` dans `authController.ts`, ajustable). Sans ça, les deux
  stores pouvaient rejeter l'app à cause du chat ouvert entre inconnus.

**Avant de soumettre aux stores**, dans cet ordre :
1. Complète les `[À COMPLÉTER]` dans `privacy.html` et `terms.html`
2. Relance `bash setup.sh` (nouvelle colonne `birthDate`)
3. Vérifie que `/privacy` et `/terms` sont accessibles publiquement une
   fois déployé (`https://tondomaine.com/privacy`)
4. Suis `store/listing.md` pour remplir les fiches Play Console / App
   Store Connect

## Day 12 — Contacts, confidentialité, DM & groupes payants

- **Contacts** : `POST /api/contacts` (ajouter), `DELETE
  /api/contacts/:id` (retirer), `GET /api/contacts` (liste). Ajouter
  quelqu'un depuis une conversation privée (icône "+" dans l'en-tête) le
  fait entrer dans tes contacts.
- **Visibilité du profil** : réglage `profileVisibility` (`everyone` /
  `contacts`) dans l'écran d'édition du profil. `GET
  /api/users/:id/profile` renvoie une version restreinte (juste
  nom/avatar) si le visiteur n'est pas dans les contacts du propriétaire
  et que celui-ci a choisi "mes contacts uniquement".
- **DM payants** : chaque utilisateur peut fixer un `dmPrice` (prix par
  message reçu en privé, 0 = gratuit) dans son profil. Chaque message
  envoyé dans cette conversation débite l'expéditeur et crédite le
  destinataire (transaction wallet immédiate, atomique côté serveur — le
  message n'est créé que si le solde suffit, sinon `402 Payment Required`
  et une bannière propose de recharger). Une bannière dans le chat annonce
  le prix avant d'écrire.
- **Groupes/communautés — lien d'invitation, privé/public, message
  payant** : chaque groupe/communauté a un `inviteCode` unique généré à la
  création, régénérable par le créateur (`POST
  /api/chats/:id/invite/regenerate`). `PATCH /api/chats/:id/settings`
  (créateur uniquement) permet de renommer, basculer `isPrivate`
  (privé/public — pour l'instant un simple indicateur, il n'y a pas encore
  d'annuaire public des groupes pour l'exploiter, seul le lien
  d'invitation fait rejoindre quelqu'un), et fixer `messagePrice` (chaque
  message d'un membre autre que le créateur débite l'expéditeur et
  crédite le créateur, même mécanique que les DM payants). Rejoindre un
  groupe : `POST /api/chats/join/:inviteCode`, exposé côté mobile dans
  l'onglet **Explorer** (coller le lien ou le code).
- **Mobile** : icône réglages dans l'en-tête des conversations de groupe
  (nom, privé/public, prix par message, lien d'invitation avec copie),
  icône "ajouter aux contacts" dans les conversations privées, bannière
  de prix DM, dialogue de recharge si solde insuffisant, historique
  wallet qui distingue maintenant crédits (+) et débits (-).

### Limites à connaître

- Le badge "privé/public" des groupes n'a pas encore d'usage réel au-delà
  de l'affichage — il n'y a pas d'annuaire/recherche de groupes publics
  pour l'instant. Le lien d'invitation fonctionne dans les deux cas.
- Les contacts sont à sens unique (si tu ajoutes quelqu'un, ça ne l'ajoute
  pas automatiquement de son côté) — comme les contacts Telegram, pas
  comme une demande d'ami Facebook à accepter. Change ça si tu veux un
  système à double confirmation.
- Les paiements de messages sont immédiats et sans confirmation
  utilisateur avant envoi (pas de "es-tu sûr de payer X crédits ?") — à
  ajouter si tu veux éviter les envois accidentels coûteux.

## Day 13 — Déploiement sur VPS à ports restreints (6 ports + 80/443)

Certains VPS/panneaux d'hébergement n'ouvrent qu'un nombre limité de ports
publics (au-delà de 80/443, toujours ouverts pour le web). `deploy.sh` gère
maintenant ce cas : sur l'ensemble du projet, **un seul port supplémentaire
est réellement nécessaire** pour tout faire fonctionner.

### Pourquoi un seul port suffit

- L'API (HTTP + WebSocket du chat) passe entièrement par Nginx sur
  443 — pas de port dédié à ouvrir.
- Le signaling LiveKit (la partie "négociation" du live, pas la vidéo
  elle-même) passe aussi par Nginx, sur `https://tondomaine.com/livekit`
  — donc pas de port dédié non plus.
- Seul le **flux vidéo/audio** du live ne peut pas passer par un
  reverse-proxy HTTP classique (ce n'est pas du HTTP). Il utilise le
  serveur TURN intégré à LiveKit, configuré pour tout faire transiter en
  TLS sur **un seul port TCP** (`3010` par défaut) — donc pas besoin
  d'ouvrir une plage UDP, ce qui correspond à un VPS où l'on ne sait pas
  si UDP est autorisé. PostgreSQL, MongoDB, Redis et Ollama ne sont
  accessibles que depuis la machine elle-même (`127.0.0.1`) — ils n'ont
  jamais eu besoin d'être publics.

### Ce qui change concrètement

- `docker-compose.yml` reste la version **développement local** (plage de
  ports LiveKit classique, pratique pour tester en LAN).
- `deploy.sh` génère au moment du déploiement un fichier séparé,
  `docker-compose.prod.yml` (à partir de `deploy/docker-compose.prod.yml.template`),
  qui restreint LiveKit à `3010` (TURN/TLS) + `3020` en local uniquement
  (proxié par Nginx) — c'est ce fichier qui tourne réellement sur le VPS.
- `deploy/livekit-prod.yaml` est généré avec une vraie paire de clés
  LiveKit aléatoires (différentes des clés de dev) et le certificat
  Let's Encrypt déjà obtenu pour ton domaine (réutilisé pour le TURN/TLS,
  pas besoin d'un deuxième certificat).
- `apps/api/.env` est mis à jour automatiquement avec
  `LIVEKIT_URL=wss://tondomaine.com/livekit` et les nouvelles clés.

### Ce que tu dois faire toi-même

1. **Ouvrir le port 3010 (TCP)** dans le pare-feu ou le panneau de ton
   hébergeur — c'est le seul port, en plus de 80/443, dont ce projet a
   besoin. Les autres ports que tu as listés (par exemple 3000, 3007,
   2000, 2019) restent libres pour un usage futur.
2. Lancer `sudo bash deploy.sh tondomaine.com toi@email.com` normalement
   — le script obtient d'abord le certificat HTTPS, puis démarre LiveKit
   avec TURN/TLS une fois le certificat disponible (ordre géré
   automatiquement).
3. Si LiveKit n'a pas démarré parce que le certificat n'était pas encore
   prêt (DNS pas propagé, etc.), le script te l'indique clairement à la
   fin — relance simplement la commande qu'il affiche une fois le DNS en
   place.

### Limite à connaître

Le point ICE-relay-only fonctionne bien pour la grande majorité des
réseaux, mais un réseau exceptionnellement restrictif qui bloquerait
aussi le TCP sortant sur port non-standard resterait problématique — cas
rare, mais pas impossible (certains réseaux d'entreprise très verrouillés).
Si des utilisateurs rapportent des lives qui ne se connectent jamais,
c'est la première piste à vérifier.

## Day 14 — Appels, pièces jointes, cadeaux

- **Appels voix/vidéo réels** : réutilisent l'infrastructure LiveKit déjà en
  place pour le Live, mais en 1-to-1 symétrique (les deux participants
  publient). `POST /api/calls/initiate` crée une room LiveKit et notifie
  l'autre utilisateur en temps réel via le même circuit WebSocket que les
  messages (`callEvent: "invite"`). Le destinataire reçoit un dialogue
  d'appel entrant **où qu'il soit dans l'app** (écoute globale au niveau de
  `MainShell`, pas seulement dans l'écran de conversation) — Accepter
  (`POST /api/calls/answer`) rejoint la room, Refuser
  (`POST /api/calls/decline`) prévient l'appelant. Écran d'appel avec
  coupure micro/caméra et raccrocher.
- **Pièces jointes** : upload générique (`POST /api/uploads/chat-media`,
  même mécanisme multer que les stories/avatars), puis message de type
  `image` envoyé normalement — passe par le même circuit temps réel et la
  même logique de facturation (DM payant/groupe payant) que le texte.
- **Cadeaux virtuels** : catalogue fixe de 4 cadeaux (`GET /api/gifts`),
  envoi (`POST /api/gifts/send`) débite l'expéditeur et crédite le
  destinataire (comme les DM payants), crée un message de type `gift`
  affiché avec une bulle dédiée. Limité aux conversations privées pour
  l'instant (pas de destinataire unique évident dans un groupe).

### Limites à connaître

- **Pas de notifications push.** Le dialogue d'appel entrant ne s'affiche
  que si l'app est **ouverte** (connexion WebSocket active). Fermer l'app
  ou la mettre en arrière-plan longtemps = appel manqué sans notification.
  Corriger ça demande d'intégrer Firebase Cloud Messaging (Android) / APNs
  (iOS), un chantier à part entière. Le mode voix cache la vidéo mais
  utilise le même mécanisme LiveKit qu'un appel vidéo (juste sans caméra) —
  donc les mêmes limites réseau que le Live (section Day 9 : TURN/TLS en
  prod) s'appliquent aux appels.
- Les cadeaux dans les groupes/communautés ne sont pas implémentés (limité
  aux DM) — à ajouter si tu veux une mécanique de "cadeau collectif" ou un
  destinataire désigné dans le groupe.

## Day 15 — Interactions sur les messages (traduire, épingler, réagir, anti-spoiler)

- **Réaction rapide double-tap** : double-tap sur une bulle envoie un ❤️
  (`POST /api/chats/:conversationId/messages/:messageId/react`), retape pour
  retirer. Menu contextuel (appui long) propose aussi 6 emojis. Les
  réactions sont stockées sur le message (`reactions: [{userId, emoji}]`,
  un seul emoji par utilisateur) et diffusées en temps réel aux autres
  participants via le même circuit WebSocket que les messages
  (`messageEvent: "react"`), affichées sous forme de puces regroupées sous
  la bulle.
- **Épingler** : appui long → Épingler/Désépingler
  (`POST /.../messages/:messageId/pin`), badge visible sur la bulle,
  diffusé en temps réel (`messageEvent: "pin"`).
  `GET /api/chats/:conversationId/messages/pinned` liste les messages
  épinglés (pas encore de bandeau dédié dans l'UI — à ajouter si besoin).
- **Traduire** : appui long sur un message texte → traduction via Ollama
  (réutilise le modèle déjà configuré pour l'assistant IA, prompt dédié
  dans `config/ollama.ts::translateText`), affichée sous le message
  d'origine, avec option "Voir l'original". Traduction à la demande, non
  stockée.
- **Anti-spoiler (flouter)** : une image peut être envoyée en `spoiler:
  true` (champ sur le message), affichée floutée avec un bouton "Toucher
  pour révéler" — la révélation est locale à chaque destinataire (comme
  Telegram), pas persistée côté serveur. L'UI pour marquer une image comme
  spoiler au moment de l'envoi n'est pas encore branchée dans
  `chat_screen.dart` (le champ existe côté API et widget, il manque juste
  le bouton toggle dans le sélecteur de pièce jointe).

### Limites à connaître

- Pas de "Répondre" (citation d'un message précédent) ni de "Supprimer
  pour moi / pour tous" — mentionnés dans le prompt mais pas encore faits,
  prochain lot logique côté interactions message.
- Le menu de réactions est limité à 6 emojis fixes, pas de picker complet.
- La traduction dépend de la qualité du modèle Ollama local (`llama3.2:3b`
  par défaut) — pour des traductions fiables en production, un vrai
  service de traduction (DeepL, Google Translate API) serait préférable.

## Day 16 — Répondre à un message & suppression

- **Répondre** : appui long → Répondre affiche une barre d'aperçu
  au-dessus du champ de saisie (contenu tronqué + bouton annuler). Le
  message envoyé inclut `replyToId`, le backend copie un instantané
  (`replyTo: {messageId, senderId, content, type}`) sur le nouveau message
  au moment de l'envoi — pas de jointure à chaque lecture. La citation
  s'affiche au-dessus du contenu de la bulle, avec liseré coloré.
- **Supprimer pour moi** : `DELETE /api/chats/:conversationId/messages/:messageId`
  avec `{scope: "me"}` ajoute l'utilisateur à `deletedFor` sur le message
  (le document reste en base pour les autres participants).
  `listMessages` exclut désormais les messages où `deletedFor` contient
  l'utilisateur courant. Pas de diffusion temps réel nécessaire (n'affecte
  que soi-même).
- **Supprimer pour tout le monde** : même endpoint avec
  `{scope: "everyone"}`, réservé à l'auteur du message (403 sinon). Vide le
  contenu et pose `deletedForEveryone: true`, diffusé en temps réel
  (`messageEvent: "delete"`) — tous les participants voient la bulle
  remplacée par "Ce message a été supprimé".

### Limites à connaître

- La suppression "pour tout le monde" ne met pas à jour `lastMessage` sur
  la conversation si c'était le dernier message — l'aperçu dans la liste
  des conversations peut donc rester obsolète jusqu'au prochain message.
- Pas de délai limite pour la suppression "pour tout le monde" (contrairement
  à WhatsApp qui limite à ~1h) — à ajouter si souhaité.
- Répondre à un message qu'on vient tout juste d'envoyer soi-même (avant
  que l'écho WebSocket ne lui attribue un id) ne fonctionne pas encore —
  lié à la limitation déjà connue de duplication de message optimiste
  (voir Day 14).

## Day 17 — Messages vocaux : enregistrement, lecture, transcription, export

- **Enregistrement** : maintenir le bouton micro (visible quand le champ
  texte est vide, remplacé par l'icône d'envoi sinon) démarre
  l'enregistrement (`record` package, encodage AAC/.m4a). Glisser vers la
  gauche pendant l'enregistrement annule l'envoi ("Glisser pour annuler"),
  relâcher normalement envoie le vocal. Overlay avec chronomètre pendant
  l'enregistrement à la place de la barre de saisie.
- **Envoi** : réutilise l'upload générique déjà en place
  (`POST /api/uploads/chat-media`), puis un message de type `voice` avec
  `durationSeconds` stocké sur le message.
- **Lecture** : bouton play/pause avec barre de progression dans la bulle
  (`audioplayers`), affichage du temps restant.
- **Transcription** : appui long sur un vocal → Transcrire, appelle un
  service Whisper auto-hébergé (`onerahmet/openai-whisper-asr-webservice`,
  nouveau service `whisper` dans `docker-compose.yml`, lié en
  `127.0.0.1:9000` — ne consomme pas de port public supplémentaire, comme
  Postgres/Mongo/Redis/Ollama). Le backend lit le fichier audio directement
  depuis le dossier `uploads/` et l'envoie au service Whisper
  (`config/whisper.ts`), pas de stockage du texte transcrit.
- **Export** : appui long → Exporter l'audio ouvre l'URL du fichier dans
  le gestionnaire externe de l'appareil (`url_launcher`) — pas de
  transcodage en MP3 réel, le fichier reste dans son format
  d'enregistrement d'origine (.m4a/AAC).

### Limites à connaître

- **Pas de vrai export MP3.** Le point 75 du prompt demande un "bouton
  d'export MP3" ; l'implémentation actuelle exporte le fichier tel quel
  (AAC/.m4a, largement compatible mais pas littéralement du MP3). Un vrai
  transcodage nécessiterait ffmpeg côté serveur ou dans l'app — à ajouter
  si le format exact importe.
- Le service Whisper (modèle `base`) doit être démarré via
  `docker-compose up whisper` et ajouté à `.env` (`WHISPER_URL`) — comme
  Ollama, il tourne en local et n'est pas déployé automatiquement par
  `deploy.sh` pour l'instant (à vérifier/ajouter côté Day 13).
- Pas de limite de durée d'enregistrement ni d'indicateur visuel de niveau
  sonore (waveform) — le prompt mentionne une "onde sonore visuelle", pas
  encore faite (actuellement une simple barre de progression linéaire).
- La transcription n'est pas mise en cache : rappuyer sur "Transcrire"
  relance un appel au service Whisper à chaque fois.

## Day 18 — Auto-suppression des messages & code PIN

- **Messages éphémères** : icône horloge dans la barre du chat (remplace
  le menu 3 points quand actif, devient violette) → Off / 1 min / 1 h /
  1 jour / 1 semaine. Réglage stocké sur la conversation
  (`selfDestructSeconds`), diffusé en temps réel aux deux côtés
  (`messageEvent: "selfDestructChanged"`). Chaque nouveau message envoyé
  pendant que le réglage est actif reçoit un `expireAt` calculé au moment
  de l'envoi.
- **Suppression réelle** : index TTL MongoDB natif sur
  `Message.expireAt` (`expireAfterSeconds: 0`) — c'est MongoDB lui-même
  qui supprime le document quand `expireAt` est dépassé, pas un job
  applicatif. Le balayage TTL de MongoDB tourne toutes les ~60 secondes,
  donc la suppression réelle peut avoir jusqu'à une minute de retard sur
  l'heure affichée.
- **Affichage client** : badge horloge avec temps restant approximatif
  sur chaque bulle concernée, et minuteur local qui retire la bulle de la
  vue à l'instant exact de l'expiration (indépendant du balayage TTL
  serveur, purement pour le confort visuel).
- **Code PIN** : nouvelle section "Sécurité" dans l'écran profil. Code à
  6 chiffres, hashé (SHA256 + sel local) et stocké uniquement en local
  (`shared_preferences`), jamais envoyé au serveur. Verrouille l'app au
  premier lancement si un PIN est défini, et à chaque retour au premier
  plan (`WidgetsBindingObserver` sur `MainShell`). Écran dédié pour
  créer / changer (redemande l'ancien code) / désactiver le PIN.

### Limites à connaître

- **Pas d'empreinte digitale.** Le point 5 du prompt mentionne "Code
  d'accès PIN/Empreinte" — seul le PIN est fait. L'authentification
  biométrique nécessiterait le package `local_auth` et une configuration
  native (Face ID / Touch ID côté iOS, BiometricPrompt côté Android), pas
  encore ajoutée.
- **Pas de coffre-fort chiffré (Vault) ni de camouflage d'icône
  d'application** — mentionnés dans le même point du prompt (section 5,
  "Sécurité"), pas commencés.
- Le badge de compte à rebours sur les bulles ne se met à jour que
  lorsque le widget se re-rend pour une autre raison (nouvelle réaction,
  traduction...), pas en continu à la seconde près — pour éviter un
  timer par bulle qui tournerait en permanence. Le minuteur de
  suppression réelle, lui, est précis.
- Si l'app est fermée puis rouverte avant l'expiration TTL serveur, les
  messages expirés mais pas encore balayés par MongoDB peuvent
  brièvement réapparaître au prochain `listMessages` jusqu'au passage du
  TTL monitor.
- Le code PIN protège l'accès à l'app localement, mais ne chiffre pas
  les données stockées sur l'appareil (pas de chiffrement au repos) — à
  ne pas présenter comme une protection contre un accès physique avancé
  au téléphone.

## Day 19 — Multi-comptes

- **Sélecteur de compte** : avatar en haut à droite du header (nouvelle
  ligne logo + avatar ajoutée au-dessus de la barre de recherche sur
  l'écran d'accueil). Tap → feuille listant tous les comptes enregistrés
  localement sur l'appareil, avec coche sur le compte actif.
- **Ajouter un compte** : depuis la feuille, "Ajouter un autre compte"
  ouvre l'écran de connexion sans effacer les comptes déjà enregistrés ;
  une fois connecté, ce nouveau compte devient l'actif et rejoint la
  liste.
- **Changer de compte** : tap sur un compte inactif → bascule immédiate
  (`syrix_token` réécrit avec le token stocké de ce compte), redémarrage
  propre vers un nouveau `MainShell` (pile de navigation entièrement
  réinitialisée pour éviter d'empiler plusieurs sessions).
- **Retirer un compte** : bouton "x" sur un compte inactif dans la
  feuille — le retire juste de la liste locale, ne déconnecte rien côté
  serveur (pas de révocation de token, voir limites). Pour le compte
  actif, la déconnexion se fait toujours depuis Profil → Déconnexion,
  qui retire aussi ce compte de la liste multi-comptes.
- **Stockage** : tous les comptes (id, username, avatarUrl, token) sont
  gardés dans `shared_preferences` sous une seule clé JSON
  (`syrix_accounts`) — uniquement local à l'appareil, le backend n'a
  aucune notion de "comptes liés".
- **Bug corrigé au passage** : `CallService` (singleton WebSocket pour
  les appels entrants) ne se reconnectait jamais si un canal était déjà
  ouvert (`if (_channel != null) return;`), ce qui aurait fait rester
  l'ancien compte "écouté" pour les appels après un changement de
  compte. Un `disconnect()` explicite est maintenant appelé avant tout
  remplacement de `MainShell` (connexion, changement de compte,
  ajout de compte).

### Limites à connaître

- **Pas de session serveur multi-comptes.** Chaque "compte enregistré"
  n'est qu'un token JWT stocké localement. Si ce token expire
  (`JWT_EXPIRES_IN`, 7 jours par défaut) ou est révoqué côté serveur, le
  switch échouera silencieusement (retour à `/api/chats` en 401) — pas
  de re-authentification automatique ni de message d'erreur dédié pour
  ce cas précis pour l'instant.
- **Pas de vraie déconnexion à distance** quand on retire un compte
  inactif depuis la feuille : le token reste valide côté serveur tant
  qu'il n'a pas expiré, seule sa présence locale sur cet appareil est
  effacée.
- Aucun rafraîchissement automatique de l'avatar/pseudo affiché dans le
  sélecteur si l'utilisateur modifie son profil ailleurs — mis à jour
  uniquement à la prochaine connexion/changement de compte via ce
  compte.
- Le prompt mentionne aussi un scanner de QR code dans le header — pas
  fait, seul l'espace pour le logo et le sélecteur de compte a été
  ajouté.

## Day 20 — Auto-modération IA dans les groupes

- **Toggle "Auto-modération IA"** dans les paramètres du groupe/communauté
  (réservé au créateur, comme les autres réglages de groupe). Stocké sur
  la conversation (`aiModerationEnabled`), nouvel endpoint
  `PATCH /api/chats/:conversationId/moderation`.
- **Vérification à l'envoi** : quand activée, chaque message texte envoyé
  dans ce groupe/cette communauté est classifié par le modèle Ollama déjà
  utilisé pour l'assistant IA et la traduction
  (`config/ollama.ts::moderateText`) en une catégorie :
  `none` / `spam` / `nsfw` / `harassment`. Si le message n'est pas classé
  `none`, il est rejeté avant même d'être créé en base (HTTP 422,
  `{error: "message_blocked", category}`), donc jamais stocké ni diffusé
  aux autres membres. Le client affiche un message d'erreur adapté à la
  catégorie.
- **Fail-open assumé** : si l'appel à Ollama échoue (service down,
  timeout...), le message passe quand même — la modération ne doit pas
  transformer une panne d'infra en blocage total du chat. C'est un choix
  délibéré, pas un oubli.

### Limites à connaître

- **Texte uniquement.** Le point du prompt mentionne aussi la
  "détection de contenu NSFW" au sens large (images) — non faite : le
  modèle Ollama utilisé (`llama3.2:3b`) est un modèle texte, pas un
  modèle de vision. Détecter le NSFW sur les images nécessiterait soit un
  modèle multimodal (ex. `llava` via Ollama), soit un service de
  modération d'images dédié — à ajouter si besoin, sur le même schéma que
  Whisper (Day 17).
- **Pas de "Fermer le Groupe" ni de rôles admin (Promote/Demote/Kick/Ban).**
  Ces fonctionnalités du panneau d'administration de groupe (section 4 du
  prompt) nécessitent un vrai système de rôles par membre qui n'existe
  pas encore dans le modèle `Conversation` (seul `creatorId` existe, pas
  de liste d'admins) — actuellement seul le créateur a des droits de
  configuration. C'est le prochain gros morceau logique du prompt côté
  administration de groupe.
- Pas de historique/log des messages bloqués consultable par les admins
  — un message rejeté disparaît simplement, sans trace.
- La classification est approximative (modèle 3B généraliste, pas
  entraîné spécifiquement pour la modération) — des faux positifs/négatifs
  sont à prévoir, notamment sur des messages ambigus ou dans une langue
  peu représentée dans les données d'entraînement du modèle.

## Day 21 — Rôles & administration de groupe

- **Modèle de rôles** : `Conversation.adminIds` (liste d'admins promus) +
  `creatorId` (propriétaire, déjà existant). Un membre est donc
  `owner` / `admin` / `member`. Nouveau champ `bannedUserIds` pour les
  bannissements (empêche de rejoindre via le lien d'invitation).
- **Écran Membres** (`group_members_screen.dart`) : liste tous les
  participants avec badge de rôle. Pour les admins/propriétaire, tap sur
  un membre (qui n'est ni soi-même ni le propriétaire) ouvre le menu
  Promouvoir/Rétrograder + Retirer du groupe + Bannir.
- **Fermer le Groupe** : toggle dans les paramètres (visible par les
  admins et le propriétaire) — une fois activé, `sendMessage` rejette
  (403 `group_closed`) tout message texte/image/vocal venant d'un membre
  non-admin ; la barre de saisie est remplacée par un bandeau
  "Seuls les admins peuvent envoyer des messages" côté client.
- **Quitter le groupe** : nouveau bouton pour les non-propriétaires,
  confirmation puis retour à l'accueil. Le propriétaire ne peut pas
  quitter (doit d'abord transférer la propriété — pas encore possible,
  voir limites).
- **Kick / Ban en temps réel** : diffusion WebSocket
  (`messageEvent: "memberUpdate"`) à l'ancien participant retiré — son
  client affiche un message et le fait sortir automatiquement de l'écran
  de chat s'il y est encore.
- **Endpoints ajoutés** : `GET .../members`, `POST .../members/:id/promote`,
  `.../demote`, `.../kick`, `.../ban`, `POST .../leave`,
  `PATCH .../closed`. Toutes protégées par une vérification
  propriétaire-ou-admin (sauf lister les membres, ouvert à tout
  participant).
- **Petit nettoyage au passage** : une ligne de code mal formatée
  (héritage d'une édition précédente, `regenerateInviteLink`) a été
  remise en forme — pas un bug fonctionnel, juste de la lisibilité.

### Limites à connaître

- **Pas de transfert de propriété.** Le propriétaire d'un groupe ne peut
  ni être rétrogradé, ni quitter, ni être banni/kické. S'il veut partir,
  il n'y a actuellement aucun moyen de désigner un nouveau propriétaire
  à sa place — à ajouter si besoin (`transferOwnership`).
- **Pas d'historique de modération.** Qui a promu/rétrogradé/kické/banni
  qui, et quand, n'est pas journalisé — impossible d'auditer les actions
  d'administration après coup.
- Un membre banni peut toujours être ajouté manuellement à la
  conversation via `participantIds` par un autre chemin (ex. ajout
  direct côté admin, s'il existait) — le check `bannedUserIds` n'est
  appliqué qu'au moment de rejoindre via lien d'invitation
  (`joinByInviteCode`), pas ailleurs.
- Le badge de rôle dans la liste des membres ne se met pas à jour tout
  seul en temps réel après une promotion/rétrogradation faite par un
  autre admin en simultané — il faut rouvrir l'écran (`load()` est
  rappelé après chaque action locale, mais pas sur réception WS).

## Day 22 — Transfert de propriété de groupe

- **Nouveau bouton "Nommer propriétaire"** dans le menu d'un membre,
  visible uniquement par le propriétaire actuel (pas les simples admins),
  et seulement sur des membres qui ne sont pas déjà propriétaire.
  Confirmation obligatoire avant d'agir (dialogue avec avertissement).
- **Effet du transfert** : `creatorId` passe au nouveau propriétaire ;
  l'ancien propriétaire est automatiquement ajouté à `adminIds` (il ne
  perd pas tous ses droits, il redevient un admin normal comme n'importe
  quel autre). Diffusion temps réel (`messageEvent: "ownerTransferred"`)
  à tous les participants.
- **Débloque la sortie de l'ancien propriétaire** : comme documenté au
  Day 21, le propriétaire ne peut pas quitter le groupe directement — il
  doit d'abord transférer la propriété à quelqu'un d'autre, puis utiliser
  "Quitter le groupe" normalement une fois redevenu simple admin.
- Nouvel endpoint `POST /api/chats/:conversationId/transfer-ownership`.

### Limites à connaître

- Pas de possibilité de transférer à un membre qui n'est pas encore dans
  le groupe (le nouveau propriétaire doit déjà être participant).
- Pas d'étape "accepter le transfert" côté destinataire — c'est
  instantané et unilatéral, à l'initiative du seul propriétaire actuel.
  Un vrai système pourrait vouloir une confirmation du nouveau
  propriétaire avant que le transfert prenne effet.
- Toujours pas d'historique/audit des transferts de propriété (même
  limite que pour promote/demote/kick/ban notée au Day 21).

## Day 23 — Journal d'audit de modération

- **Nouveau modèle Mongo `AuditLog`** : chaque action d'administration
  (promote, demote, kick, ban, transfer_ownership, fermeture/réouverture
  du groupe, activation/désactivation de l'auto-modération IA) écrit une
  entrée avec l'auteur, la cible (si applicable) et l'horodatage.
  Écriture ajoutée à chacun des endpoints concernés (aucun endpoint
  existant n'a changé de comportement, juste une ligne de log en plus).
- **Écran "Journal d'audit"** (`group_audit_log_screen.dart`), accessible
  depuis les paramètres du groupe pour les admins et le propriétaire.
  Liste chronologique (plus récent en premier, 100 dernières entrées),
  phrase lisible par type d'action ("X a promu Y admin", "X a fermé le
  groupe"...) avec horodatage relatif (à l'instant / Xm / Xh / Xj).
- Nouvel endpoint `GET /api/chats/:conversationId/audit-log`, protégé
  (admin/propriétaire uniquement, comme les autres actions de gestion de
  groupe).

### Limites à connaître

- **Pas de pagination.** Limité aux 100 dernières entrées ; au-delà,
  les plus anciennes ne sont simplement plus visibles dans l'écran (elles
  restent en base, juste non affichées) — un vrai scroll infini /
  pagination serait nécessaire pour un historique complet sur des
  groupes très actifs.
- **Pas de log pour la suppression de messages "pour tout le monde"**
  (Day 16) ni pour le blocage d'un message par l'auto-modération
  (Day 20) — seules les actions d'administration au sens strict (sur les
  membres et les réglages du groupe) sont journalisées pour l'instant.
- Aucune purge automatique : les entrées `AuditLog` s'accumulent
  indéfiniment en base (contrairement aux messages qui ont un TTL
  optionnel depuis le Day 18) — à surveiller sur le long terme.
- Le journal n'est pas exportable (CSV, etc.) — consultation uniquement
  dans l'app.

## Day 24 — Panneau Développeur / BotFather

- **Créer un bot** : depuis Profil → Développeur → Bots → "+". Chaque bot
  est en réalité un compte `User` normal côté Postgres avec `isBot: true`
  (même mécanisme que le bot assistant IA existant), plus une ligne
  `DeveloperBot` qui associe ce compte à son propriétaire, son nom, un
  webhook optionnel, et le hash de son token.
- **Génération du token `SYRIX_BOT_...`** : token aléatoire (48 hex
  chars), affiché en clair une seule fois à la création (et à chaque
  régénération), jamais stocké en clair côté serveur — seul son hash
  SHA256 est conservé, comme pour les codes PIN (Day 18). Bouton copier
  dans le dialogue.
- **Auth par token dédiée** : nouveau middleware
  `requireBotToken` (`middleware/botAuth.ts`), distinct du JWT humain
  habituel — un bot s'authentifie avec
  `Authorization: Bearer SYRIX_BOT_...` sur `POST /api/bots/send` pour
  envoyer un message dans une conversation dont il est déjà participant
  (ajouté normalement comme membre, ex. via un groupe).
- **Configuration du Webhook** : URL modifiable depuis le panneau du bot.
  Quand un humain envoie un message dans une conversation contenant ce
  bot, `dispatchBotWebhooks` (`config/botWebhook.ts`) fait un `POST` vers
  cette URL avec `{conversationId, message}` — fire-and-forget, échoue
  silencieusement (log serveur uniquement) si l'URL du développeur ne
  répond pas, pour ne jamais bloquer l'envoi du message côté chat normal.
- **Gestion complète** : lister ses bots, changer le webhook, régénérer
  le token (invalide l'ancien immédiatement), supprimer l'accès API d'un
  bot (le compte `User` du bot reste intact pour préserver l'historique
  des messages déjà envoyés).
- Nouveau modèle Prisma `DeveloperBot` — nécessite `npx prisma db push`
  (déjà dans `setup.sh`) pour être appliqué en base.

### Limites à connaître

- **Le bot doit déjà être participant** d'une conversation pour pouvoir y
  écrire via `POST /api/bots/send` — il n'y a pas encore de mécanisme
  pour qu'un bot rejoigne un groupe lui-même (ex. via un lien
  d'invitation) ; c'est un humain qui doit l'ajouter comme n'importe quel
  autre participant lors de la création du groupe pour l'instant.
- **Pas de vérification de signature sur le webhook sortant** (pas de
  secret partagé / HMAC pour prouver que la requête vient bien de SYRIX)
  — un développeur ne peut pas encore garantir l'authenticité de l'appel
  entrant sur son serveur. À ajouter (ex. header `X-Syrix-Signature`)
  avant un usage en production.
- **Pas de retry en cas d'échec du webhook** — un seul essai, silencieux
  en cas d'échec (log uniquement). Pas de file d'attente ni de dead-letter.
- Le message envoyé par un bot via `POST /api/bots/send` est simplifié :
  pas de support spoiler/réponse-à/auto-suppression/durée vocale
  (uniquement `type` + `content`) — les bots ne bénéficient pas encore de
  toutes les fonctionnalités des messages humains.
- Pas de limite de débit (rate limit) sur `POST /api/bots/send` — un bot
  mal configuré pourrait spammer une conversation.

## Day 25 — Notes personnelles & dossiers de tchats

- **Notes personnelles** (`notes_screen.dart`) : accessible via une
  tuile "Notes enregistrées" épinglée en haut de la liste des
  conversations (icône marque-page). CRUD complet — créer, modifier,
  supprimer — stocké dans un nouveau modèle Mongo `Note` (`userId`,
  `content`, horodatages), privé à chaque utilisateur. Endpoints
  `GET/POST /api/notes`, `PATCH/DELETE /api/notes/:noteId`.
- **Dossiers de tchats** : ligne de chips horizontale ("Tout" + dossiers
  personnalisés + "+") sous la barre des Stories. Sélectionner un dossier
  filtre la liste des conversations à celles qu'il contient. Nouveau
  modèle Mongo `ChatFolder` (`userId`, `name`, `conversationIds`).
  Appui long sur un dossier → renommer/supprimer. Appui long sur une
  conversation → coche les dossiers dans lesquels l'ajouter/retirer
  (plusieurs dossiers possibles par conversation).
- Endpoints : `GET/POST /api/folders`, `PATCH/DELETE /api/folders/:folderId`,
  `POST/DELETE /api/folders/:folderId/conversations/:conversationId`.
- `ChatListItem` accepte désormais un `onLongPress` optionnel (petit ajout
  au widget partagé, rétrocompatible).

### Limites à connaître

- **Notes texte brut uniquement** — pas de pièces jointes, pas de
  formatage riche, pas de titre séparé (juste un bloc de texte, comme
  les "Messages enregistrés" de Telegram plutôt que des notes
  structurées).
- **Une conversation peut appartenir à plusieurs dossiers**, mais rien
  n'empêche d'en créer un nombre illimité — pas de limite façon
  "Free = 5 dossiers max" mentionnée dans le prompt pour les Stories
  (point analogue non appliqué ici, à ajouter si une distinction
  Free/VIP doit aussi couvrir les dossiers).
- Le filtrage par dossier est fait côté client (sur la liste déjà
  chargée) — pas un vrai filtre serveur ; sans impact perceptible tant
  que le nombre de conversations reste raisonnable, mais à revoir si la
  liste devient très grande.
- Pas de réordonnancement des dossiers (toujours dans l'ordre de
  création) ni d'icône/couleur personnalisée par dossier.

## Day 26 — Gamification : XP, niveaux, badges de contributeurs

- **Gain d'XP** : chaque message envoyé dans un groupe ou une communauté
  rapporte 10 XP à son auteur (`config/gamification.ts::XP_PER_MESSAGE`),
  avec un cooldown de 30 secondes entre deux gains pour éviter le
  farming par spam. Stocké dans un nouveau modèle Mongo `MemberStats`
  (`conversationId`, `userId`, `xp`, index unique composé).
- **Niveaux** : formule simple, 100 XP = 1 niveau (`levelFromXp`). Pas de
  courbe progressive pour l'instant — chaque niveau coûte le même
  montant d'XP.
- **Badges de contributeur** : 4 paliers (`Nouveau membre` → niveau 1,
  `Contributeur` → niveau 5, `Contributeur actif` → niveau 10, `Pilier
  du groupe` → niveau 20), calculés côté serveur pour rester la seule
  source de vérité (`badgeForLevel`), jamais recalculés côté client.
- **Écran Classement** (`group_leaderboard_screen.dart`), accessible
  depuis les paramètres du groupe pour tous les membres (pas réservé aux
  admins) : classement par XP décroissant, médailles pour le top 3,
  barre de progression vers le niveau suivant.
- **Niveau visible dans la liste des Membres** (Day 21) : chaque membre
  affiche désormais son niveau à côté de son rôle.
- Nouvel endpoint `GET /api/chats/:conversationId/leaderboard` ; `GET
  .../members` (Day 21) retourne aussi `xp`/`level`/`badge` par membre
  maintenant.

### Limites à connaître

- **Pas de gamification pour les DM privés** — uniquement groupes et
  communautés, comme l'auto-modération IA (Day 20) et "Fermer le
  Groupe" (Day 21) ; cohérent avec le fait que l'XP récompense la
  participation à une communauté, pas les échanges privés.
- **Aucune récompense au-delà du badge affiché** — pas de crédits
  wallet, pas de déblocage de fonctionnalité liée au niveau. Purement
  cosmétique/statut pour l'instant.
- **Le cooldown anti-farming est simpliste** (30s entre deux gains, peu
  importe le contenu du message) — n'empêche pas un utilisateur motivé
  d'envoyer un message toutes les 30 secondes pendant des heures pour
  monter de niveau artificiellement.
- Pas de remise à zéro périodique (classement "du mois") — l'XP
  s'accumule indéfiniment depuis la création du groupe.
- Les niveaux/XP ne sont pas recalculés si un ancien message est
  supprimé — supprimer ses propres messages ne fait pas perdre l'XP déjà
  gagné.

## Day 27 — Scanner QR & QR code d'invitation

- **Scanner de QR code dans le header** (limite ouverte depuis le
  Day 19, maintenant comblée) : icône dans l'en-tête de l'écran d'accueil,
  ouvre la caméra (`mobile_scanner`), détecte un QR contenant un lien ou
  code d'invitation, rejoint automatiquement le groupe/la communauté et
  ouvre le chat.
- **Scanner accessible aussi depuis "Rejoindre par lien"** (onglet
  Explorer) — un bouton dédié en plus du champ texte existant, même
  logique d'extraction de code partagée (`utils/invite_code.dart`,
  petit refactor pour éviter la duplication entre les deux points
  d'entrée).
- **QR code affiché côté groupe** : dans les paramètres du groupe, un
  nouveau bouton à côté du lien d'invitation ouvre une pop-up avec le QR
  code correspondant (`qr_flutter`), scannable directement par un autre
  appareil.
- Le format encodé est le code d'invitation brut (même valeur que celle
  copiée par le bouton "copier"), pas une URL complète — cohérent avec
  ce qui existait déjà avant ce jour.

### Limites à connaître

- **Pas de QR code de profil personnel** — le prompt mentionne aussi un
  "QR Code de profil personnel" (section 5, Sécurité & Confidentialité)
  pour partager/ajouter un contact par QR ; seul le QR d'invitation de
  groupe a été fait aujourd'hui. Le scanner du header ne reconnaît donc
  que des codes d'invitation, pas des profils utilisateur.
- Aucune gestion d'erreur spécifique si la caméra n'est pas disponible
  ou si la permission est refusée au-delà de ce que `mobile_scanner`
  gère nativement — pas de message d'erreur personnalisé dans l'app pour
  ce cas.
- Le scan ne distingue pas un QR SYRIX valide d'un QR quelconque avant
  d'essayer de rejoindre — un QR non reconnu déclenche simplement
  l'erreur générique "lien d'invitation invalide" du serveur.

## Day 28 — QR code de profil personnel

- **QR code sur son propre profil** : bouton "Mon QR code" à côté de
  "Modifier le profil". Encode `syrixuser:<userId>` (préfixe distinct du
  QR d'invitation de groupe, qui reste un code brut sans préfixe — les
  deux formats coexistent sans ambiguïté).
- **Scan reconnaît maintenant deux types de QR** : le scanner du header
  (Day 27) et celui de l'écran "Rejoindre par lien" détectent le préfixe
  `syrixuser:` et redirigent vers un nouvel écran de profil au lieu
  d'essayer de rejoindre un groupe. Logique de détection centralisée
  dans `utils/invite_code.dart` (`isProfileQrCode`,
  `extractUserIdFromProfileQr`), réutilisée aux deux points d'entrée.
- **Nouvel écran `UserProfileScreen`** : affiche avatar/pseudo/bio d'un
  utilisateur scanné (réutilise l'endpoint déjà existant
  `GET /api/users/:userId/profile`, jusqu'ici jamais branché côté
  mobile), avec deux actions — "Message" (démarre un DM) et "Ajouter"
  (ajoute aux contacts, même logique que le bouton déjà présent dans
  `chat_screen.dart`).

### Limites à connaître

- **`UserProfileScreen` n'est accessible que par scan QR pour l'instant**
  — pas encore de moyen de l'ouvrir en tapant sur un nom d'utilisateur
  ailleurs dans l'app (résultats de recherche, listes de membres...).
  L'endpoint et l'écran existent, il manque juste les points d'entrée
  additionnels ailleurs dans l'UI.
- Respecte `profileVisibility` déjà en place côté serveur (si le profil
  scanné n'est pas public et que le scanneur n'est pas dans ses contacts,
  seules les infos minimales — pseudo, avatar — sont renvoyées) mais rien
  n'empêche techniquement de scanner le QR de n'importe qui si on a son
  ID, même sans l'avoir rencontré — comportement attendu pour un QR
  destiné à être partagé publiquement.
- Pas de QR "à durée limitée" ou révocable — le QR de profil encode
  directement l'ID utilisateur permanent, il ne peut pas être invalidé
  comme un lien d'invitation de groupe (qui peut être régénéré).

## Roadmap (au-delà de ce projet)

Le plan initial est maintenant couvert de bout en bout : auth (avec
vérification d'âge), chat temps réel, stories, live vidéo réel, wallet
Stripe, profil, admin, déploiement, assistant IA local, pages légales,
dossier de soumission stores, contacts, confidentialité du profil, DM et
groupes payants. Ce qui reste dépend de décisions produit au-delà de ce
qu'on peut préparer à l'avance :
- durcissement production de LiveKit (TURN, pare-feu, rotation des clés —
  voir la section Day 9)
- modération de contenu (texte et/ou image), si le volume d'utilisateurs
  le justifie
- automatiser la suppression de compte (actuellement : demande par email)
- annuaire de groupes publics, si tu veux exploiter le champ `isPrivate`
  au-delà de l'affichage
- confirmation avant l'envoi d'un message payant
