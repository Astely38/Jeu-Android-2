# Jeu-Android-2

## Eneko, la Voie du Sabre

Petit platformer 2D fait avec [Godot 4](https://godotengine.org/). Eneko — un jeune samouraï aux
boucles d'oreilles dorées, armé du sabre de son grand-père — traverse une forêt de bambous, saute
par-dessus les trous et les **pics**, tranche des esprits malveillants au sabre, et rejoint le
torii pour terminer le niveau.

Eneko a **3 cœurs de vie** (en haut à gauche) : toucher un esprit, marcher sur un **piège à pieux de bois**,
**ou tomber dans un trou** coûte un cœur et renvoie au dernier **point de contrôle** (bannière).
En chemin, **Léonie**, la gardienne kitsune de la forêt, l'accueille par un court dialogue. Deux
types d'ennemis, désormais plus nombreux : l'esprit **Onre** qui patrouille sa plateforme, et
l'**Ombre corrompue** (guerrier spectral sombre) qui poursuit Eneko. Les **orbes spirituels**
comptent pour le grade de fin de niveau et, tous les 5 ramassés, **rendent un cœur**. Décor peint : montagnes
enneigées, collines, nuages, nappes de brume, bambous noueux, fleurs sauvages et **pétales de
cerisier** portés par le vent. Effets sonores et vent ambiant inclus.

Contrôles tactiles à l'écran : Gauche / Droite à gauche ; **Ruée** (dash éclair avec images
rémanentes, invincible pendant l'élan, temps de recharge court), Saut et Attaque à droite.
Maintenir le saut permet de sauter plus haut. Chaque niveau s'ouvre sur un **survol de caméra**
depuis l'objectif jusqu'à Eneko — joué une seule fois par session et **passable d'un tap** — et
chaque coup de sabre qui porte marque un bref **arrêt du temps**. Un **chronomètre** et le
compteur d'orbes (récoltés / total) s'affichent en haut de l'écran ; le chrono ne démarre qu'à
la prise en main. Le bouton du haut ouvre une **pause** (Reprendre / Recommencer / Retour au
menu) au lieu de quitter directement. La sélection de niveaux affiche le **meilleur grade** et
le **meilleur temps** de chaque niveau terminé.

**Sauvegarde locale** (JSON, `user://save.json`) : niveaux terminés/débloqués et meilleur score
d'orbes par niveau. Le menu principal propose **Continuer** (reprend le dernier niveau joué, visible
dès qu'une sauvegarde existe) et **Niveaux** (écran de sélection listant les 5 niveaux prévus —
les niveaux 3 à 5 apparaissent encore en "à venir").

**Niveau 2 — Le Temple Oublié** : ascension nocturne d'une tour en ruine sous un **ciel étoilé**,
jusqu'à la **lune** qui veille sur le sanctuaire. Torches aux **flammes animées** et halos pulsants,
**braises flottantes**, piliers de pierre, statues gardiennes aux yeux luisants, bannières rouge et
or, dalles fissurées et moussues. 3 points de contrôle, pièges à pieux, esprits et ombres
corrompues, apparition de Léonie à mi-parcours. Débloqué en terminant le niveau 1.

**Niveau 3 — Le Village des Ombres** : traversée d'un village abandonné sous une **lune de sang**.
Maisons aux fenêtres encore luisantes, portes béantes, **cordées de lanternes** entre les poteaux,
braseros aux flammes dansantes, arbres morts, clôtures brisées, brume violette et volutes sombres.
Les points de contrôle sont des **lanternes de pierre (tōrō)** qui s'allument en vert. Les Ombres
corrompues y sont plus nombreuses que partout ailleurs. Débloqué en terminant le niveau 2.

**Niveau 4 — La Montagne des Brumes** : ascension rocheuse en haute montagne, sous un **ciel pâle
et froid**. Pics enneigés, crêtes rocheuses, **drapeaux de prière** déchirés tendus entre des mâts,
**cairns de pierre**, ponts de corde suspendus, brume dense et neige qui tombe doucement. Pièges à
**stalactites de glace**. Léonie apparaît une dernière fois à mi-parcours avant de laisser Eneko
continuer seul vers le sommet. Débloqué en terminant le niveau 3.

**Niveau 5 — Le Sanctuaire Final** : traversée de marbre pâle et d'or — dont un grand vide
franchissable uniquement par des **dalles effondrables** — menant à l'arène du **Gardien Corrompu**,
boss final doté de **12 points de vie et 3 phases** : marche, puis charges, puis charges rapprochées
et coups enchaînés, avec des Ombres invoquées en renfort à chaque changement de phase. Une barre de
vie s'affiche en haut de l'écran pendant le combat. Léonie n'apparaît pas — elle l'a annoncé au
sommet de la montagne, Eneko termine seul. Débloqué en terminant le niveau 4 ; dernier niveau de la
progression.

**Nouvelles mécaniques** : **ponts de corde praticables** au-dessus des grandes brèches et **dalles
effondrables** qui tremblent puis s'écroulent sous les pieds avant de se reformer (niveaux 4-5),
**rafales de vent** alternées qui poussent Eneko sur la montagne — la brume et la neige filent dans
le sens du vent pour l'annoncer (niveau 4). Les esprits Onre et les Ombres corrompues sont
globalement plus rapides.

Le **système de défi** note chaque niveau terminé (Bronze/Argent/Or/Platine) selon les orbes
récoltés et les dégâts subis, affiché sur l'écran de victoire. **Toute défaite (chute ou 0 cœur)
redémarre intégralement le niveau** — plus de retour au dernier checkpoint.

Le **menu principal** est un tableau de crépuscule : soleil couchant derrière un torii sur la
colline, montagnes, rivière aux reflets dorés et pétales portés par le vent.

### Structure du projet

```
/scenes   main_menu, level_select, player, enemy, shadow, undead, leonie, orb, boss
/levels   level_1 ("La Clairière des Bambous"), level_2 ("Le Temple Oublié"),
          level_3 ("Le Village des Ombres"), level_4 ("La Montagne des Brumes"),
          level_5 ("Le Sanctuaire Final")
/scripts  logique GDScript (player, enemy, shadow, undead, leonie, boss, level, level_2, level_3,
          level_4, level_5, main_menu, level_select, challenge)
/scripts/save  SaveManager (autoload, sauvegarde JSON)
/ui       boîte de dialogue
/assets   sprites (SVG + pixel art), sons (assets/sfx)
```

Le jeu démarre sur le **menu principal**. Les collisions du sol reposent sur des `StaticBody2D`
(fiables) ; une migration vers un `TileMap` peint est prévue une fois que le rendu pourra être
vérifié dans l'éditeur Godot.

### Récupérer l'APK sur ton téléphone

Chaque `push` sur ce dépôt déclenche une compilation automatique (GitHub Actions) qui publie un
APK de debug directement dans les **Releases** du dépôt, installable sans passer par le Play
Store et sans avoir besoin d'être connecté à GitHub :

1. Depuis le téléphone, ouvre :
   **https://github.com/Astely38/Jeu-Android-2/releases**
2. Tout en haut de la liste se trouve le build le plus récent (ex. "Build #4"). Ouvre-le.
3. Dans la section "Assets", appuie sur **eneko-v0.NN.apk** (NN = numéro du build) pour le
   télécharger (pas besoin de dézipper).
4. Ouvre le fichier téléchargé et autorise l'installation depuis une "source inconnue" si demandé.

### Développer le projet

Ouvre simplement le dossier avec [Godot 4.6+](https://godotengine.org/download) (`project.godot`
à la racine) pour éditer les scènes dans l'éditeur.
