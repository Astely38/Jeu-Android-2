# Jeu-Android-2

## Eneko, la Voie du Sabre

Petit platformer 2D fait avec [Godot 4](https://godotengine.org/). Eneko traverse une clairière de
bambous, saute par-dessus les trous, tranche un esprit malveillant au sabre, et rejoint le torii
illuminé pour terminer le niveau.

Contrôles tactiles à l'écran : Gauche / Droite / Saut à gauche, Attaque à droite.

### Récupérer l'APK sur ton téléphone

Chaque `push` sur ce dépôt déclenche une compilation automatique (GitHub Actions) qui génère un
APK de debug, installable directement sans passer par le Play Store :

1. Va dans l'onglet **Actions** du dépôt GitHub.
2. Ouvre le run le plus récent du workflow **Build Android APK**.
3. Télécharge l'artifact **eneko-apk** (un zip contenant `eneko.apk`).
4. Transfère le fichier `.apk` sur ton téléphone (ou télécharge-le directement depuis le
   navigateur du téléphone si tu es connecté à ton compte GitHub).
5. Ouvre le fichier APK sur le téléphone et autorise l'installation depuis une "source inconnue"
   si demandé.

### Développer le projet

Ouvre simplement le dossier avec [Godot 4.6+](https://godotengine.org/download) (`project.godot`
à la racine) pour éditer les scènes dans l'éditeur.
