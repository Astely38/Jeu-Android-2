extends LevelBase
## Niveau 2 : « Le Temple Oublié ».
## Ruine sacrée à flanc de colline, dans la nuit. On gravit un grand
## escalier de terrasses de pierre qui monte régulièrement vers la droite
## jusqu'au sanctuaire du sommet — une ascension franche, sans zigzag.
## Ciel étoilé, lune croissante, pagodes en ruine au loin, torches et
## braises, statues gardiennes et bannières.

const ORB_SCENE := preload("res://scenes/orb.tscn")
const PATROL_SCENE := preload("res://scenes/enemy.tscn")
const SHADOW_SCENE := preload("res://scenes/shadow.tscn")
const LEONIE_SCENE := preload("res://scenes/leonie.tscn")
const SPIRIT_SCENE := preload("res://scenes/spirit.tscn")

const LEVEL_END := 5600.0
const LEVEL_ID := "level_2"

const STONE := Color(0.45, 0.42, 0.38)
const STONE_DARK := Color(0.3, 0.28, 0.25)
const CLOTH := Color(0.52, 0.13, 0.11)
const CLOTH_TRIM := Color(0.85, 0.68, 0.3)

## Thème du peintre de plateformes : pierre de temple, joints de maçonnerie.
const PLATFORM_THEME := {
	"top": Color(0.5, 0.47, 0.43),
	"top_light": Color(0.63, 0.59, 0.53),
	"body_a": Color(0.4, 0.37, 0.34),
	"body_b": Color(0.33, 0.3, 0.28),
	"dark": Color(0.24, 0.22, 0.2),
	"speck": Color(0.52, 0.49, 0.45),
	"cut": true,
}

## Terrasses de l'escalier : (x = centre, y = centre vertical du bloc).
## Chaque marche monte d'environ 46 px et s'écarte de la précédente d'un
## saut confortable (< 170 px) — montée régulière vers la droite.
const PLATFORMS := [
	Vector2(280, 580), Vector2(660, 532), Vector2(1010, 486), Vector2(1360, 440),
	Vector2(1740, 396), Vector2(2120, 350), Vector2(2470, 304), Vector2(2850, 258),
	Vector2(3230, 212), Vector2(3600, 166), Vector2(3980, 120), Vector2(4330, 74),
	Vector2(4710, 28), Vector2(5110, -12),
]
const HALF_WIDTHS := [
	200, 120, 120, 130, 190, 120, 130, 190, 120, 190, 120, 130, 120, 200,
]

const CHECKPOINT_IDX := [4, 9]
const LEONIE_IDX := 7
const GOAL_IDX := 13

const PATROL_IDX := [1, 3, 6, 10]
const SHADOW_IDX := [2, 8]
## Ombre d'élite : rare, deux coups à placer, orbe dorée (3 orbes) à la clé.
const ELITE_IDX := [5]
## Yūrei tireur : au-dessus d'une terrasse (jamais d'un trou).
const SPIRIT_IDX := [11]
const TRAP_IDX := [3, 8, 11]
const BRAZIER_IDX := [1, 5, 9, 12]

## Orbes : une traînée le long des marches, trois sur les larges terrasses.
const ORBS := [
	Vector2(280, 465), Vector2(210, 465), Vector2(350, 465),
	Vector2(660, 417),
	Vector2(1010, 371),
	Vector2(1360, 325),
	Vector2(1740, 281), Vector2(1670, 281), Vector2(1810, 281),
	Vector2(2120, 235),
	Vector2(2470, 189),
	Vector2(2850, 143), Vector2(2780, 143), Vector2(2920, 143),
	Vector2(3230, 97),
	Vector2(3600, 51), Vector2(3530, 51), Vector2(3670, 51),
	Vector2(3980, 5),
	Vector2(4330, -41),
	Vector2(4710, -87),
]

const LEONIE_LINES := [
	{ "name": "Léonie", "text": "Ce temple gardait autrefois une braise de la Flamme d'Aube. Les Ombres l'ont éteinte parmi les premières." },
	{ "name": "Léonie", "text": "Plus tu rassembles d'éclats, plus la Flamme se souvient d'elle-même. Ne néglige aucune lueur." },
	{ "name": "Léonie", "text": "Je veille sur toi. Ma lumière t'entoure encore un temps — profite-s'en." },
	{ "name": "Léonie", "text": "Gravis les marches jusqu'au sanctuaire du sommet. La Voie ne fait que commencer." },
	{ "name": "Eneko", "text": "Chaque marche me rapproche de la source. Je ne m'arrêterai pas." },
]

var sfx_win: AudioStreamPlayer
var embers: CPUParticles2D
var _flames: Array = []
var _halos: Array = []
var _t := 0.0
## Ciel : couche presque fixe où filent les étoiles filantes.
var _sky: ParallaxLayer
var _meteor_cd := 3.0
## Lucioles qui errent dans la nuit et pulsent leur lueur (voir _process).
var _fireflies: Array = []
## Positions des flaques ; des ondulations y troublent la surface.
var _puddles: Array = []
var _ripple_cd := 1.5

@onready var player: CharacterBody2D = $Player
@onready var win_label: CanvasLayer = $WinLabel
@onready var menu_button: Button = $WinLabel/MenuButton
@onready var next_button: Button = $WinLabel/NextButton
@onready var dialogue: CanvasLayer = $Dialogue

func _ready() -> void:
	_build_decor()
	Atmosphere.add_foreground(self, Color(0.07, 0.07, 0.13, 0.32))
	_build_platforms()
	_build_hazards()
	_build_fireflies()
	_build_puddles()
	_build_braziers()
	_build_checkpoints()
	_build_traps()
	_build_goal()
	_build_kill_zone(LEVEL_END, 820.0, 200.0)
	_spawn_entities()
	_setup_audio()
	_setup_ambient()
	win_label.visible = false
	SaveManager.set_last_level(LEVEL_ID)
	# Relique cachée, en surplomb juste au-dessus de l'apparition.
	var relic := Relic.new()
	relic.level_id = LEVEL_ID
	relic.position = Vector2(280, 398)
	add_child(relic)
	# Les orbes dorées des Ombres d'élite comptent dans le total (3 chacune).
	Challenge.start_level(LEVEL_ID, ORBS.size() + 3 * ELITE_IDX.size())
	_attach_player_glow()
	menu_button.pressed.connect(_on_menu_pressed)
	dialogue.finished.connect(_on_dialogue_finished)
	var next_scene: String = SaveManager.LEVEL_SCENES.get("level_3", "")
	next_button.visible = next_scene != ""
	if next_scene != "":
		next_button.pressed.connect(func(): Transition.goto(next_scene))
	# Survol d'introduction : du sanctuaire au sommet jusqu'à Eneko en bas.
	var summit: Vector2 = PLATFORMS[GOAL_IDX]
	player.intro_pan(Vector2(summit.x, summit.y - 120.0), 2.2)

func _process(delta: float) -> void:
	_t += delta
	for i in _flames.size():
		var f: Polygon2D = _flames[i]
		f.scale.y = 1.0 + 0.16 * sin(_t * 8.0 + i * 1.7)
		f.scale.x = 1.0 + 0.1 * sin(_t * 6.3 + i * 2.3)
	for i in _halos.size():
		var h: Sprite2D = _halos[i]
		h.modulate.a = 0.17 + 0.06 * sin(_t * 5.0 + i * 1.3)
	for ff in _fireflies:
		var fn: Node2D = ff["node"]
		var home: Vector2 = ff["home"]
		var ph: float = float(ff["phase"])
		var nx := home.x + float(ff["rx"]) * sin(_t * float(ff["sx"]) + ph)
		var ny := home.y + float(ff["ry"]) * sin(_t * float(ff["sy"]) + ph * 1.7)
		fn.position = Vector2(nx, ny)
		var halo: Sprite2D = ff["halo"]
		halo.modulate.a = 0.25 + 0.4 * (0.5 + 0.5 * sin(_t * 2.4 + ph * 2.3))
	# Étoiles filantes : de loin en loin, une traînée file dans le ciel.
	_meteor_cd -= delta
	if _meteor_cd <= 0.0 and _sky != null:
		_meteor_cd = randf_range(3.5, 8.0)
		_spawn_meteor()
	# Ondulations qui troublent la surface des flaques de lune.
	_ripple_cd -= delta
	if _ripple_cd <= 0.0 and not _puddles.is_empty():
		_ripple_cd = randf_range(1.2, 2.6)
		_spawn_puddle_ripple()

## Rond d'onde bleuté qui s'élargit sur une flaque au hasard.
func _spawn_puddle_ripple() -> void:
	var base: Vector2 = _puddles[randi() % _puddles.size()]
	var pos := base + Vector2(randf_range(-30.0, 30.0), randf_range(-2.0, 3.0))
	var ring := Line2D.new()
	ring.width = 1.5
	ring.default_color = Color(0.72, 0.82, 1.0, 0.45)
	ring.closed = true
	var pts := PackedVector2Array()
	var k := 0
	while k < 14:
		var a := k * TAU / 14.0
		pts.append(Vector2(cos(a) * 8.0, sin(a) * 2.4))
		k += 1
	ring.points = pts
	ring.position = pos
	add_child(ring)
	var tw := ring.create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "scale", Vector2(3.2, 3.2), 1.1)
	tw.tween_property(ring, "modulate:a", 0.0, 1.1)
	tw.chain().tween_callback(ring.queue_free)

## Une étoile filante : traînée lumineuse qui traverse le ciel en diagonale
## puis s'efface. Purement décoratif, dans la couche du ciel.
func _spawn_meteor() -> void:
	var start := Vector2(randf_range(200.0, 1000.0), randf_range(-40.0, 140.0))
	var dir := Vector2(-1.0, 0.5).normalized()
	var len := randf_range(70.0, 130.0)
	var trail := Line2D.new()
	trail.width = 2.2
	trail.default_color = Color(0.9, 0.95, 1.0, 0.0)
	trail.points = PackedVector2Array([start, start + dir * len])
	# Dégradé : tête vive, queue estompée.
	var grad := Gradient.new()
	grad.set_color(0, Color(1, 1, 1, 0.0))
	grad.set_color(1, Color(0.85, 0.92, 1.0, 0.95))
	trail.gradient = grad
	trail.z_index = -1
	_sky.add_child(trail)
	var travel := dir * randf_range(360.0, 520.0)
	var tw := trail.create_tween()
	tw.set_parallel(true)
	tw.tween_property(trail, "position", travel, 0.7)
	tw.tween_property(trail, "modulate:a", 0.0, 0.7).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(trail.queue_free)

func _physics_process(_delta: float) -> void:
	if embers != null and is_instance_valid(player):
		embers.position = player.position + Vector2(0, -60.0)

# --- Aides géométriques ---------------------------------------------------

## Hauteur d'apparition d'un personnage debout sur la terrasse `idx`.
func _stand_y(idx: int) -> Vector2:
	var p: Vector2 = PLATFORMS[idx]
	return Vector2(p.x, p.y - 73.0)

## Y de la surface (dessus) de la terrasse `idx`.
func _surface_y(idx: int) -> float:
	return PLATFORMS[idx].y - 50.0

func _poly(parent: Node, points: PackedVector2Array, color: Color, pos := Vector2.ZERO) -> Polygon2D:
	var p := Polygon2D.new()
	p.polygon = points
	p.color = color
	p.position = pos
	parent.add_child(p)
	return p

func _attach_player_glow() -> void:
	var glow := Sprite2D.new()
	glow.texture = load("res://assets/mist.svg")
	glow.modulate = Color(1.0, 0.78, 0.4, 0.14)
	glow.scale = Vector2(3.2, 3.2)
	glow.position = Vector2(0, -10)
	glow.z_index = -1
	player.add_child(glow)

# --- Décor ----------------------------------------------------------------

## Ciel de nuit : lune croissante, étoiles, pagodes en ruine au loin,
## colonnes brisées, brume et braises qui montent avec Eneko.
func _build_decor() -> void:
	var bg: ParallaxBackground = $ParallaxBackground
	var mist_tex: Texture2D = load("res://assets/mist.svg")

	# Lune et étoiles, presque fixes.
	var sky := ParallaxLayer.new()
	sky.motion_scale = Vector2(0.05, 0.05)
	bg.add_child(sky)
	_sky = sky
	var moon_glow := Sprite2D.new()
	moon_glow.texture = mist_tex
	moon_glow.modulate = Color(0.8, 0.85, 1.0, 0.35)
	moon_glow.scale = Vector2(7.0, 7.0)
	moon_glow.position = Vector2(760.0, 110.0)
	sky.add_child(moon_glow)
	var moon := PackedVector2Array()
	var k := 0
	while k <= 22:
		var a := -1.9 + k * 3.8 / 22.0
		moon.append(Vector2(cos(a) * 34.0, sin(a) * 34.0))
		k += 1
	k = 22
	while k >= 0:
		var a2 := -1.6 + k * 3.2 / 22.0
		moon.append(Vector2(cos(a2) * 26.0 + 11.0, sin(a2) * 26.0))
		k -= 1
	_poly(sky, moon, Color(0.92, 0.94, 1.0, 0.92), Vector2(760, 110))
	# Rayons lunaires froids qui descendent sur l'escalier.
	var rays := GodRays.new()
	rays.color = Color(0.78, 0.84, 1.0, 0.06)
	rays.length = 1300.0
	rays.half_spread = 0.8
	rays.position = Vector2(760.0, 110.0)
	sky.add_child(rays)
	var si := 0
	while si < 60:
		var stx := -200.0 + float((si * 137) % 1360)
		var sty := 20.0 + float((si * 211) % 520)
		var r := 1.3 + float(si % 3) * 0.6
		_poly(sky, PackedVector2Array([
			Vector2(-r, 0), Vector2(0, -r), Vector2(r, 0), Vector2(0, r),
		]), Color(0.92, 0.93, 1.0, 0.4 + float(si % 4) * 0.12), Vector2(stx, sty))
		si += 1

	# Pagodes et collines noires au loin.
	var far := ParallaxLayer.new()
	far.motion_scale = Vector2(0.16, 0.7)
	bg.add_child(far)
	var mx := -200.0
	var mi := 0
	while mx < LEVEL_END + 900.0:
		var mh := 150.0 + float(mi * 47 % 80)
		_poly(far, PackedVector2Array([
			Vector2(-300, 0), Vector2(-110, -mh + 40), Vector2(0, -mh),
			Vector2(150, -mh + 50), Vector2(300, 0),
		]), Color(0.1, 0.09, 0.15, 0.85), Vector2(mx, 600))
		if mi % 2 == 1:
			_build_pagoda(far, Vector2(mx + 120.0, 600.0), mi)
		mx += 460.0 + float(mi * 31 % 120)
		mi += 1

	# Colonnes brisées, plan intermédiaire.
	var mid := ParallaxLayer.new()
	mid.motion_scale = Vector2(0.5, 1)
	bg.add_child(mid)
	var cx := 260.0
	var ci := 0
	while cx < LEVEL_END:
		var ch := 120.0 + float(ci * 41 % 90)
		_poly(mid, PackedVector2Array([
			Vector2(-16, 0), Vector2(16, 0), Vector2(13, -ch), Vector2(-13, -ch),
		]), Color(0.14, 0.12, 0.15, 0.85), Vector2(cx, 560.0))
		_poly(mid, PackedVector2Array([
			Vector2(-22, -ch), Vector2(22, -ch), Vector2(18, -ch - 10), Vector2(-18, -ch - 10),
		]), Color(0.2, 0.17, 0.14, 0.8), Vector2(cx, 560.0))
		cx += 520.0 + float(ci * 37 % 160)
		ci += 1

	# Brume nocturne au ras des terrasses.
	var mist_layer := ParallaxLayer.new()
	mist_layer.motion_scale = Vector2(0.55, 1)
	bg.add_child(mist_layer)
	var i := 0
	while i < PLATFORMS.size():
		var p: Vector2 = PLATFORMS[i]
		var m := Sprite2D.new()
		m.texture = mist_tex
		m.position = Vector2(p.x, p.y + 30.0)
		m.scale = Vector2(5.0, 1.6)
		m.modulate = Color(0.72, 0.75, 0.95, 0.1)
		mist_layer.add_child(m)
		i += 1

	# Braises qui montent autour d'Eneko.
	embers = CPUParticles2D.new()
	embers.amount = 24
	embers.lifetime = 5.0
	embers.preprocess = 5.0
	embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	embers.emission_rect_extents = Vector2(320, 220)
	embers.direction = Vector2(0, -1)
	embers.spread = 30.0
	embers.gravity = Vector2(0, -14)
	embers.initial_velocity_min = 6.0
	embers.initial_velocity_max = 20.0
	embers.scale_amount_min = 1.4
	embers.scale_amount_max = 2.8
	embers.color = Color(1.0, 0.62, 0.2, 0.5)
	add_child(embers)

## Silhouette de pagode à étages, tout au fond.
func _build_pagoda(parent: Node, base: Vector2, seed_i: int) -> void:
	var c := Color(0.12, 0.1, 0.16, 0.9)
	var floors := 2 + seed_i % 3
	var w := 46.0
	var y := 0.0
	for f in floors:
		_poly(parent, PackedVector2Array([
			Vector2(-w, y), Vector2(w, y), Vector2(w - 6, y - 40), Vector2(-w + 6, y - 40),
		]), c, base)
		# Toit débordant retroussé.
		_poly(parent, PackedVector2Array([
			Vector2(-w - 12, y - 40), Vector2(w + 12, y - 40),
			Vector2(w - 2, y - 54), Vector2(-w + 2, y - 54),
		]), c, base)
		y -= 54.0
		w -= 9.0
	_poly(parent, PackedVector2Array([
		Vector2(-2, y), Vector2(2, y), Vector2(1, y - 18), Vector2(-1, y - 18),
	]), c, base)

# --- Terrasses ------------------------------------------------------------

## Terrasses de pierre taillée (peintes par PlatformPainter), avec un
## liseré de marches gravées sur le devant.
func _build_platforms() -> void:
	for i in PLATFORMS.size():
		var p: Vector2 = PLATFORMS[i]
		var hw: float = HALF_WIDTHS[i]
		var body := StaticBody2D.new()
		body.position = p
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(hw * 2.0, 100.0)
		shape.shape = rect
		body.add_child(shape)
		PlatformPainter.paint(body, hw, PLATFORM_THEME)
		# Marches gravées sur la corniche avant.
		var sx := -hw + 20.0
		while sx < hw - 20.0:
			_poly(body, PackedVector2Array([
				Vector2(sx, -40), Vector2(sx + 14, -40), Vector2(sx + 14, -34), Vector2(sx, -34),
			]), Color(0.36, 0.33, 0.3))
			sx += 34.0
		# Mousse aux angles.
		_poly(body, PackedVector2Array([
			Vector2(-hw, -50), Vector2(-hw + 26, -50), Vector2(-hw + 18, -56), Vector2(-hw - 2, -52),
		]), Color(0.32, 0.44, 0.28, 0.7))
		add_child(body)

## Faux spectrales suspendues aux poutres du temple, sur des terrasses
## dégagées (ni sanctuaire, ni checkpoint, ni brasero) : on passe dessous
## quand la lame est écartée. Amplitude réduite, adaptée aux terrasses.
func _build_hazards() -> void:
	for entry in [{"idx": 3, "ph": 0.0}, {"idx": 8, "ph": 0.9}]:
		var idx: int = entry["idx"]
		var pd := SpectralPendulum.new()
		pd.max_angle = 0.6
		pd.arm_len = 128.0
		pd.pivot_h = 150.0
		pd.speed = 1.8
		pd.phase = entry["ph"]
		pd.position = Vector2(PLATFORMS[idx].x, _surface_y(idx))
		add_child(pd)

## Lucioles : petites lueurs jaune-vert qui errent au-dessus des terrasses en
## trajectoire de Lissajous et respirent leur éclat, chacune à son rythme.
func _build_fireflies() -> void:
	var glow_tex: Texture2D = load("res://assets/mist.svg")
	var fi := 0
	for idx in range(1, PLATFORMS.size(), 2):
		var p: Vector2 = PLATFORMS[idx]
		var home := Vector2(p.x + float((fi * 47) % 120) - 60.0, _surface_y(idx) - 60.0 - float(fi % 3) * 24.0)
		var f := Node2D.new()
		f.position = home
		f.z_index = 4
		add_child(f)
		var halo := Sprite2D.new()
		halo.texture = glow_tex
		halo.modulate = Color(0.8, 1.0, 0.4, 0.5)
		halo.scale = Vector2(0.55, 0.55)
		f.add_child(halo)
		_poly(f, PackedVector2Array([
			Vector2(-1.5, 0), Vector2(0, -1.5), Vector2(1.5, 0), Vector2(0, 1.5),
		]), Color(0.95, 1.0, 0.7, 0.95))
		_fireflies.append({
			"node": f, "halo": halo, "home": home,
			"rx": 60.0 + float(fi % 3) * 24.0, "ry": 30.0 + float(fi % 2) * 16.0,
			"sx": 0.5 + float(fi % 4) * 0.12, "sy": 0.7 + float(fi % 3) * 0.15,
			"phase": float(fi) * 1.3,
		})
		fi += 1

## Flaques d'eau sur quelques terrasses : elles reflètent la lune d'un
## reflet pâle qui scintille (le reflet est un halo pulsant).
func _build_puddles() -> void:
	for idx in [2, 6, 10]:
		var p: Vector2 = PLATFORMS[idx]
		var pud := Node2D.new()
		pud.position = Vector2(p.x, _surface_y(idx) + 2.0)
		add_child(pud)
		_puddles.append(pud.position)
		var water := PackedVector2Array()
		var k := 0
		while k < 16:
			var a := k * TAU / 16.0
			water.append(Vector2(cos(a) * 48.0, sin(a) * 8.0))
			k += 1
		_poly(pud, water, Color(0.28, 0.36, 0.55, 0.35))
		_poly(pud, PackedVector2Array([
			Vector2(-48, -3), Vector2(48, -3), Vector2(46, -1), Vector2(-46, -1),
		]), Color(0.5, 0.56, 0.72, 0.4))
		var glint := Sprite2D.new()
		glint.texture = load("res://assets/mist.svg")
		glint.modulate = Color(0.82, 0.88, 1.0, 0.25)
		glint.scale = Vector2(1.7, 0.42)
		pud.add_child(glint)
		_halos.append(glint)

## Braseros sur trépied aux flammes dansantes, posés sur des terrasses.
func _build_braziers() -> void:
	var mist_tex: Texture2D = load("res://assets/mist.svg")
	for idx in BRAZIER_IDX:
		var p: Vector2 = PLATFORMS[idx]
		var hw: float = HALF_WIDTHS[idx]
		var b := Node2D.new()
		b.position = Vector2(p.x - hw + 40.0, _surface_y(idx))
		_poly(b, PackedVector2Array([
			Vector2(-10, 0), Vector2(-16, -26), Vector2(-12, -26),
		]), Color(0.12, 0.1, 0.11))
		_poly(b, PackedVector2Array([
			Vector2(10, 0), Vector2(16, -26), Vector2(12, -26),
		]), Color(0.12, 0.1, 0.11))
		_poly(b, PackedVector2Array([
			Vector2(-16, -26), Vector2(16, -26), Vector2(12, -36), Vector2(-12, -36),
		]), Color(0.2, 0.16, 0.15))
		var halo := Sprite2D.new()
		halo.texture = mist_tex
		halo.modulate = Color(1.0, 0.6, 0.25, 0.2)
		halo.scale = Vector2(2.6, 2.6)
		halo.position = Vector2(0, -46.0)
		b.add_child(halo)
		_halos.append(halo)
		var flame := Polygon2D.new()
		flame.position = Vector2(0, -36.0)
		flame.polygon = PackedVector2Array([
			Vector2(-7, 0), Vector2(7, 0), Vector2(5, -13), Vector2(0, -24), Vector2(-5, -13),
		])
		flame.color = Color(1.0, 0.58, 0.14)
		var inner := Polygon2D.new()
		inner.polygon = PackedVector2Array([
			Vector2(-3, 0), Vector2(3, 0), Vector2(0, -15),
		])
		inner.color = Color(1.0, 0.88, 0.42)
		flame.add_child(inner)
		b.add_child(flame)
		_flames.append(flame)
		add_child(b)

## Points de contrôle : lanterne de pierre (tōrō) encadrée de deux statues
## gardiennes ; la flamme s'allume en vert au passage d'Eneko.
func _build_checkpoints() -> void:
	for idx in CHECKPOINT_IDX:
		var p: Vector2 = PLATFORMS[idx]
		var hw: float = HALF_WIDTHS[idx]
		var surf := _surface_y(idx)
		_build_statue(Vector2(p.x - hw + 34.0, surf), 1.0)
		_build_statue(Vector2(p.x + hw - 34.0, surf), -1.0)
		var cp := Area2D.new()
		cp.position = Vector2(p.x, surf - 70.0)
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(60, 120)
		shape.shape = rect
		cp.add_child(shape)
		var stone := Color(0.4, 0.38, 0.4)
		var stone_dark := Color(0.3, 0.28, 0.3)
		_poly(cp, PackedVector2Array([
			Vector2(-16, 70), Vector2(16, 70), Vector2(13, 60), Vector2(-13, 60),
		]), stone_dark)
		_poly(cp, PackedVector2Array([
			Vector2(-5, 60), Vector2(5, 60), Vector2(5, 6), Vector2(-5, 6),
		]), stone)
		_poly(cp, PackedVector2Array([
			Vector2(-14, 6), Vector2(14, 6), Vector2(14, -22), Vector2(-14, -22),
		]), stone)
		var flag := _poly(cp, PackedVector2Array([
			Vector2(-8, 0), Vector2(8, 0), Vector2(8, -16), Vector2(-8, -16),
		]), Color(0.95, 0.66, 0.28, 0.9))
		_poly(cp, PackedVector2Array([
			Vector2(-20, -22), Vector2(20, -22), Vector2(12, -34), Vector2(-12, -34),
		]), stone_dark)
		_poly(cp, PackedVector2Array([
			Vector2(-4, -34), Vector2(4, -34), Vector2(2, -42), Vector2(-2, -42),
		]), stone)
		add_child(cp)
		cp.body_entered.connect(_on_checkpoint_body_entered.bind(cp, flag))

## Statue gardienne (komainu stylisé) posée sur une terrasse.
func _build_statue(pos: Vector2, side: float) -> void:
	var st := Node2D.new()
	st.position = pos
	st.scale = Vector2(side, 1.0)
	add_child(st)
	var stone := Color(0.42, 0.4, 0.36)
	var dark := Color(0.3, 0.28, 0.25)
	_poly(st, PackedVector2Array([
		Vector2(-16, 0), Vector2(16, 0), Vector2(13, -8), Vector2(-13, -8),
	]), dark)
	_poly(st, PackedVector2Array([
		Vector2(-11, -8), Vector2(11, -8), Vector2(9, -24), Vector2(-2, -28), Vector2(-11, -18),
	]), stone)
	_poly(st, PackedVector2Array([
		Vector2(0, -28), Vector2(12, -28), Vector2(12, -40), Vector2(0, -40),
	]), stone)
	_poly(st, PackedVector2Array([
		Vector2(3, -32), Vector2(7, -32), Vector2(7, -36), Vector2(3, -36),
	]), Color(1.0, 0.7, 0.3, 0.9))

func _build_traps() -> void:
	for idx in TRAP_IDX:
		var p: Vector2 = PLATFORMS[idx]
		var hw: float = HALF_WIDTHS[idx]
		var trap := Area2D.new()
		trap.position = Vector2(p.x + hw * 0.4, _surface_y(idx) - 4.0)
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(44, 24)
		shape.shape = rect
		trap.add_child(shape)
		_poly(trap, PackedVector2Array([
			Vector2(-22, 18), Vector2(22, 18), Vector2(22, 6), Vector2(-22, 6),
		]), STONE_DARK)
		for k in 3:
			var ox := -16.0 + k * 16.0
			_poly(trap, PackedVector2Array([
				Vector2(ox - 5, 6), Vector2(ox + 5, 6), Vector2(ox, -14),
			]), Color(0.55, 0.53, 0.5))
			_poly(trap, PackedVector2Array([
				Vector2(ox - 2, 2), Vector2(ox + 2, 2), Vector2(ox, -12),
			]), Color(0.68, 0.66, 0.62))
		add_child(trap)
		trap.body_entered.connect(_on_trap_body_entered)

## Torii doré du sanctuaire, au sommet de l'escalier.
func _build_goal() -> void:
	var p: Vector2 = PLATFORMS[GOAL_IDX]
	var goal := Area2D.new()
	goal.position = Vector2(p.x, _surface_y(GOAL_IDX) - 70.0)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(60, 140)
	shape.shape = rect
	goal.add_child(shape)
	var glow := Sprite2D.new()
	glow.texture = load("res://assets/mist.svg")
	glow.modulate = Color(0.9, 0.9, 1.0, 0.5)
	glow.scale = Vector2(4.5, 4.5)
	goal.add_child(glow)
	_poly(goal, PackedVector2Array([Vector2(-40, -60), Vector2(40, -60), Vector2(40, 66), Vector2(-40, 66)]), Color(0.85, 0.85, 1.0, 0.2))
	_poly(goal, PackedVector2Array([Vector2(-28, -55), Vector2(-20, -55), Vector2(-20, 70), Vector2(-28, 70)]), CLOTH)
	_poly(goal, PackedVector2Array([Vector2(20, -55), Vector2(28, -55), Vector2(28, 70), Vector2(20, 70)]), CLOTH)
	_poly(goal, PackedVector2Array([Vector2(-42, -70), Vector2(42, -70), Vector2(38, -58), Vector2(-38, -58)]), Color(0.42, 0.11, 0.08))
	_poly(goal, PackedVector2Array([Vector2(-32, -46), Vector2(32, -46), Vector2(32, -38), Vector2(-32, -38)]), CLOTH)
	add_child(goal)
	Atmosphere.breathe(glow)
	goal.body_entered.connect(_on_goal_body_entered)

func _spawn_entities() -> void:
	for idx in PATROL_IDX:
		var e := PATROL_SCENE.instantiate()
		e.patrol_distance = maxf(30.0, HALF_WIDTHS[idx] - 45.0)
		e.position = _stand_y(idx)
		add_child(e)
	for idx in SHADOW_IDX:
		var s := SHADOW_SCENE.instantiate()
		s.position = _stand_y(idx)
		add_child(s)
	for idx in ELITE_IDX:
		var el := SHADOW_SCENE.instantiate()
		el.position = _stand_y(idx)
		add_child(el)
		el.make_elite()
	for idx in SPIRIT_IDX:
		var sp := SPIRIT_SCENE.instantiate()
		sp.position = _stand_y(idx) + Vector2(0, -85.0)
		add_child(sp)
	# Sanctuaire de Léonie sur une terrasse dégagée (aucun ennemi ni piège).
	var sp7: Vector2 = PLATFORMS[LEONIE_IDX]
	PlatformPainter.build_sanctuary(self, sp7.x, _surface_y(LEONIE_IDX))
	var leonie := LEONIE_SCENE.instantiate()
	leonie.position = Vector2(sp7.x, _surface_y(LEONIE_IDX) - 23.0)
	leonie.set_lines(LEONIE_LINES)
	add_child(leonie)
	for o in ORBS:
		var orb := ORB_SCENE.instantiate()
		orb.position = o
		add_child(orb)

## Répliques d'ambiance au fil du niveau (non bloquantes).
func _setup_ambient() -> void:
	var amb := AmbientDialogue.new()
	add_child(amb)
	amb.add_line(self, 1010.0, "Eneko", "Ce temple veillait sur la vallée depuis mille ans...")
	amb.add_line(self, 2470.0, "Murmure", "Retourne d'où tu viens, mortel... ici règnent les Ombres.")
	amb.add_line(self, 3980.0, "Eneko", "Leurs murmures ne m'arrêteront pas. Je monte.")

func _setup_audio() -> void:
	var wind := AudioStreamPlayer.new()
	wind.stream = load("res://assets/sfx/wind.wav")
	wind.volume_db = -20.0
	wind.pitch_scale = 0.7
	add_child(wind)
	wind.finished.connect(wind.play)
	wind.play()
	sfx_win = AudioStreamPlayer.new()
	sfx_win.stream = load("res://assets/sfx/win.wav")
	sfx_win.volume_db = -4.0
	add_child(sfx_win)

# --- Déroulement ----------------------------------------------------------

func _on_checkpoint_body_entered(body: Node2D, cp: Area2D, flag: Polygon2D) -> void:
	if body == player:
		if not cp.has_meta("lit"):
			cp.set_meta("lit", true)
			Atmosphere.spark_burst(self, cp.global_position, Color(0.5, 1.0, 0.6))
		player.set_checkpoint(Vector2(cp.global_position.x, cp.global_position.y + 30.0))
		flag.color = Color(0.4, 0.9, 0.5, 0.95)

func _on_trap_body_entered(body: Node2D) -> void:
	if body == player and body.has_method("take_damage"):
		body.take_damage(1, body.global_position + Vector2(0, 40))

func _on_goal_body_entered(body: Node2D) -> void:
	_reach_goal(body, LEVEL_ID, sfx_win)
