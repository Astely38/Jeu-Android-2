# Jeu-Android-2

## Eneko, la Voie du Sabre

Petit platformer 2D fait avec [Godot 4](https://godotengine.org/). Eneko — un jeune samouraï aux
boucles d'oreilles dorées, armé du sabre de son grand-père — traverse une forêt de bambous, saute
par-dessus les trous, tranche un esprit malveillant au sabre, et rejoint le torii pour terminer le
niveau.

Eneko a **3 cœurs de vie** (en haut à gauche) : toucher l'esprit sans l'attaquer coûte un cœur ;
à zéro cœur, on repart au début du niveau. Tomber dans un trou renvoie aussi au départ.

Contrôles tactiles à l'écran : Gauche / Droite / Saut à gauche, Attaque à droite.

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
