class_name Sfx
extends Object
## Aides audio réutilisables. But principal : jouer un bruitage avec une
## légère variation de hauteur aléatoire, pour que les sons répétés (coups
## de sabre, sauts, ramassages...) ne sonnent pas identiques et mécaniques.

## Joue le lecteur avec une hauteur (pitch) tirée dans [lo, hi].
static func varied(p: AudioStreamPlayer, lo: float = 0.94, hi: float = 1.06) -> void:
	if p == null or not is_instance_valid(p):
		return
	p.pitch_scale = randf_range(lo, hi)
	p.play()

## Variante pour un lecteur positionnel (AudioStreamPlayer2D).
static func varied2d(p: AudioStreamPlayer2D, lo: float = 0.94, hi: float = 1.06) -> void:
	if p == null or not is_instance_valid(p):
		return
	p.pitch_scale = randf_range(lo, hi)
	p.play()
