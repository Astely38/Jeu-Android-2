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
rechargent l'énergie du sabre et, tous les 5 ramassés, **rendent un cœur**. Décor enrichi (soleil,
nuages, touffes d'herbe, cailloux) et effets sonores et vent ambiant inclus.

Contrôles tactiles à l'écran : Gauche / Droite / Saut à gauche, Attaque à droite.

**Sauvegarde locale** (JSON, `user://save.json`) : niveaux terminés/débloqués et meilleur score
d'orbes par niveau. Le menu principal propose **Continuer** (reprend le dernier niveau joué, visible
dès qu'une sauvegarde existe) et **Niveaux** (écran de sélection listant les 5 niveaux prévus —
les niveaux 3 à 5 apparaissent encore en "à venir").

**Niveau 2 — Le Temple Oublié** : ascension verticale en zigzag dans des ruines de pierre, avec
des pièges à pieux, les mêmes esprits repositionnés, 4 points de contrôle et une apparition de
Léonie à mi-parcours. Débloqué en terminant le niveau 1 (bouton "Niveau suivant" sur l'écran de
victoire).

### Structure du projet

```
/scenes   main_menu, level_select, player, enemy, shadow, leonie, orb
/levels   level_1 ("La Clairière des Bambous"), level_2 ("Le Temple Oublié")
/scripts  logique GDScript (player, enemy, shadow, leonie, level, level_2, main_menu, level_select)
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
3. Dans la section "Assets", appuie sur **eneko.apk** pour le télécharger (pas besoin de dézipper).
4. Ouvre le fichier téléchargé et autorise l'installation depuis une "source inconnue" si demandé.

### Développer le projet

Ouvre simplement le dossier avec [Godot 4.6+](https://godotengine.org/download) (`project.godot`
à la racine) pour éditer les scènes dans l'éditeur.
