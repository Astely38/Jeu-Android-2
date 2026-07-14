# Sprites d'animation d'Eneko

Dépose ici les images du pack d'animation d'Eneko (le personnage joueur).
Une fois les fichiers présents, je (Claude) mesure leurs dimensions réelles,
je les découpe en frames et je branche l'`AnimatedSprite2D` + la machine à
états d'animation dans le jeu.

## Ce qu'il faut

Un pack pixel art **vue de côté** (side-scroller) avec, au minimum :

- `idle`  (repos / respiration)
- `run`   (course) ou `walk` (marche)
- `jump`  (saut, montée)
- `fall`  (chute)
- `attack` (coup de sabre)
- `hurt`  (touché)  — optionnel
- `death` (mort)    — optionnel

## Format idéal (le plus fiable à découper)

**Une image PNG par animation**, chaque image étant une **bande horizontale**
de frames de **taille égale** (idéalement carrées).

Nommage conseillé (minuscules) — mais si le pack utilise d'autres noms, ce
n'est pas grave, indique-moi juste la correspondance :

```
idle.png
run.png
jump.png
fall.png
attack.png
hurt.png
death.png
```

## Si le pack est une seule grande planche combinée

Dépose-la quand même **ET** ajoute le fichier de données qui l'accompagne
(`.json` d'Aseprite / TexturePacker, ou un `.txt` décrivant la taille des
frames). Ça me permet un découpage exact.

## Important — licence / crédits

Ajoute ici (ou dis-le moi) : **nom du pack, auteur, URL et licence**.
Je les inscrirai dans les crédits du jeu. Vérifie que la licence autorise
l'usage dans un jeu ; si elle interdit la redistribution, on gardera
éventuellement le dépôt en privé.

Pack utilisé : _(à compléter)_
Auteur / source : _(à compléter)_
Licence : _(à compléter)_
