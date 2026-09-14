# SYRIX CHAT — Dossier de soumission Play Store / App Store

Ce fichier regroupe tout ce qu'il faut préparer pour publier l'app. Les
textes marketing sont prêts à copier-coller ; les sections légales et de
sécurité des données restent à vérifier/compléter avant soumission — ce
n'est pas un avis juridique.

## 1. Liens obligatoires à fournir aux deux stores

- Politique de confidentialité : `https://tondomaine.com/privacy`
- Conditions d'utilisation : `https://tondomaine.com/terms`

Les deux sont déjà hébergées par l'API (`apps/api/public/legal/`). Complète
d'abord les champs `[À COMPLÉTER]` dans ces deux fichiers (nom légal de
l'entreprise, email de support, adresse si requise, droit applicable) —
**avant** de soumettre, pas après.

## 2. Fiche store (textes)

**Nom de l'app** (≤30 caractères) : `SYRIX CHAT`

**Description courte** (Play Store, ≤80 caractères) :
`Chat, stories, live et cadeaux virtuels entre amis.`

**Description longue** (≤4000 caractères, adapte selon les fonctionnalités
réellement actives à la date de soumission) :

```
SYRIX CHAT — messagerie, stories et live, tout au même endroit.

Discutez en temps réel avec vos amis, en privé ou en groupe. Partagez des
stories qui disparaissent après 24h. Démarrez un live et échangez avec vos
spectateurs en direct. Rechargez votre portefeuille pour envoyer des
cadeaux virtuels pendant vos conversations ou vos lives.

FONCTIONNALITÉS
• Messagerie instantanée privée et de groupe
• Stories photo (expirent après 24h)
• Live streaming vidéo
• Portefeuille intégré et cadeaux virtuels
• Assistant IA intégré pour répondre à vos questions
• Profil personnalisable (photo, bio)

SYRIX CHAT tourne sur une infrastructure que nous exploitons nous-mêmes —
vos messages et vos échanges avec l'assistant ne sont pas partagés avec des
régies publicitaires tierces.
```

**Catégorie suggérée** : Réseaux sociaux / Communication

**Mots-clés** (App Store, ≤100 caractères) : `chat,messagerie,live,stories,social,cadeaux`

## 3. Classification par âge — à traiter sérieusement

L'app combine messagerie ouverte, live streaming vidéo et achats intégrés
(wallet). Sur les deux stores, ça pousse presque toujours la classification
vers **Teen/16+ ou Mature 17+**, pas "tout public". Réponds honnêtement au
questionnaire (Play Console → "Content rating", App Store Connect → "Age
Rating") en cochant :
- Communication/chat non modéré entre utilisateurs → oui
- Contenu généré par les utilisateurs (photos, vidéo en direct) → oui
- Achats intégrés → oui
- Partage de la localisation → non (pas implémenté actuellement)

**Point bloquant à régler avant soumission** : ce build ne vérifie pas
l'âge à l'inscription. Les deux stores peuvent rejeter ou re-classifier
l'app si un chat ouvert entre inconnus est accessible à des comptes non
vérifiés comme majeurs. Ajoute au minimum une case "date de naissance" au
signup et bloque l'accès au chat/paiement en dessous de l'âge légal choisi,
avant de soumettre.

## 4. Data Safety (Google Play Console)

Section "Data safety" → déclarer, en fonction de ce que l'app collecte
réellement (voir `apps/api/public/legal/privacy.html` pour le détail) :

| Type de donnée | Collectée ? | Partagée avec un tiers ? | Finalité |
|---|---|---|---|
| Email | Oui | Non | Création de compte, vérification |
| Nom d'utilisateur / photo de profil | Oui | Non | Fonctionnalités de l'app |
| Messages | Oui | Non | Fonctionnalités de l'app |
| Photos (stories) | Oui | Non | Fonctionnalités de l'app |
| Audio/vidéo (live) | Oui | Non | Fonctionnalités de l'app |
| Informations de paiement | Non (traité par Stripe) | Oui (Stripe) | Traitement du paiement |
| Historique des transactions (montant, date) | Oui | Non | Portefeuille, comptabilité |

Case "Chiffrement en transit" : coche Oui une fois HTTPS/WSS actif en
production (fait par `deploy.sh`, section Day 8 du README).
Case "Suppression des données sur demande" : coche Oui — le processus
existe (contact email), à automatiser plus tard si besoin.

## 5. App Privacy (App Store Connect)

Même logique côté Apple, sous forme d'étiquette "Confidentialité de
l'app". Catégories à déclarer comme "Associées à vous" : contact info
(email), contenu utilisateur (messages, photos, vidéo), identifiants
(ID de compte). Déclare "Utilisé pour suivre" = Non pour toutes (pas de
tracking publicitaire tiers dans ce build).

## 6. Captures d'écran à préparer

Les deux stores exigent des tailles précises par type d'appareil. Résolutions
courantes à couvrir (vérifie les exigences à jour au moment de soumettre,
elles changent parfois) :
- Téléphone : 1080×1920 ou 1290×2796 (iPhone Pro Max) minimum, portrait
- Tablette 7" et 10" si tu coches "compatible tablette"

Écrans à capturer en priorité (5 à 8 images) :
1. Splash / écran de connexion
2. Liste de chats (avec story bar visible)
3. Une conversation en cours (idéalement avec l'assistant IA visible)
4. Un live en cours
5. L'écran Portefeuille (packs de recharge)
6. L'écran Profil

## 7. Compte développeur

- Google Play : compte développeur (frais unique ~25 USD) + vérification
  d'identité, peut prendre plusieurs jours
- Apple App Store : Apple Developer Program (~99 USD/an), vérification
  d'entité légale si tu soumets en tant qu'entreprise (documents
  justificatifs demandés — prévoir ce délai dans ton planning)
