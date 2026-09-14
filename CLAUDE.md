# SYRIX CHAT — Contexte projet pour IA

Ce fichier est la source de vérité pour toute IA (Claude ou autre) qui reprend ce
projet. Il remplace les prompts bruts envoyés précédemment — lis-le en entier
avant de toucher au code. Mets-le à jour à la fin de chaque session de travail.

## 0. Ce que le porteur de projet a répété plusieurs fois, donc non négociable

- **Les fichiers ne suffisent pas.** Le projet a une longue histoire de code
  généré mais jamais vraiment relié à l'UI, ou relié mais jamais testé sur un
  vrai appareil connecté à un vrai serveur. Avant de déclarer une fonctionnalité
  "faite", vérifie qu'elle est : (1) codée backend, (2) codée mobile, (3)
  appelée depuis un écran réellement atteignable par l'utilisateur, (4) que
  l'URL/le endpoint utilisé est correct.
- **Ne jamais re-hardcoder une URL localhost dans `api_client.dart`.** Voir
  section 1 — c'est la cause du bug le plus coûteux du projet à ce jour.
- Travailler **jour par jour** : une session = un lot de fonctionnalités
  cohérent, documenté en bas de ce fichier, pas un big-bang.
- **Avant de marquer quoi que ce soit ❌ dans ce fichier, `grep` le code
  d'abord.** Quatre éléments ont été listés à tort comme non codés au fil
  des sessions (double-tap réaction, BotFather, auto-modération IA/rôles
  XP) alors qu'ils existaient déjà — corrigés le 10/09 après coup. Un faux
  ❌ fait perdre une session entière à refaire ce qui marche déjà.
- **Depuis le 10/09 (Day 9) : ne mettre à jour que le bloc anglais (`en`) de
  `apps/mobile/lib/i18n/strings.dart`.** Le porteur de projet traduit
  lui-même en français à partir des clés anglaises pour économiser les
  tokens. Ne pas ajouter d'entrées FR sauf demande explicite contraire.
- Le porteur de projet n'est pas développeur — les explications doivent rester
  concrètes (quel fichier, quel écran, quel bouton), pas seulement conceptuelles.

## 1. Piège d'infrastructure déjà tombé une fois — ne pas répéter

`apps/mobile/lib/services/api_client.dart` doit **toujours** lire son URL via
`String.fromEnvironment("API_BASE_URL", defaultValue: "http://localhost:4000/api")`
(idem pour `WS_URL`), jamais une chaîne en dur. L'APK est buildé avec
`scripts/build_release.sh`, qui lit `apps/mobile/.env.build` (copié depuis
`.env.build.example`, ignoré par git) et injecte `--dart-define=API_BASE_URL=...`
automatiquement. **Si `.env.build` n'existe pas ou pointe vers `localhost`,
l'APK compile sans erreur mais absolument aucun appel réseau ne fonctionnera
sur un vrai téléphone** — c'est indétectable à la lecture du code, seulement
au runtime sur appareil réel. C'est la cause racine de la quasi-totalité des
"fonctionnalités qui existent dans les fichiers mais pas dans l'APK" reportées
le 10/09.

Autres pièges déjà rencontrés :
- **`/auth/me` doit toujours être mis à jour quand un nouveau champ `User`
  est ajouté au profil.** Trouvé le 10/09 : `profileVisibility` et
  `dmPrice` étaient lus côté mobile (`body["profileVisibility"]`) sans
  jamais être présents dans la réponse réelle de `/auth/me` — bug silencieux
  qui remettait ces réglages à leur valeur par défaut à chaque rechargement.
  Avant d'ajouter un champ à `updateProfile`/`getUserProfile`, vérifier
  aussi `me()` dans `authController.ts`.
- **Toujours `grep` le nom d'une méthode avant de l'ajouter à
  `api_client.dart`** (ou tout fichier long) : un doublon de méthode a été
  introduit par erreur au Day 6 (`listContacts()` définie deux fois),
  découvert et corrigé au Day 14 seulement. Un doublon empêche la
  compilation Dart.
- `gallery_saver_plus` fige `compileSdkVersion` à 31 dans son propre
  `build.gradle`, incompatible avec livekit/webrtc/mobile_scanner (besoin de
  34+). Corrigé par `scripts/patch_known_issues.sh`, appelé automatiquement par
  `build_release.sh`. Si on ajoute d'autres packages Android tiers, vérifier
  leur `compileSdkVersion`.
- Le port API par défaut est **3000** (pas 4000) sur le VPS de prod actuel —
  `PORT=3000` dans `.env`. Vérifier avant de supposer 4000.
- **Même piège avec `LIVEKIT_URL`** (défaut `ws://localhost:7880`) : cause
  exacte du bug "Could not connect to the live stream". Voir section 4.4.
- Sans `GMAIL_USER`/`GMAIL_APP_PASSWORD` configurés, le code OTP d'inscription
  s'affiche juste dans les logs serveur (`console.log`) — pratique pour tester,
  mais ne pas oublier de configurer Gmail avant un vrai lancement public.

## 2. Identité du produit (non négociable, déjà codé et protégé par un filtre)

- Nom : **SYRIX CHAT**, assistant IA embarqué : **Syrix Assistant**.
- Développé par **SYRIX VISION COMPANY**. Toute mention de Meta/OpenAI/Google/
  Anthropic comme créateur est bloquée par le system prompt ET un filtre
  post-génération (`apps/api/src/config/ollama.ts`).
- CEO & co-fondateur : **INCONNU BOY SENSEI** (nom réel Dawens). Co-fondateur :
  **Dsprimis** (nom réel Fritz).
- Signature en pied de page : "Made in by Syrix Vision" déjà présente dans
  `SyrixLogo` (splash/login/signup) — pas besoin de l'ajouter ailleurs sauf
  demande explicite pour l'écran Paramètres.

## 3. Identité visuelle cible

L'app utilise maintenant une palette **violette/dégradé** (`SyrixColors` dans
`apps/mobile/lib/theme/app_theme.dart`, `primary` = `#6C5CE7`, `cyan` =
`#00E5FF`, `background` = `#13111C`, `surface` = `#1E1B2E`) — corrigé le
10/09. Comme presque tout l'UI référence `SyrixColors.primary` plutôt que des
couleurs en dur, ce changement s'est propagé automatiquement à la quasi-
totalité de l'app (boutons, badges, story ring, bottom nav). Fait
explicitement en plus le 10/09 : écran de connexion (fond dégradé plein
écran, carte à bordure lumineuse violette, bouton "Sign In" en dégradé
violet→cyan), barre de navigation du bas avec labels texte sous les 5 icônes.

- Palette **violette/dégradé** — violet néon `#6C5CE7` déjà utilisé pour le
  badge vérifié, à étendre à tout l'accent color (boutons, nav, story rings).
  Cyan néon `#00E5FF` pour les liens dans les bulles de message.
- Logo : bulle de chat en forme de "S" stylisé, dégradé violet.
- Écran de connexion : dégradé violet plein écran, logo centré, champs
  Email/Password arrondis avec glow violet, bouton "Sign In" en dégradé,
  boutons de connexion sociale (Google/Apple/Facebook) ronds sous le bouton
  principal.
- Liste de discussions : story bar en haut avec anneaux colorés autour des
  avatars — **fait le 10/09**, convention retenue : dégradé violet→cyan
  néon = story non vue, gris uni = toutes les stories du groupe vues
  (convention standard Instagram/WhatsApp ; à confirmer avec le porteur de
  projet si une autre logique était voulue). Bouton
  flottant "+" en bas au centre, barre de navigation du bas avec fond en
  dégradé et labels texte sous chaque icône (Chats/Calls/Groups/People/
  Settings — **5 onglets avec labels**, pas juste des icônes nues comme
  actuellement).
- Fond des bulles de message : `#1E1B2E` pour les reçus, dégradé violet/cyan
  pour les envoyés (actuellement bleu plat).
- Fond général de l'écran de chat : `#13111C`.

Ce reskin est un gros chantier transverse (quasi tous les écrans). Ne pas le
faire en un seul big-bang — un écran/composant à la fois, dans l'ordre du
planning ci-dessous.

## 4. Inventaire des fonctionnalités — statut réel au 10/09

Légende : ✅ fait et branché · ⚠️ codé partiellement / pas branché correctement
· ❌ pas codé du tout.

### 4.1 Auth & Onboarding
- ✅ Signup email/password → OTP → vérification → choix de username unique
  avec suggestions temps réel (debounce 300ms) — `UsernameSelectionScreen`.
- ✅ Changement de username plus tard depuis le profil.
- ✅ Persistance de session (corrigée le 10/09) : `splash_screen.dart` vérifie
  maintenant le token stocké au démarrage au lieu de forcer `LoginScreen`
  systématiquement.
- ✅ Mode hors-ligne basique (fait le 10/09) : cache local (`OfflineCache`)
  pour la liste de discussions et les messages du dernier chat ouvert,
  bannière "offline_banner". Bonus : correction d'un bug où une coupure
  réseau faisait tourner le spinner à l'infini (pas de `try/catch` sur les
  appels réseau de `loadData()`/`init()`). Pas caché : stories, dossiers,
  profils visités.

### 4.2 Profil & Premium/VIP
- ✅ Badge vérifié (`VerifiedBadge`/`UsernameWithBadge`) branché sur : bulles
  de message en groupe, en-tête de chat privé, profil (soi + autrui), liste
  de membres, recherche globale, liste de discussions, stories.
- ✅ Bannière de profil, localisation en bio, liens riches auto-détectés
  (YouTube/Instagram/X/GitHub/TikTok/Facebook/LinkedIn), réservés Premium.
- ✅ Visite du profil d'un autre utilisateur (`user_profile_screen.dart`) —
  le porteur de projet pensait que ça manquait le 10/09, **à vérifier avec
  lui si le point d'entrée (clic sur avatar/nom) est bien visible dans
  l'APK qu'il a testé**, car le code existe.
- ✅ QR code de profil (`My QR code`, modal avec image QR).
- ✅ **Partage du QR en lien cliquable** (fait le 10/09) : `GET /u/<username>`
  côté serveur (page HTML minimale) + bouton "Copier le lien" sur le profil.
- ✅ Activation Premium via Stripe (fait le 10/09) : paiement unique
  30 jours, pas un abonnement récurrent géré automatiquement (pas de
  renouvellement/annulation auto, pas de job d'expiration). Le toggle admin
  reste utile pour du support manuel.
- ✅ Auto-suggestion de ville/pays pendant la saisie (fait le 10/09, via
  l'API publique Nominatim/OpenStreetMap, aucune clé requise).
- ✅ Suggestion d'amis du même pays/ville (fait le 10/09) : `GET /users/nearby`
  + section dans `explorer_screen.dart`. Matching = égalité stricte sur
  `location`, pas de rayon géographique réel (pas de lat/lng stockées).

### 4.3 Groupes & Communautés
- ✅ Communautés = vraies conteneurs de groupes (corrigé le 10/09) :
  `Conversation.communityId` relie un groupe à sa communauté parente ;
  `CommunityScreen` liste les groupes d'une communauté + bouton de création
  de groupe scopé ; les groupes rattachés n'apparaissent plus dans la liste
  plate des discussions (seulement via leur communauté) ; icône différenciée
  groupe/communauté/privé dans `ChatListItem`.
- ✅ Panel admin de groupe, promote/demote/kick/ban, fermeture de groupe,
  transfert de propriétaire.
- ✅ Modifier les infos du groupe (nom) : icône crayon ajoutée le 10/09,
  affichage lecture seule → bascule en champ éditable au clic (au lieu d'un
  TextField toujours actif). Description/photo de groupe pas encore couvertes
  par ce pattern.
- ✅ Auto-modération IA (anti-spam/NSFW via `moderateText`, toggle
  `aiModerationEnabled` bloquant les messages) et Fermer le Groupe
  (`closedGroup`) — déjà entièrement codés (`group_settings_screen.dart`),
  listés à tort comme ❌. Rôles par XP / gamification aussi déjà codés
  (`MemberStats`, `config/gamification.ts`, `group_leaderboard_screen.dart`)
  — même erreur d'audit corrigée le 10/09.

### 4.4 Chat, Stories, Live
- ✅ Republier/télécharger une story (Premium), badge sur le posteur.
- ✅ Filtres de messages (Tout/Non lus/Lus/Groupes/Communautés) sous la barre
  de recherche (fait le 10/09). Filtre "reply status" pas fait.
- ✅ Navigation avancée par @tags dans les groupes (fait le 10/09) : barre
  flottante Précédent/Suivant + compteur, saute entre les messages
  mentionnant le même tag sans perdre le fil.
- ✅ Renommage personnalisé de contact (fait le 10/09) : nouvel écran
  `ContactsScreen` (accessible depuis le profil, section au-dessus de
  Développeur) — n'existait pas du tout avant.
- ✅ Édition de message avec mention "Édité" + horodatage (fait le 10/09).
- ✅ Message d'absence automatique + réponses rapides `/` (fait le 10/09,
  section Outils Business). Catalogue de produits fait le 10/09
  (`CatalogScreen`, grille avec image/nom/prix). Étiquetage clients fait le
  10/09 aussi (badges colorés Prospect/VIP/Order in progress sur
  `ContactsScreen`) — section 7 complète.
- ✅ Archivage de discussion (fait le 10/09) : swipe gauche dans la liste,
  écran `ArchivedChatsScreen` pour désarchiver.
- ✅ Contrôle parental (fait le 10/09) : PIN 4 chiffres distinct du PIN
  d'app, verrouille l'onglet Live. Pas encore fait : verrouiller aussi
  canaux publics et paramètres de paiement.
- ⚠️ Filtres AR (visage/masques), éditeur vidéo avant envoi, animations 3D
  de cadeaux en live, crowdfunding en live — toujours pas faits (gros
  chantiers médias/natifs). **Nuance** : des filtres couleur simples pour
  les stories (N&B/Vivid/Retro, `ColorFilter.matrix`) sont faits depuis le
  10/09 — ce n'est pas de l'AR (pas de détection de visage/masques 3D),
  juste un traitement colorimétrique de l'image entière.
- ✅ Recherche dans une conversation (fait le 10/09) : côté client seulement,
  limitée aux 200 derniers messages chargés (limite de `listMessages`).
- ✅ Mentions @username cliquables et liens surlignés cyan néon dans les
  bulles (fait le 10/09) — ouvrent la navigation par tags (voir ci-dessus),
  pas encore la carte de profil directement (ambiguïté entre les deux
  comportements décrits dans le prompt original, tag-navigation choisi en
  priorité car c'était le sujet du jour).
- ✅ Double-tap réaction rapide (existait déjà, animation néon ajoutée le
  10/09). Fancy Text fait le 10/09 aussi (`*gras*`/`_italique_`/`~barré~`/
  `` `code` `` rendus dans les bulles). Transcription vocale (Whisper) était
  déjà codée (`transcribeMessage`), listée à tort comme ❌ — corrigé le
  10/09. Téléchargement du fichier vocal ajouté le 10/09 (ouverture externe,
  pas de transcodage MP3 réel). Import de stickers Telegram toujours pas
  codé.
- ✅ **Cause du bug Live trouvée** (10/09) : même piège que la section 1 —
  `LIVEKIT_URL` vaut `ws://localhost:7880` par défaut (`.env.example`,
  `liveController.ts`, `callController.ts`). Si ce n'est pas changé dans le
  `.env` réel du VPS, le téléphone reçoit "localhost" et essaie de se
  connecter à lui-même → "Could not connect to the live stream" à chaque
  fois. **Fix à appliquer sur le VPS (pas dans le code)** :
  1. `docker compose up -d livekit` (le conteneur n'a probablement jamais
     été démarré — je l'avais explicitement fait sauter dans une
     instruction de déploiement précédente).
  2. Dans `apps/api/.env` : `LIVEKIT_URL=ws://<IP ou domaine du VPS>:7880`.
  3. Redémarrer l'API (`systemctl restart syrix-api` ou relancer
     `node dist/server.js`).
  Ajouté le 10/09 : un avertissement au démarrage du serveur
  (`console.warn`) si `LIVEKIT_URL` est absent ou contient "localhost", pour
  que ce piège ne passe plus jamais inaperçu dans les logs.
- ✅ Notifications réelles (fait le 10/09) : mentions @username et ajout de
  contact. Pas encore couverts : cadeaux/réactions en tant que déclencheurs
  (le modèle les supporte, mais rien n'appelle encore `createNotification`
  pour ces deux types).

### 4.5 Paramètres
- ✅ Langue FR/EN, PIN, Bots (liste vide, pas de création de bot encore),
  wallet (solde, écran dédié).
- ✅ Appareils Connectés / Sessions (fait le 10/09) : IP + type d'appareil +
  date, déconnexion à distance fonctionnelle (révocation réelle, pas
  cosmétique). Pas de géolocalisation par pays.
- ✅ Confidentialité fine — date de naissance et stories (fait le 10/09).
- ⚠️ Coffre-fort fait le 10/09 mais **pas un vrai chiffrement** — juste un
  index local protégé par PIN (voir journal). Camouflage d'icône d'app —
  toujours pas fait (nécessite du code natif Android non vérifiable ici).
- ⚠️ Personnalisation : économie d'énergie faite le 10/09 (réduit les
  animations). Couleur d'accent/éditeur de bulles/mode OLED toujours
  bloqués par le problème des 461 `const SyrixColors` (voir Day 26).
- ✅ BotFather (création de bot, génération de token, config webhook) —
  était déjà entièrement codé (`developer_bots_screen.dart`), je l'avais
  listé à tort comme ❌. Corrigé dans l'audit du 10/09.
- ✅ L'IA "Syrix Assistant" a sa propre conversation créée automatiquement à
  l'inscription et **toujours épinglée en tête de liste** (fait le 10/09).
  Transfert de message vers un autre chat aussi ajouté le 10/09
  (menu contextuel > Transférer). Pas fait : écran IA véritablement distinct
  avec génération d'images/résumés (pas d'infra de génération d'image
  configurée) — l'IA reste un contact de chat classique, juste épinglé.

## 5. Prompts sources (archivés, ne pas re-suivre mot à mot)

Deux documents ont été fournis comme spec originale :
1. Un doc "architecture visuelle" (9 sections numérotées : structure nav,
   chat_screen.dart, stories/lives, group_settings_screen.dart,
   settings_screen.dart, syrix_ai_screen.dart) — décrit un produit à la
   fois WhatsApp + Telegram + TikTok Live + Stripe + plateforme de bots.
   C'est une vision produit complète, pas un scope réaliste pour une seule
   session. À traiter comme backlog priorisé, pas comme check-list à
   cocher d'un coup.
2. Un doc "9 fonctionnalités" détaillé (username, identité IA, Premium,
   badge, filtres/@tags, profil/contact, outils business, sécurité,
   appels/AR/lives) — largement traité section 4 ci-dessus.

**Ne pas redemander ces prompts au porteur de projet** — leur contenu est
digéré dans la section 4. S'y référer seulement si une ambiguïté précise
n'est pas couverte ici.

## 6. Journal de session (day-by-day)

Ajouter une entrée courte à chaque session, la plus récente en haut.

- **10/09 (32)** : Cadeaux + crowdfunding en Live — dernier morceau de la section 9. `LiveSession.giftTotal`, `POST /live/:liveId/gift` (réutilise le catalogue de cadeaux existant `GIFT_CATALOG` + le débit/crédit wallet déjà en place pour les cadeaux en chat privé). `showGiftSheet` généralisé avec un paramètre `sendOverride` pour être réutilisable en live sans dupliquer le widget. Jauge de cadeaux affichée dans l'en-tête du live, bouton cadeau à côté du bouton réaction. **Pas fait** : les vraies animations 3D haute définition des gros cadeaux (juste l'icône classique du catalogue existant, pas de rendu 3D) — hors de portée sans moteur de rendu 3D vérifiable dans cet environnement. Avec ça, **toutes les fonctionnalités raisonnablement faisables des deux prompts d'origine sont couvertes**. Il ne reste que : (1) vraies animations 3D/filtres AR par détection de visage — nécessite des bibliothèques natives non vérifiables ici, (2) couleur d'accent dynamique/OLED/éditeur de bulles — bloqué par les 461 `const SyrixColors` (nécessite un accès compilateur réel pour être fait sans risque).
- **10/09 (31)** : Partage QR/lien d'un Live. Page publique `GET /live/:liveId` (même pattern que `/u/:username` du Day 4), bouton QR dans l'en-tête de `live_room_screen.dart` avec modal QR + copier le lien. Il ne reste plus que les cadeaux 3D et le crowdfunding en live dans la section 9 du prompt original — les deux nécessitent une vraie infra de paiement/animation lourde, non prioritaires.
- **10/09 (30)** : Tchat en direct + réaction rapide pendant un Live — `live_room_screen.dart` n'avait aucune interactivité (juste la vidéo). Nouveau modèle `LiveChatMessage` + `GET/POST /live/:liveId/chat` (polling toutes les 3s côté mobile plutôt que le canal de données LiveKit — je n'ai pas pu vérifier la signature exacte de l'API `publishData` de `livekit_client` sans accès au code source du package dans cet environnement, le polling HTTP est moins élégant mais fiable et déjà éprouvé sur d'autres fonctionnalités). Bouton cœur (réaction rapide, compteur global partagé, en mémoire serveur donc remis à zéro au redémarrage — pas persisté en base). Overlay tchat en bas à gauche, bouton réaction en bas à droite, conforme à la disposition du prompt original. Pas fait : cadeaux 3D, crowdfunding, partage QR/lien du live.
- **10/09 (29)** : Filtres couleur réels pour les stories — jusque-là la maquette montrait une rangée de filtres (Original/Cinematic/Retro/Vivid/B&W...) qui n'existait nulle part dans le code (`create_story_screen.dart` se contentait de choisir une image galerie + légende). Ajouté : capture caméra en plus de la galerie, 3 filtres réels (N&B, Vivid, Retro) via `ColorFilter.matrix` (pur Flutter, aucune dépendance externe), et surtout **le filtre est réellement appliqué au fichier publié** (capture du rendu filtré via `RenderRepaintBoundary.toImage()` avant upload, pas juste un aperçu cosmétique). Limite : 3 filtres seulement (pas les 7 de la maquette), pas de musique ni de texte superposé sur la story (la légende texte existait déjà, en dessous, pas incrustée sur l'image).
- **10/09 (28)** : Tranche sûre de Personnalisation — Économie d'énergie (`PersonalizationService`, toggle dans un nouvel écran `PersonalizationScreen` sous Profil > Paramètres). Contrairement à la couleur d'accent/OLED (bloquées par le problème des 461 `const SyrixColors`, voir Day 26), ce toggle ne touche aucune couleur — il désactive juste l'animation cœur néon du double-tap en conditionnant un simple `if` runtime, donc zéro risque de casser la compilation. Couleur d'accent dynamique et éditeur de bulles restent non faits, pour la même raison que précédemment.
- **10/09 (27)** : Photo et description de groupe — gap trouvé en vérifiant le reste du backlog (`Conversation.avatarUrl`/`description` n'existaient pas du tout). Avatar cliquable en haut de `group_settings_screen.dart` (upload réservé au créateur, `POST /chats/:id/photo`), champ description, les deux sauvegardés via `updateConversationSettings` étendu. Bonus automatique : `listConversations` utilisait toujours `avatarUrl: null` pour les groupes — maintenant que le champ existe, la liste de discussions affichera la vraie photo de groupe sans changement supplémentaire côté `ChatListItem` (il l'acceptait déjà en paramètre).
- **10/09 (26)** : Anneaux de story différenciés vu/pas-vu (dégradé violet→cyan néon si non vue, gris uni si toutes les stories du groupe ont été vues par l'utilisateur courant) — dernier point visuel du reskin Day 8 resté en suspens. Nécessitait de faire remonter `currentUserId` jusqu'à `StoryBar` (ajouté à `loadCurrentUser()` dans `home_chats_screen.dart`). **Vérification faite avant de choisir la tâche du jour** : recomptage du backlog ❌ restant — il ne reste que deux éléments non triviaux : (1) Filtres AR/éditeur vidéo/animations 3D de cadeaux live (médias lourds, hors de portée sans pouvoir tester le rendu caméra/vidéo réel), (2) Personnalisation (couleur d'accent dynamique/OLED/éditeur de bulles) — **volontairement reportée** : `SyrixColors.primary` etc. sont utilisés dans 461 endroits avec le mot-clé `const` à travers le projet ; les rendre modifiables à l'exécution casserait la compilation Dart à ces 461 endroits (un `const` ne peut pas référencer une valeur non-constante). Faisable proprement seulement avec un accès compilateur réel (`flutter analyze`) pour repérer et corriger chaque cassure — pas prudent à faire à l'aveugle dans cet environnement sans compilation.
- **10/09 (25)** : Coffre-fort (Vault) — PIN dédié à 4 chiffres (distinct des PIN app-lock et parental), option "Save to Vault" sur les messages image (menu contextuel), galerie protégée par PIN (`VaultScreen`), accessible depuis Profil > Sécurité. **Important — à corriger le vocabulaire avec le porteur de projet** : ce n'est **pas un vrai chiffrement du contenu**, seulement un index local (SharedPreferences) des URLs d'images sauvegardées, protégé par un PIN. Je n'ai pas de bibliothèque de chiffrement vérifiée disponible dans cet environnement sans compilation testable, donc j'ai choisi l'honnêteté plutôt que de prétendre à un "coffre-fort chiffré" qui ne le serait pas vraiment. Camouflage d'icône d'app : pas fait (nécessite de toucher `AndroidManifest.xml` avec un `activity-alias` + code natif pour basculer dynamiquement, risqué à faire sans pouvoir compiler pour vérifier).
- **10/09 (24)** : Activation Premium via Stripe. Réutilise le pattern de checkout déjà en place pour le wallet (`walletController.ts`). `PREMIUM_PACKAGE` (4,99$/30 jours), `POST /wallet/premium-checkout`, webhook étendu pour activer `isPremium` + `premiumExpiresAt` à la confirmation du paiement (cumulatif si déjà Premium). Bouton "Go Premium" sur le profil si non-Premium. Limite assumée : paiement unique renouvelé manuellement, pas un vrai abonnement Stripe récurrent (pas de gestion d'annulation/webhook `invoice.payment_failed`) — plus simple à opérer sans infra de facturation récurrente. Pas de job qui repasse `isPremium` à `false` quand `premiumExpiresAt` est dépassé (le champ existe mais rien ne le vérifie encore automatiquement).
- **10/09 (23)** : Correction d'audit (transcription vocale déjà codée) + export/téléchargement des messages vocaux. Icône de téléchargement à côté du minuteur dans la bulle vocale — ouvre le fichier audio via le navigateur externe (`url_launcher`) plutôt qu'un vrai transcodage MP3, faute de bibliothèque de conversion audio fiable disponible dans cet environnement sans compilation testable. C'est honnête sur le format réel (le fichier reste dans son format d'origine, pas un vrai .mp3) plutôt que de prétendre à un export MP3 non testé.
- **10/09 (22)** : Fancy Text — support de mise en forme dans les bulles de message : `*gras*`, `_italique_`, `~barré~`, `` `code` `` (police monospace + fond). Parsing combiné avec les mentions/liens déjà en place (Day 12) via un second passage `parseFancySpans` sur les segments de texte brut. Pas de barre d'outils de formatage dans le champ de saisie — juste le rendu ; l'utilisateur tape la syntaxe à la main pour l'instant.
- **10/09 (21)** : Grand nettoyage d'audit — trois fonctionnalités listées à tort comme ❌ étaient en fait déjà codées : BotFather (création bot/token/webhook), auto-modération IA + fermeture de groupe, rôles XP/gamification/leaderboard. Toutes corrigées dans l'inventaire ci-dessus. Travail réel du jour : conversation avec Syrix Assistant toujours épinglée en tête de liste (`listConversations` trie les bots en premier) + option "Transférer" dans le menu contextuel des messages (sélecteur de conversation cible, réutilise `sendMessage`). Pas fait : génération d'images/résumés par l'IA transférables (aucune infra de génération d'image configurée côté serveur).
- **10/09 (20)** : Confidentialité fine — qui voit ma date de naissance (`hidden`/`contacts`/`everyone`, appliqué dans `getUserProfile`) et qui voit mes stories (`everyone`/`contacts`, appliqué dans `listActiveStories` via `isContactOf`). Sélecteurs ajoutés dans `edit_profile_screen.dart`. **Bug pré-existant corrigé au passage** : `/auth/me` ne renvoyait jamais `profileVisibility`/`dmPrice` — donc à chaque rechargement du profil, ces réglages retombaient silencieusement à leur valeur par défaut ("everyone"/0) même si l'utilisateur avait choisi autre chose. Exactement le genre de décalage fichier-vs-comportement signalé par le porteur de projet le 10/09 ; probablement présent depuis le tout début du projet, avant même nos sessions.
- **10/09 (19)** : Étiquetage clients — dernière pièce de la section 7 (Outils Business). `Contact.tag` (Prisma), `renameContact` étendu pour accepter `tag` en plus de `alias`. Trois étiquettes prédéfinies avec couleur (Prospect bleu, VIP client violet, Order in progress orange), badge coloré affiché à côté du nom dans `ContactsScreen`, sélection via bottom sheet (icône étiquette). Point d'attention : j'ai changé la signature de `ApiClient.renameContact()` de positionnelle à nommée (`{alias, tag}`) — les deux call sites existants ont été mis à jour, mais si une future session ajoute un nouvel appel, bien utiliser les paramètres nommés.
- **10/09 (18)** : Catalogue de produits. Nouveau modèle Mongo `Product` (nom/description/prix/image/date de lancement), CRUD complet (`GET/POST/PATCH/DELETE /catalog`). Écran `CatalogScreen` en grille, accessible depuis son propre profil (édition complète) et depuis le profil d'un autre utilisateur (lecture seule). Simplification assumée : l'image du produit est une URL collée à la main, pas d'upload dédié (pour rester dans le temps imparti — un vrai upload réutiliserait `config/upload.ts` si besoin plus tard).
- **10/09 (17)** : Recherche dans une conversation. Icône loupe dans l'en-tête du chat, remplace le titre par un champ de recherche, résultats surlignés via compteur "i/N" + flèches haut/bas qui font défiler jusqu'au message correspondant (réutilise et généralise l'infra de scroll créée pour la navigation par tags au Day 12 — `scrollToMessageId` factorisé). Limite : recherche uniquement sur les messages déjà chargés côté client (200 derniers, limite de `listMessages`), pas de recherche côté serveur sur tout l'historique.
- **10/09 (16)** : Correction d'audit — le double-tap réaction rapide était en fait **déjà codé** (`handleDoubleTap` dans `message_bubble.dart`), je l'avais listé à tort comme ❌ au Day 12. Ajouté l'animation d'explosion de cœur néon manquante (`TweenAnimationBuilder`, icône cyan). Contrôle parental (fait le 10/09) : PIN à 4 chiffres **distinct** du PIN de verrouillage d'app (`ParentalControlService`, clé de stockage séparée), verrouille l'accès à l'onglet Live (`main_shell.dart` intercepte la sélection d'onglet), écran de config dans Profil > Sécurité. Pas encore verrouillés : canaux publics et paramètres de paiement (seul Live est gate pour l'instant, ce sont les deux autres surfaces citées dans le prompt original).
- **10/09 (15)** : Appareils connectés / sessions actives. Nouveau modèle `Session` (Postgres), `sid` ajouté au payload JWT, `requireAuth` vérifie maintenant que la session n'a pas été révoquée (pas seulement la signature du JWT). Session créée à chaque `login`/`verify-email`. `GET/DELETE /auth/sessions`, `POST /auth/sessions/revoke-others`. Écran `SessionsScreen` (appareil, IP, "Log out all other sessions") accessible depuis Profil > Sécurité. Limite : pas de géolocalisation par IP (pays affiché dans le spec original) — seulement IP brute + type d'appareil déduit du User-Agent.
- **10/09 (14)** : Outils Business — message d'absence automatique (`User.awayEnabled`/`awayMessage`, déclenché dans `sendMessage` pour les chats privés, max 1 auto-réponse par conversation toutes les 4h) + réponses rapides `/raccourci` (`User.quickReplies` en Json, autocomplete dans la barre de saisie du chat). Nouvel écran `BusinessToolsScreen` accessible depuis le profil. **Bug corrigé au passage** : `api_client.dart` avait deux définitions identiques de `listContacts()` (une déjà présente dans le code d'origine, une que j'avais ajoutée par erreur au Day 6 sans vérifier le reste du fichier) — ça aurait empêché toute compilation. Retiré le doublon. Étiquetage clients (reste de la section 7) pas encore fait ; catalogue produits fait au Day 18 (voir plus haut).
- **10/09 (13)** : Mentions @username et liens cliquables dans les bulles (`message_bubble.dart` : `RichText`/`TapGestureRecognizer`, mentions en violet, liens en cyan néon `#00E5FF`, ouverture via `url_launcher`). Navigation avancée par @tags dans les groupes (section 5 du prompt) : taper une mention affiche une barre flottante en bas (Précédent/Suivant + compteur "Tag i/N") qui saute entre tous les messages mentionnant ce tag dans la conversation, via `GlobalKey`/`Scrollable.ensureVisible` par message. Limite : la regex de mention est simple (`@[a-zA-Z0-9_]{3,20}`), pas de vérification que le username mentionné existe réellement.
- **10/09 (12)** : Diagnostic + fix du bug Live/Appels. Cause trouvée : `LIVEKIT_URL=ws://localhost:7880` par défaut, jamais changé sur le VPS réel → le téléphone essaie de se connecter à lui-même. C'est une config VPS à corriger côté porteur de projet, pas un bug de code en soi — j'ai ajouté un `console.warn` au démarrage du serveur (`server.ts`) qui alerte si `LIVEKIT_URL` est absent/localhost, pour que ça ne passe plus inaperçu. Fix exact à appliquer documenté en section 4.4.
- **10/09 (11)** : Mode hors-ligne basique. Nouveau `OfflineCache` (SharedPreferences + JSON). `home_chats_screen.dart` et `chat_screen.dart` mettent en cache la liste de discussions / les messages à chaque chargement réussi, et retombent dessus si le réseau échoue (bannière "offline_banner" affichée). Bonus important : les deux écrans n'avaient **aucun** `try/catch` autour de leurs appels réseau — une simple coupure internet plantait silencieusement `loadData()`/`init()` et laissait le spinner tourner à l'infini. C'est corrigé au passage (`.timeout(8s)` + `try/catch` partout). Limite : seuls chats + messages du dernier écran ouvert sont cachés, pas les stories/folders/profils.
- **10/09 (10)** : Notifications réelles (n'était qu'un "Coming soon" statique). Modèle `Notification` (mention/contact_added/reaction/gift), déclenché sur mention `@username` dans un message texte et sur ajout de contact. `NotificationsScreen` remplace le `PlaceholderScreen` dans `main_shell.dart`. À partir de maintenant : je ne mets à jour que le bloc anglais de `i18n/strings.dart` (le porteur de projet traduit lui-même en français à partir des clés anglaises) — les nouvelles clés ajoutées après ce point n'ont donc pas d'entrée FR tant qu'il ne les a pas traduites.
- **10/09 (9)** : Reskin violet — `SyrixColors` (primary `#6C5CE7`, cyan `#00E5FF`, background `#13111C`, surface `#1E1B2E`), propagé automatiquement partout via les références `SyrixColors.primary`. Écran de connexion : fond dégradé plein écran, carte à bordure lumineuse, bouton dégradé violet→cyan avec glow. Bottom nav : labels texte ajoutés sous les 5 icônes. Pas encore fait : anneaux colorés autour des avatars dans le story bar, boutons de connexion sociale (Google/Apple/Facebook) sur login, bouton flottant "+" sur la liste de chats (il y en a déjà un dans `create_sheet.dart` mais pas au style exact de la maquette), reskin de `chat_screen.dart` (bulles #1E1B2E/dégradé, liens cyan néon, mentions bleu néon).
- **10/09 (8)** : Édition de message avec mention "Édité". `Message.edited`/`editedAt`, `PATCH /chats/:conversationId/messages/:messageId` (texte seulement, uniquement par l'expéditeur), diffusion websocket `messageEvent: "edit"`. Option "Éditer" dans le menu contextuel long-press (messages texte, soi-même uniquement), tag "Édité" affiché sous le texte modifié.
- **10/09 (7)** : Renommage personnalisé de contact (`Contact.alias`, `PATCH /contacts/:contactId`) + nouvel écran `ContactsScreen` (n'existait pas du tout avant — aucun endroit dans l'app ne listait ses contacts). Archivage de discussion : glisser à gauche sur une conversation (`Dismissible`), `Conversation.archivedBy`, nouvel écran `ArchivedChatsScreen` accessible via icône dans le header. Point d'attention : `startPrivateChat` est nécessaire pour ouvrir un chat depuis `ContactsScreen` (le contact stocké est un `userId`, pas un `conversationId`).
- **10/09 (6)** : Filtres de messages (Tout/Non lus/Lus/Groupes/Communautés) sous la barre de dossiers dans `home_chats_screen.dart`. Ajout du tracking non-lu : `Conversation.unreadBy` (liste de userId), peuplé à l'envoi de message, vidé à l'ouverture de la conversation (`listMessages`). Point néon + texte en gras sur les discussions non lues dans `ChatListItem`. Pas encore fait : filtre "Messages lus dans réponse" (reply status) — nécessiterait de tracker qui a répondu à qui, pas prioritaire.
- **10/09 (5)** : Autocomplete ville/pays sur le champ localisation (Nominatim/OpenStreetMap, debounce 400ms, chips de suggestion) dans `edit_profile_screen.dart`. Suggestions d'amis par localisation : `GET /users/nearby` (backend, match exact sur `location`) + section "Gens près de toi" dans `explorer_screen.dart`. Limite connue : le matching est une égalité stricte sur la chaîne `location` (insensible à la casse) — deux personnes qui tapent "Paris, France" différemment (accents, espaces) ne matcheront pas forcément ; l'autocomplete aide à uniformiser mais ne garantit rien à 100%.
- **10/09 (4)** : QR partageable en lien (`GET /u/:username` page publique + endpoint public `/api/v1/users/public/:username`, bouton "Copier le lien" sur le profil). Crayon d'édition sur le nom de groupe (`group_settings_screen.dart`) — affichage en lecture seule + icône crayon, bascule vers champ éditable au clic au lieu d'un TextField toujours actif.
- **10/09 (3)** : Communautés = conteneurs de groupes (pas juste une étiquette). `communityId` sur `Conversation`, `POST /chats/group` accepte `communityId`, nouveau `GET /chats/:communityId/groups`, `CommunityScreen` mobile, icône différenciée dans `ChatListItem`. Pas encore fait : canal d'annonces dédié à la communauté, migration des communautés déjà créées avant ce fix (elles restent vides tant qu'aucun groupe n'y est rattaché).
- **10/09 (2)** : Fix session persistante — `splash_screen.dart` routait toujours vers `LoginScreen` sans jamais vérifier le token stocké, causant la redemande systématique email+mdp. Corrigé : vérifie `syrix_token` en local, si présent tente `/auth/me` (6s timeout), va direct à `MainShell` (qui gère déjà le verrou PIN au démarrage/résume) sauf 401 explicite → purge le token et repasse par `LoginScreen`. En cas d'échec réseau (offline), on fait confiance au token local plutôt que de forcer une reconnexion.
- **10/09** : Audit complet des sections 1-4 du prompt "9 fonctionnalités" +
  implémentation (username/suggestions, identité IA verrouillée,
  Premium/badge/bannière/liens riches/repost-download story, panel admin
  Premium, nom d'expéditeur+badge dans les bulles de groupe). Découverte du
  bug `localhost` hardcodé (déjà corrigé par une session externe dans
  `syrix-chat-fixed.zip`, adopté comme base). Rédaction de ce fichier suite
  aux retours utilisateur sur l'APK réel + captures d'écran + maquettes de
  design cible + nouveaux prompts.
