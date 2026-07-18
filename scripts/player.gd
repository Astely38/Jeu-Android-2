extends CharacterBody2D
## Eneko, l'apprenti sabreur. Déplacement/saut/attaque au sabre avec un
## AnimatedSprite2D piloté par une machine à états (idle / run / jump /
## attack / hurt). Barre de vie (cœurs), énergie du sabre, invincibilité,
## recul et point de contrôle.

const SPEED := 220.0
const JUMP_VELOCITY := -480.0
const GRAVITY := 980.0
const ATTACK_DURATION := 0.42
const HURT_LOCK := 0.28
const MAX_HEALTH := 3
const INVULN_TIME := 1.0
const KNOCKBACK_SPEED := 240.0
const KNOCKBACK_TIME := 0.18
const HEART_BASE_SCALE := Vector2(1.1, 1.1)
const SAMURAI := "res://assets/character/samurai/"
## Confort de saut : tolérance après avoir quitté un rebord (coyote),
## mémorisation d'un saut demandé juste avant l'atterrissage (buffer),
## et saut coupé si le bouton est relâché tôt (hauteur variable).
const COYOTE_TIME := 0.12
const JUMP_BUFFER := 0.15
const JUMP_CUT_VELOCITY := -160.0
## Double Saut spirituel (bénédiction de Léonie, débloqué après le Ch. I) :
## un second bond en plein vol, un peu moins puissant, escorté d'un halo.
const AIR_JUMP_VELOCITY := -430.0
const ANIM_BASE_SCALE := Vector2(1.0, 1.0)
## Ruée du sabreur : élan horizontal éclair avec images rémanentes et
## invincibilité, limité par un temps de recharge. La traversée des
## ennemis persiste un court instant APRÈS l'élan : sans ça, Eneko
## redevenait solide à l'intérieur du boss et la physique le recrachait
## du côté d'où il venait.
const DASH_SPEED := 560.0
const DASH_TIME := 0.2
const DASH_GHOST_EXTRA := 0.18
const DASH_COOLDOWN := 0.9

## Fil Spirituel : Eneko lance un fil vers un ancrage lumineux (nœuds du
## groupe « spirit_anchor ») et s'y hisse d'un trait. Portée, vitesse de
## traction, petit rebond à l'arrivée et délai avant de relancer.
const GRAPPLE_RANGE := 360.0
const GRAPPLE_SPEED := 780.0
const GRAPPLE_MAX_TIME := 0.6
const GRAPPLE_POP := -260.0
const GRAPPLE_COOLDOWN := 0.35

var moving_left := false
var moving_right := false
var attacking := false
var facing := 1.0
var health := MAX_HEALTH
var invuln := 0.0
var knockback := 0.0
var lock_timer := 0.0
## Frappe en ruée : fenêtre pendant/juste après une ruée où l'attaque devient
## un coup tournant élargi qui inflige un dégât supplémentaire.
var _heavy := false
var _dash_strike_window := 0.0
## Cibles déjà touchées par le coup de sabre en cours (évite les doublons).
var _hit_bodies: Array = []
var anim_time := 0.0
var orbs := 0
var start_position := Vector2.ZERO
var _cur := ""
var _dead := false
## Force horizontale imposée par le niveau (rafales de vent du niveau 4).
var wind_force := 0.0
## Poussière soulevée par la course (construite en code dans _ready).
var _dust: CPUParticles2D
var _land_dust: CPUParticles2D
var _orb_burst: CPUParticles2D
var _coyote := 0.0
var _jump_buffer := 0.0
var _touch_jump_held := false
## Double Saut : nombre de sauts aériens déjà utilisés depuis le dernier
## contact au sol, et nombre autorisé (1 si le pouvoir est débloqué, 0 sinon).
var _air_jumps := 0
var _max_air := 0
## Front montant de la touche de saut clavier (le double saut ne doit partir
## que sur une nouvelle pression, pas tant que la touche est maintenue).
var _kb_jump_prev := false
var _was_on_floor := false
var _fall_speed := 0.0
var _shake := 0.0
## Bruitages créés en code : atterrissage, impact sur un ennemi.
var _sfx_land: AudioStreamPlayer
var _sfx_hit: AudioStreamPlayer
var _dash_timer := 0.0
var _dash_cd := 0.0
## Fil Spirituel : état de la traction en cours.
var _grappling := false
var _grapple_timer := 0.0
var _grapple_cd := 0.0
var _grapple_target := Vector2.ZERO
var _thread: Line2D
var _ghost_timer := 0.0
## Fenêtre de traversée des ennemis (couvre l'élan + une marge de sortie).
var _ghost_through := 0.0
var _pan_tween: Tween
var _pause_layer: CanvasLayer
## Bénédiction de Léonie : le prochain coup encaissé est annulé.
var blessed := false
var _bless_aura: Sprite2D
## Combo : esprits tranchés coup sur coup. La série grimpe tant qu'un
## nouvel esprit tombe dans la fenêtre et qu'Eneko n'encaisse rien.
const COMBO_WINDOW := 5.0
var _combo := 0
var _combo_timer := 0.0
## Bref éclat du feu follet quand un éclat de lumière est ramassé.
var _orb_flash := 0.0
var _combo_label: Label
## Vignette rouge de lisibilité : éclat bref quand Eneko est touché, et
## pulsation douce et continue quand il ne reste qu'un seul cœur (danger).
var _vignette: TextureRect
var _vignette_flash := 0.0

@onready var attack_area: Area2D = $AttackArea
@onready var attack_shape: CollisionShape2D = $AttackArea/CollisionShape2D
@onready var anim: AnimatedSprite2D = $Anim
@onready var orb_label: Label = $HUD/OrbCount
@onready var time_label: Label = $HUD/TimeLabel
@onready var heart_hint: Label = $HUD/HeartHint
@onready var game_over_label: Label = $HUD/GameOverLabel
@onready var hearts: Array = [$HUD/Heart1, $HUD/Heart2, $HUD/Heart3]
@onready var sfx_jump: AudioStreamPlayer = $SfxJump
@onready var sfx_slash: AudioStreamPlayer = $SfxSlash
@onready var sfx_hurt: AudioStreamPlayer = $SfxHurt
@onready var sfx_orb: AudioStreamPlayer = $SfxOrb
@onready var sfx_dash: AudioStreamPlayer = $SfxDash
@onready var sfx_checkpoint: AudioStreamPlayer = $SfxCheckpoint
@onready var camera: Camera2D = $Camera2D
@onready var _dash_icons: Array = [$HUD/DashButton/Icon, $HUD/DashButton/Icon2]

func _ready() -> void:
	# Garde-fou : un rechargement de scène pendant un hit-stop ou un
	# ralenti ne doit jamais laisser le temps figé.
	Engine.time_scale = 1.0
	add_to_group("player")
	# Double Saut spirituel : autorisé une fois le Chapitre I terminé.
	_max_air = 1 if SaveManager.double_jump_unlocked() else 0
	start_position = position
	attack_area.monitoring = false
	attack_area.body_entered.connect(_on_attack_area_body_entered)
	attack_area.area_entered.connect(_on_attack_area_area_entered)
	_build_combo_label()
	_add_contact_shadow(30.0)
	add_child(GuardianWisp.new())  # le feu follet de Léonie veille sur Eneko
	_sfx_land = _make_sfx("res://assets/sfx/land.wav", -6.0)
	_sfx_hit = _make_sfx("res://assets/sfx/enemy_hit.wav", -4.0)
	# Cœurs supplémentaires (mode détente) puis vie de départ au maximum.
	_ensure_hearts()
	health = _max_health()
	if Challenge.kensei:
		_build_kensei_badge()
	anim.sprite_frames = SpriteSheet.build([
		{"name": "idle", "path": SAMURAI + "Idle.png", "frames": 6, "fps": 8.0, "loop": true},
		{"name": "run", "path": SAMURAI + "Run.png", "frames": 8, "fps": 13.0, "loop": true},
		{"name": "jump", "path": SAMURAI + "Jump.png", "frames": 12, "fps": 14.0, "loop": false},
		{"name": "attack", "path": SAMURAI + "Attack_1.png", "frames": 6, "fps": 14.0, "loop": false},
		{"name": "hurt", "path": SAMURAI + "Hurt.png", "frames": 2, "fps": 9.0, "loop": false},
	])
	_play("idle")
	orb_label.text = "x0"
	_build_vignette()
	_build_thread()
	_update_hearts()
	_update_heart_hint()

	# Petits nuages de poussière aux pieds pendant la course.
	_dust = CPUParticles2D.new()
	_dust.position = Vector2(0, 22)
	_dust.amount = 10
	_dust.lifetime = 0.45
	_dust.local_coords = false
	_dust.direction = Vector2(0, -1)
	_dust.spread = 40.0
	_dust.gravity = Vector2(0, -14)
	_dust.initial_velocity_min = 8.0
	_dust.initial_velocity_max = 22.0
	_dust.scale_amount_min = 1.6
	_dust.scale_amount_max = 3.0
	_dust.color = Color(0.78, 0.72, 0.6, 0.45)
	_dust.emitting = false
	add_child(_dust)

	# Bouffée de poussière à l'atterrissage (une seule salve à la fois).
	_land_dust = CPUParticles2D.new()
	_land_dust.position = Vector2(0, 22)
	_land_dust.amount = 14
	_land_dust.lifetime = 0.4
	_land_dust.one_shot = true
	_land_dust.explosiveness = 1.0
	_land_dust.local_coords = false
	_land_dust.emitting = false
	_land_dust.direction = Vector2(0, -1)
	_land_dust.spread = 75.0
	_land_dust.gravity = Vector2(0, 180)
	_land_dust.initial_velocity_min = 30.0
	_land_dust.initial_velocity_max = 75.0
	_land_dust.scale_amount_min = 1.5
	_land_dust.scale_amount_max = 3.0
	_land_dust.color = Color(0.8, 0.74, 0.62, 0.55)
	add_child(_land_dust)

	# Éclat d'étincelles bleutées quand un orbe est ramassé.
	_orb_burst = CPUParticles2D.new()
	_orb_burst.position = Vector2(0, -10)
	_orb_burst.amount = 12
	_orb_burst.lifetime = 0.5
	_orb_burst.one_shot = true
	_orb_burst.explosiveness = 1.0
	_orb_burst.local_coords = false
	_orb_burst.emitting = false
	_orb_burst.spread = 180.0
	_orb_burst.gravity = Vector2.ZERO
	_orb_burst.initial_velocity_min = 40.0
	_orb_burst.initial_velocity_max = 90.0
	_orb_burst.scale_amount_min = 1.2
	_orb_burst.scale_amount_max = 2.2
	_orb_burst.color = Color(0.6, 0.95, 1.0, 0.9)
	add_child(_orb_burst)

func _physics_process(delta: float) -> void:
	# Invincibilité : clignotement.
	if invuln > 0.0:
		invuln -= delta
		anim.modulate.a = 0.35 if int(invuln * 12.0) % 2 == 0 else 1.0
	else:
		anim.modulate.a = 1.0
	# Fenêtre de combo : expire si Eneko reste trop longtemps sans trancher.
	if _combo_timer > 0.0:
		_combo_timer -= delta
		if _combo_timer <= 0.0:
			_end_combo()
	if _orb_flash > 0.0:
		_orb_flash -= delta
	_update_vignette(delta)

	_dash_strike_window = maxf(0.0, _dash_strike_window - delta)

	# Le coup de sabre touche aussi les cibles DÉJÀ au contact (pas seulement
	# celles qui entrent dans la zone) — indispensable face au boss immobile.
	if attacking:
		for b in attack_area.get_overlapping_bodies():
			_try_hit(b)

	# Verrou d'animation (attaque / touché).
	if lock_timer > 0.0:
		lock_timer -= delta
		if lock_timer <= 0.0 and attacking:
			attacking = false
			attack_area.monitoring = false
			# Restaure la portée normale après une frappe en ruée.
			attack_shape.scale = Vector2.ONE
			_heavy = false

	# Ruée du sabreur : trajectoire horizontale figée, gravité suspendue,
	# images rémanentes semées derrière Eneko.
	_dash_cd = maxf(0.0, _dash_cd - delta)
	# La solidité face aux ennemis ne revient qu'une fois la fenêtre de
	# traversée épuisée (élan + marge), pour être sûr d'être RESSORTI.
	if _ghost_through > 0.0:
		_ghost_through -= delta
		if _ghost_through <= 0.0:
			set_collision_mask_value(2, true)
	_grapple_cd = maxf(0.0, _grapple_cd - delta)
	# Fil Spirituel : traction vers l'ancrage, prioritaire sur tout le reste.
	if _grappling:
		_grapple_timer += delta
		var to: Vector2 = _grapple_target - global_position
		if to.length() <= 28.0 or _grapple_timer > GRAPPLE_MAX_TIME:
			_end_grapple()
		else:
			velocity = to.normalized() * GRAPPLE_SPEED
			move_and_slide()
			_update_thread()
			_play("jump")
			# Bloqué par un mur en route : on coupe le fil.
			if get_slide_collision_count() > 0 and to.length() > 44.0:
				_end_grapple()
			return
		return

	if _dash_timer > 0.0:
		_dash_timer -= delta
		velocity = Vector2(facing * DASH_SPEED, 0)
		move_and_slide()
		_ghost_timer -= delta
		if _ghost_timer <= 0.0:
			_ghost_timer = 0.045
			_spawn_ghost()
		_play("run")
		return

	if not is_on_floor():
		velocity.y += GRAVITY * delta
		_fall_speed = velocity.y
		# Saut à hauteur variable : relâcher le bouton coupe l'ascension.
		if velocity.y < JUMP_CUT_VELOCITY and not _jump_held():
			velocity.y = JUMP_CUT_VELOCITY

	if knockback > 0.0:
		knockback -= delta
		velocity.x = move_toward(velocity.x, 0.0, SPEED * 3.0 * delta)
	else:
		var direction := 0.0
		if moving_left or Input.is_physical_key_pressed(KEY_LEFT) or Input.is_physical_key_pressed(KEY_A):
			direction -= 1.0
		if moving_right or Input.is_physical_key_pressed(KEY_RIGHT) or Input.is_physical_key_pressed(KEY_D):
			direction += 1.0
		velocity.x = direction * SPEED + wind_force
		if direction != 0.0:
			_set_facing(direction)

	move_and_slide()

	if _dust != null:
		_dust.emitting = is_on_floor() and absf(velocity.x) > 40.0

	# Coyote time, buffer de saut et impact d'atterrissage.
	_jump_buffer = maxf(0.0, _jump_buffer - delta)
	if is_on_floor():
		_coyote = COYOTE_TIME
		_air_jumps = 0  # le contact au sol rend le double saut
		if not _was_on_floor:
			_on_landed()
		if _jump_buffer > 0.0:
			_jump_buffer = 0.0
			_do_jump()
	else:
		_coyote = maxf(0.0, _coyote - delta)
	_was_on_floor = is_on_floor()

	# Secousse de caméra (dégâts, coups de sabre) qui s'amortit vite.
	# Accessibilité : supprimée si le joueur a coupé les secousses d'écran.
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 30.0)
		if SaveManager.setting_on("shake"):
			camera.offset = Vector2(randf_range(-_shake, _shake), randf_range(-_shake, _shake))
		else:
			camera.offset = Vector2.ZERO
	elif camera.offset != Vector2.ZERO:
		camera.offset = Vector2.ZERO

	# Saut clavier sur FRONT MONTANT : indispensable pour le double saut, qui
	# ne doit pas s'enchaîner tant que la touche reste enfoncée.
	var kb_jump := Input.is_physical_key_pressed(KEY_UP) or Input.is_physical_key_pressed(KEY_SPACE)
	if kb_jump and not _kb_jump_prev:
		jump()
	_kb_jump_prev = kb_jump
	if Input.is_physical_key_pressed(KEY_X):
		attack()
	if Input.is_physical_key_pressed(KEY_SHIFT) or Input.is_physical_key_pressed(KEY_C):
		dash()
	if Input.is_physical_key_pressed(KEY_E) or Input.is_physical_key_pressed(KEY_F):
		grapple()

	_update_animation()
	_animate(delta)

## Choisit l'animation selon l'état (sauf pendant un verrou attaque/touché).
func _update_animation() -> void:
	if lock_timer > 0.0:
		return
	if not is_on_floor():
		_play("jump")
	elif absf(velocity.x) > 12.0:
		_play("run")
	else:
		_play("idle")

func _play(n: String) -> void:
	if _cur != n:
		_cur = n
		anim.play(n)

func _animate(delta: float) -> void:
	anim_time += delta
	var pulse := 1.0 + sin(anim_time * 3.0) * 0.04
	for h in hearts:
		h.scale = HEART_BASE_SCALE * pulse
	# Chronomètre du défi, visible en haut de l'écran.
	if time_label != null:
		var tsec := int(Challenge.get_time_elapsed())
		time_label.text = "%d:%02d" % [tsec / 60, tsec % 60]
	# L'icône de la ruée s'éteint pendant la recharge.
	var dash_ready := _dash_cd <= 0.0
	for ic in _dash_icons:
		ic.modulate.a = 0.9 if dash_ready else 0.25

func _set_facing(dir: float) -> void:
	facing = dir
	anim.flip_h = dir < 0.0
	attack_area.position.x = 26.0 * dir

func jump() -> void:
	if is_on_floor() or _coyote > 0.0:
		_do_jump()
	elif _air_jumps < _max_air:
		# Double Saut spirituel : un second bond en plein vol.
		_air_jumps += 1
		_do_air_jump()
	else:
		# Trop tôt : on retient la demande, le saut partira à l'atterrissage.
		_jump_buffer = JUMP_BUFFER

func _do_jump() -> void:
	velocity.y = JUMP_VELOCITY
	_coyote = 0.0
	Sfx.varied(sfx_jump, 0.9, 1.1)
	# Étirement vertical au décollage (squash & stretch).
	anim.scale = Vector2(0.82, 1.18)
	var t := create_tween()
	t.tween_property(anim, "scale", ANIM_BASE_SCALE, 0.18)

## Double Saut : relance verticale un peu plus douce, son plus aigu, et un
## halo doré (la lumière de Léonie) qui s'évase sous les pieds d'Eneko.
func _do_air_jump() -> void:
	velocity.y = AIR_JUMP_VELOCITY
	Sfx.varied(sfx_jump, 1.18, 1.32)
	anim.scale = Vector2(0.8, 1.22)
	var t := create_tween()
	t.tween_property(anim, "scale", ANIM_BASE_SCALE, 0.18)
	_spiritual_burst()
	SaveManager.vibrate(10)

## Halo d'envol : un anneau de lumière qui s'agrandit et s'efface, plus un
## éclat d'étincelles dorées. Rattaché au parent (survit au mouvement d'Eneko).
func _spiritual_burst() -> void:
	var host := get_parent()
	if host == null:
		return
	var ring := Line2D.new()
	ring.width = 3.0
	ring.default_color = Color(1.0, 0.88, 0.55, 0.85)
	var pts := PackedVector2Array()
	for i in 21:
		var a := i * TAU / 20.0
		pts.append(Vector2(cos(a) * 20.0, sin(a) * 7.0))
	ring.points = pts
	ring.global_position = global_position + Vector2(0, 22)
	ring.z_index = 4
	host.add_child(ring)
	var tw := ring.create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "scale", Vector2(2.8, 2.8), 0.35)
	tw.tween_property(ring, "modulate:a", 0.0, 0.35)
	tw.chain().tween_callback(ring.queue_free)
	Atmosphere.spark_burst(host, global_position + Vector2(0, 8), Color(1.0, 0.85, 0.5))

## Crée un lecteur de bruitage en code (routé vers le bus « Sons » par le
## gestionnaire de musique) et le rattache à Eneko.
func _make_sfx(path: String, vol_db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = load(path)
	p.volume_db = vol_db
	add_child(p)
	return p

## Atterrissage : écrasement du sprite + bouffée de poussière si la chute
## était rapide.
func _on_landed() -> void:
	if _fall_speed > 120.0:
		Sfx.varied(_sfx_land, 0.94, 1.08)
	if _fall_speed > 300.0:
		anim.scale = Vector2(1.19, 0.78)
		var t := create_tween()
		t.tween_property(anim, "scale", ANIM_BASE_SCALE, 0.15)
		_land_dust.restart()
	# Réception franche : une onde de poussière s'étale au sol.
	if _fall_speed > 520.0:
		_spawn_landing_ring()
		_shake = maxf(_shake, 3.0)

## Anneau de poussière qui s'élargit et s'efface au point d'atterrissage
## (posé sur le niveau : il reste au sol pendant qu'Eneko repart).
func _spawn_landing_ring() -> void:
	var ring := Line2D.new()
	ring.width = 4.0
	ring.default_color = Color(0.88, 0.83, 0.68, 0.55)
	var pts := PackedVector2Array()
	for k in 22:
		var a := k * TAU / 22.0
		pts.append(Vector2(cos(a) * 11.0, sin(a) * 4.0))
	pts.append(pts[0])
	ring.points = pts
	ring.global_position = global_position + Vector2(0, 26.0)
	get_parent().add_child(ring)
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(ring, "scale", Vector2(4.6, 4.6), 0.42)
	t.tween_property(ring, "modulate:a", 0.0, 0.42)
	t.chain().tween_callback(ring.queue_free)

func _jump_held() -> bool:
	return _touch_jump_held \
		or Input.is_physical_key_pressed(KEY_UP) \
		or Input.is_physical_key_pressed(KEY_SPACE)

## Ruée du sabreur : élan éclair dans la direction du regard, invincible
## pendant l'élan, contre DASH_COST d'énergie.
func dash() -> void:
	if _dash_timer > 0.0 or _dash_cd > 0.0 or _dead:
		return
	_dash_timer = DASH_TIME
	_dash_cd = DASH_COOLDOWN
	_ghost_timer = 0.0
	_ghost_through = DASH_TIME + DASH_GHOST_EXTRA
	invuln = maxf(invuln, DASH_TIME + DASH_GHOST_EXTRA + 0.05)
	velocity.y = 0.0
	# Pendant la ruée (et la marge de sortie), Eneko TRAVERSE les ennemis
	# (couche 2) : l'esquive passe au travers des charges du Gardien.
	set_collision_mask_value(2, false)
	# Attaquer pendant cette fenêtre déclenche la frappe en ruée (coup lourd).
	_dash_strike_window = DASH_TIME + 0.3
	Sfx.varied(sfx_dash, 0.95, 1.08)
	_spawn_speed_lines()

## Fil Spirituel : file d'un trait vers l'ancrage lumineux le mieux placé
## (devant/au-dessus, dans la portée). Sans cible, ne fait rien.
func grapple() -> void:
	if _grappling or _grapple_cd > 0.0 or _dead or lock_timer > 0.0 or _dash_timer > 0.0:
		return
	var anchor := _find_anchor()
	if anchor == null:
		return
	_grappling = true
	_grapple_timer = 0.0
	_grapple_cd = GRAPPLE_COOLDOWN
	_grapple_target = anchor.global_position
	# Pendant la traction, on traverse les ennemis et on ignore la gravité.
	set_collision_mask_value(2, false)
	invuln = maxf(invuln, 0.12)
	_thread.visible = true
	_update_thread()
	if anchor.has_method("ping"):
		anchor.ping()
	Sfx.varied(sfx_dash, 1.12, 1.22)

## Meilleur ancrage à portée : privilégie ce qui est devant et en hauteur, à
## distance décroissante.
func _find_anchor() -> Node2D:
	var best: Node2D = null
	var best_score := -999.0
	for a in get_tree().get_nodes_in_group("spirit_anchor"):
		if not (a is Node2D) or not is_instance_valid(a):
			continue
		var to: Vector2 = (a as Node2D).global_position - global_position
		var d := to.length()
		if d > GRAPPLE_RANGE or d < 14.0:
			continue
		var dir := to / d
		# Biais : devant (selon le regard) + vers le haut, moins la distance.
		var score := dir.x * facing * 0.4 + (-dir.y) * 0.7 + (1.0 - d / GRAPPLE_RANGE)
		if score > best_score:
			best_score = score
			best = a
	return best

func _end_grapple() -> void:
	if not _grappling:
		return
	_grappling = false
	_thread.visible = false
	set_collision_mask_value(2, true)
	# Petit rebond à l'arrivée + élan conservé, et le double saut se recharge.
	velocity.y = GRAPPLE_POP
	velocity.x = facing * SPEED * 0.5
	_air_jumps = 0
	Atmosphere.spark_burst(self, _grapple_target, Color(0.6, 0.92, 1.0))

## Fil visible entre Eneko et l'ancrage (coordonnées locales, se met à jour
## chaque frame de traction).
func _build_thread() -> void:
	_thread = Line2D.new()
	_thread.width = 2.6
	_thread.default_color = Color(0.7, 0.95, 1.0, 0.9)
	_thread.z_index = 2
	_thread.visible = false
	add_child(_thread)

func _update_thread() -> void:
	if _thread == null:
		return
	_thread.points = PackedVector2Array([
		Vector2(0, -8), to_local(_grapple_target),
	])

## Lignes de vitesse : traits horizontaux qui fusent derrière Eneko au
## départ de la Ruée, glissent vers l'arrière et s'effacent — sensation
## de vitesse pure.
func _spawn_speed_lines() -> void:
	for i in 5:
		var line := Polygon2D.new()
		var len_x := 26.0 + float(i % 3) * 14.0
		line.polygon = PackedVector2Array([
			Vector2(0, -1.4), Vector2(len_x, -0.6), Vector2(len_x, 0.6), Vector2(0, 1.4),
		])
		line.color = Color(0.7, 0.9, 1.0, 0.55)
		var oy := -30.0 + float(i) * 14.0
		line.position = Vector2(-facing * 18.0, oy)
		line.scale.x = -facing
		add_child(line)
		var t := line.create_tween()
		t.set_parallel(true)
		t.tween_property(line, "position:x", line.position.x - facing * 60.0, 0.28)
		t.tween_property(line, "modulate:a", 0.0, 0.28)
		t.chain().tween_callback(line.queue_free)

## Image rémanente bleutée semée pendant la ruée, qui s'estompe vite.
func _spawn_ghost() -> void:
	var tex := anim.sprite_frames.get_frame_texture(anim.animation, anim.frame)
	if tex == null:
		return
	var g := Sprite2D.new()
	g.texture = tex
	g.global_position = anim.global_position
	g.flip_h = anim.flip_h
	g.scale = anim.scale
	g.texture_filter = anim.texture_filter
	g.modulate = Color(0.55, 0.85, 1.0, 0.55)
	g.z_index = z_index - 1
	get_parent().add_child(g)
	var t := g.create_tween()
	t.tween_property(g, "modulate:a", 0.0, 0.3)
	t.finished.connect(g.queue_free)

## Micro-arrêt du temps à l'impact d'un coup qui porte (le "crunch" des
## jeux d'action). Durée mesurée en temps réel, insensible au time_scale.
func _hit_stop() -> void:
	if Engine.time_scale < 1.0:
		return
	Engine.time_scale = 0.15
	await get_tree().create_timer(0.06, true, false, true).timeout
	Engine.time_scale = 1.0

## Panoramique d'introduction : la caméra part d'un point fort du niveau
## (torii, sommet, arène du boss...) et glisse jusqu'à Eneko. Le niveau
## l'appelle en fin de _ready ; Eneko est figé pendant le survol.
## Ne joue qu'une fois par niveau et par session (une mort qui recharge
## le niveau redonne la main immédiatement) ; passable d'un tap.
func intro_pan(from: Vector2, duration := 1.8) -> void:
	if not Challenge.should_play_intro():
		return
	set_physics_process(false)
	var smoothing := camera.position_smoothing_enabled
	camera.position_smoothing_enabled = false
	camera.top_level = true
	camera.global_position = from
	_pan_tween = create_tween()
	_pan_tween.tween_property(camera, "global_position", global_position + Vector2(0, -40), duration) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await _pan_tween.finished
	_pan_tween = null
	camera.top_level = false
	camera.position = Vector2.ZERO
	camera.position_smoothing_enabled = smoothing
	camera.reset_smoothing()
	set_physics_process(true)
	# Le chrono du défi ne démarre qu'à la prise en main.
	Challenge.restart_timer()

## Un tap (ou une touche) pendant le survol d'introduction le termine
## immédiatement en sautant le tween à sa fin.
func _input(event: InputEvent) -> void:
	if _pan_tween == null or not _pan_tween.is_valid() or not _pan_tween.is_running():
		return
	if (event is InputEventScreenTouch or event is InputEventKey) and event.is_pressed():
		_pan_tween.custom_step(999.0)

func attack() -> void:
	if attacking or lock_timer > 0.0:
		return
	attacking = true
	lock_timer = ATTACK_DURATION
	attack_area.monitoring = true
	_hit_bodies.clear()
	# Frappe en ruée : si l'attaque suit de près une ruée, c'est un coup
	# tournant ÉLARGI qui inflige 2 dégâts (idéal pour punir le Gardien).
	_heavy = _dash_strike_window > 0.0
	_dash_strike_window = 0.0
	if _heavy:
		attack_shape.scale = Vector2(2.0, 1.7)
		Sfx.varied(sfx_slash, 0.68, 0.82)  # coup plus grave et lourd
		SaveManager.vibrate(30)
		_shake = maxf(_shake, 3.5)
		_spawn_heavy_slash()
	else:
		attack_shape.scale = Vector2.ONE
		Sfx.varied(sfx_slash, 0.9, 1.12)
		_spawn_slash_trail()
	_play("attack")

## Arc du coup de sabre : un halo doré large et un cœur blanc vif, tracés en
## croissant, avec un léger balayage rotatif — la lame semble trancher l'air.
func _slash_crescent(outer: float, inner: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var n := 8
	var i := 0
	while i <= n:
		var a := -1.1 + 2.2 * float(i) / float(n)
		pts.append(Vector2(cos(a) * outer, sin(a) * outer))
		i += 1
	var j := n
	while j >= 0:
		var a2 := -1.1 + 2.2 * float(j) / float(n)
		pts.append(Vector2(cos(a2) * inner, sin(a2) * inner))
		j -= 1
	return pts

func _spawn_slash_trail() -> void:
	var pivot := Node2D.new()
	pivot.position = Vector2(16.0 * facing, -8.0)
	pivot.scale = Vector2(facing, 1.0)
	pivot.rotation = -0.5
	add_child(pivot)
	# Halo doré, large et diffus.
	var glow := Polygon2D.new()
	glow.polygon = _slash_crescent(40.0, 18.0)
	glow.color = Color(1.0, 0.85, 0.45, 0.4)
	pivot.add_child(glow)
	# Cœur blanc vif de la lame.
	var core := Polygon2D.new()
	core.polygon = _slash_crescent(34.0, 24.0)
	core.color = Color(1, 1, 1, 0.75)
	pivot.add_child(core)
	var t := pivot.create_tween()
	t.set_parallel(true)
	t.tween_property(pivot, "rotation", 0.6, 0.2).set_ease(Tween.EASE_OUT)
	t.tween_property(pivot, "modulate:a", 0.0, 0.24)
	t.chain().tween_callback(pivot.queue_free)

## Grand arc tournant de la frappe en ruée : un croissant large et lumineux
## qui balaie plus loin autour d'Eneko.
func _spawn_heavy_slash() -> void:
	var pivot := Node2D.new()
	pivot.position = Vector2(20.0 * facing, -8.0)
	pivot.scale = Vector2(facing, 1.0)
	pivot.rotation = -1.0
	add_child(pivot)
	var glow := Polygon2D.new()
	glow.polygon = _slash_crescent(66.0, 30.0)
	glow.color = Color(0.7, 0.9, 1.0, 0.45)
	pivot.add_child(glow)
	var core := Polygon2D.new()
	core.polygon = _slash_crescent(56.0, 40.0)
	core.color = Color(1, 1, 1, 0.85)
	pivot.add_child(core)
	var t := pivot.create_tween()
	t.set_parallel(true)
	t.tween_property(pivot, "rotation", 1.4, 0.26).set_ease(Tween.EASE_OUT)
	t.tween_property(pivot, "scale", Vector2(facing * 1.25, 1.25), 0.26)
	t.tween_property(pivot, "modulate:a", 0.0, 0.3)
	t.chain().tween_callback(pivot.queue_free)

func take_damage(amount: int, from_position: Vector2) -> void:
	if invuln > 0.0:
		return
	# La bénédiction de Léonie annule entièrement le prochain coup
	# (sans compter comme un dégât pour le grade).
	if blessed:
		blessed = false
		if _bless_aura != null:
			_bless_aura.visible = false
		invuln = INVULN_TIME
		_shake = 4.0
		Sfx.varied(sfx_hurt, 0.92, 1.08)
		SaveManager.vibrate(25)
		return
	Challenge.register_damage()
	_end_combo()
	health -= amount
	_update_hearts()
	_vignette_flash = 0.85
	Sfx.varied(sfx_hurt, 0.92, 1.08)
	_shake = 7.0
	SaveManager.vibrate(45)
	if health <= 0:
		respawn()
		return
	invuln = INVULN_TIME
	knockback = KNOCKBACK_TIME
	lock_timer = HURT_LOCK
	_play("hurt")
	var push := signf(global_position.x - from_position.x)
	if push == 0.0:
		push = -facing
	velocity.x = push * KNOCKBACK_SPEED
	velocity.y = -220.0

## Chute dans un trou : coûte un cœur et renvoie au dernier checkpoint.
## Le niveau ne recommence en entier que si les cœurs tombent à zéro.
func fall_damage() -> void:
	if _dead:
		return
	Challenge.register_damage()
	_end_combo()
	health -= 1
	_update_hearts()
	_vignette_flash = 0.85
	Sfx.varied(sfx_hurt, 0.92, 1.08)
	_shake = 7.0
	SaveManager.vibrate(45)
	if health <= 0:
		_die_and_restart()
		return
	_return_to_checkpoint()

## Permet à un niveau de teinter la poussière soulevée à l'atterrissage
## (ex. neige blanche sur les sommets enneigés au lieu de terre).
func set_land_dust_color(c: Color) -> void:
	if _land_dust != null:
		_land_dust.color = c

## Soin complet (accordé par Léonie au passage).
func heal_full() -> void:
	health = _max_health()
	_update_hearts()

## Plafond de cœurs : 2 en mode Kensei ; sinon 3, plus le bonus du mode
## détente (accessibilité) si le joueur l'a activé.
func _max_health() -> int:
	if Challenge.kensei:
		return 2
	return MAX_HEALTH + SaveManager.bonus_hearts()

## Crée au besoin des cœurs d'interface supplémentaires (mode détente) en
## dupliquant le dernier, pour que la barre de vie affiche jusqu'à 5 cœurs.
func _ensure_hearts() -> void:
	while hearts.size() < _max_health():
		var last: Sprite2D = hearts[hearts.size() - 1]
		var h: Sprite2D = last.duplicate()
		h.position = last.position + Vector2(44, 0)
		last.get_parent().add_child(h)
		hearts.append(h)

## Bénédiction de Léonie : une aura dorée entoure Eneko et le prochain
## coup encaissé est annulé.
func bless() -> void:
	blessed = true
	if _bless_aura == null:
		_bless_aura = Sprite2D.new()
		_bless_aura.texture = load("res://assets/mist.svg")
		_bless_aura.modulate = Color(1.0, 0.85, 0.4, 0.26)
		_bless_aura.scale = Vector2(2.2, 2.2)
		_bless_aura.position = Vector2(0, -10)
		_bless_aura.z_index = -1
		add_child(_bless_aura)
	_bless_aura.visible = true

## Mort (0 cœur suite aux dégâts) : redémarrage complet du niveau.
func respawn() -> void:
	_die_and_restart()

## Mort unifiée : fige Eneko, vide les cœurs, affiche le message, puis
## recharge la scène. Le garde _dead évite les déclenchements multiples
## (kill zone + ennemi dans la même frame, par exemple).
func _die_and_restart() -> void:
	if _dead:
		return
	_dead = true
	Achievements.add_death()
	health = 0
	_update_hearts()
	Sfx.varied(sfx_hurt, 0.92, 1.08)
	_flash_game_over()
	set_physics_process(false)
	await get_tree().create_timer(1.1).timeout
	get_tree().reload_current_scene()

## Message temporaire "vous avez perdu" affiché quand les 3 cœurs tombent à
## zéro (sinon la vie revient au max sans que le joueur comprenne pourquoi).
func _flash_game_over() -> void:
	game_over_label.modulate.a = 1.0
	game_over_label.visible = true
	var tween := create_tween()
	tween.tween_interval(1.2)
	tween.tween_property(game_over_label, "modulate:a", 0.0, 0.6)
	tween.finished.connect(func(): game_over_label.visible = false)

func _return_to_checkpoint() -> void:
	position = start_position
	velocity = Vector2.ZERO
	invuln = 0.8
	knockback = 0.0
	lock_timer = 0.0
	_ghost_through = 0.0
	set_collision_mask_value(2, true)
	attacking = false
	attack_area.monitoring = false
	anim.modulate.a = 1.0
	# La téléportation peut être très grande (chute verticale) : sans ça,
	# la caméra met plusieurs secondes à rattraper son lissage et Eneko
	# reste hors-écran pendant ce temps.
	camera.reset_smoothing()

## Déplace le point de réapparition (checkpoint atteint). Un carillon ne
## sonne que si le point change vraiment (pas en re-croisant le même).
func set_checkpoint(pos: Vector2) -> void:
	if pos.distance_to(start_position) > 1.0:
		sfx_checkpoint.play()
	start_position = pos

## Ramasse un orbe spirituel (ou une orbe dorée qui en vaut plusieurs) :
## tous les 5 orbes, Eneko récupère un cœur.
func collect_orb(count: int = 1) -> void:
	for k in count:
		Challenge.register_orb()
		orbs += 1
		if orbs % 5 == 0 and health < _max_health():
			health += 1
			_update_hearts()
	# Progression visible : "7/21" plutôt qu'un simple compteur.
	if Challenge.total_orbs > 0:
		orb_label.text = "%d/%d" % [orbs, Challenge.total_orbs]
	else:
		orb_label.text = "x%d" % orbs
	Sfx.varied(sfx_orb, 0.92, 1.12)
	_orb_burst.restart()
	_orb_flash = 0.45  # le feu follet de Léonie s'illumine : la Flamme grandit
	_update_heart_hint()

## Compte à rebours vers le prochain cœur (un tous les 5 orbes).
func _update_heart_hint() -> void:
	var remaining := 5 - (orbs % 5)
	heart_hint.text = "Prochain cœur : %d orbe%s" % [remaining, "s" if remaining > 1 else ""]

func _update_hearts() -> void:
	for i in hearts.size():
		hearts[i].visible = i < health

## Vignette rouge en bord d'écran, tissée d'un dégradé radial (centre limpide,
## coins teintés). Sous le reste du HUD et transparente aux touches.
func _build_vignette() -> void:
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.5, 1.0])
	grad.colors = PackedColorArray([Color(0.75, 0.05, 0.08, 0.0), Color(0.75, 0.05, 0.08, 0.85)])
	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 480
	tex.height = 270
	_vignette = TextureRect.new()
	_vignette.texture = tex
	_vignette.anchor_right = 1.0
	_vignette.anchor_bottom = 1.0
	_vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_vignette.stretch_mode = TextureRect.STRETCH_SCALE
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vignette.modulate = Color(1, 1, 1, 0)
	$HUD.add_child(_vignette)
	$HUD.move_child(_vignette, 0)

func _update_vignette(delta: float) -> void:
	if _vignette == null:
		return
	_vignette_flash = maxf(0.0, _vignette_flash - delta * 2.2)
	# L'éclat vif à l'impact respecte le réglage « flash » (accessibilité) ;
	# la pulsation lente de danger critique reste, elle, toujours visible.
	var flash := _vignette_flash if SaveManager.setting_on("flash") else 0.0
	var low := 0.0
	if health <= 1 and not _dead:
		var phase := Time.get_ticks_msec() / 1000.0
		low = 0.24 + 0.12 * (0.5 + 0.5 * sin(phase * 5.0))
	_vignette.modulate.a = maxf(flash, low)

func _on_attack_area_body_entered(body: Node2D) -> void:
	_try_hit(body)

## Applique un coup de sabre à une cible, une seule fois par attaque. Appelé
## à l'entrée dans la zone MAIS AUSSI en continu sur les corps déjà au contact
## (voir _physics_process) : sans ça, un boss immobile collé à Eneko ne
## déclenche jamais body_entered et ne subit aucun dégât.
func _try_hit(body: Node2D) -> void:
	if not attacking or not body.has_method("die"):
		return
	if body in _hit_bodies:
		return
	_hit_bodies.append(body)
	# call() : les die() des ennemis renvoient true/false (l'armure des
	# Ombres d'élite encaisse le premier coup) ; les die() void (boss,
	# anciens ennemis) renvoient null et comptent comme un coup qui tue.
	var res: Variant = body.call("die")
	Sfx.varied(_sfx_hit, 0.9, 1.12)  # claquement du sabre sur la cible
	# Frappe en ruée : une seconde entaille (2 dégâts, brise l'armure).
	if _heavy and is_instance_valid(body) and body.has_method("die"):
		body.call("die")
	if res is bool and bool(res) == false:
		_shake = 2.0  # le coup a porté, mais l'esprit tient debout
		SaveManager.vibrate(12)
		return
	Challenge.register_kill()
	_register_combo_kill()
	_shake = 3.5  # impact ressenti à chaque coup qui porte
	SaveManager.vibrate(18)
	_hit_stop()

## Petit badge rouge sous le chrono pour rappeler que le mode Kensei est actif.
func _build_kensei_badge() -> void:
	var badge := Label.new()
	badge.text = "KENSEI"
	badge.position = Vector2(330, 54)
	badge.add_theme_font_size_override("font_size", 13)
	badge.add_theme_color_override("font_color", Color(1.0, 0.42, 0.35))
	badge.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
	badge.add_theme_constant_override("shadow_offset_x", 1)
	badge.add_theme_constant_override("shadow_offset_y", 1)
	$HUD.add_child(badge)

## Ombre de contact projetée au sol sous Eneko (rendue derrière le sprite).
func _add_contact_shadow(w: float) -> void:
	var sh := ContactShadow.new()
	sh.width = w
	add_child(sh)
	move_child(sh, 0)

## Label « Combo ×N » en haut à droite, sous le compteur d'orbes (caché au
## repos) — le haut-centre est réservé au chrono et aux titres de victoire.
func _build_combo_label() -> void:
	_combo_label = Label.new()
	_combo_label.size = Vector2(280, 30)
	_combo_label.position = Vector2(660, 62)
	_combo_label.pivot_offset = Vector2(250, 15)
	_combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_combo_label.add_theme_font_size_override("font_size", 24)
	_combo_label.add_theme_color_override("font_color", Color(1.0, 0.82, 0.35))
	_combo_label.add_theme_color_override("font_outline_color", Color(0.25, 0.1, 0.05, 0.9))
	_combo_label.add_theme_constant_override("outline_size", 6)
	_combo_label.visible = false
	$HUD.add_child(_combo_label)

## Un esprit de plus dans la série : affiche « Combo ×N » à partir de 2.
func _register_combo_kill() -> void:
	_combo += 1
	_combo_timer = COMBO_WINDOW
	Challenge.register_combo(_combo)
	if _combo >= 2 and _combo_label != null:
		_combo_label.text = "Combo ×%d" % _combo
		_combo_label.modulate.a = 1.0
		_combo_label.visible = true
		_combo_label.scale = Vector2(1.45, 1.45)
		var t := create_tween()
		t.tween_property(_combo_label, "scale", Vector2.ONE, 0.18)

## Fin de série (fenêtre expirée ou coup encaissé) : le compteur s'efface.
func _end_combo() -> void:
	_combo = 0
	_combo_timer = 0.0
	if _combo_label != null and _combo_label.visible:
		var t := create_tween()
		t.tween_property(_combo_label, "modulate:a", 0.0, 0.35)
		# Ne cache le label que si aucune nouvelle série n'a démarré entre-temps.
		t.finished.connect(func() -> void:
			if _combo == 0:
				_combo_label.visible = false
		)

## Le sabre dissipe aussi les projectiles (orbes corrompus des Yūrei).
func _on_attack_area_area_entered(area: Area2D) -> void:
	if area.has_method("die"):
		area.die()
		_shake = 2.0

func _on_left_pressed() -> void:
	moving_left = true

func _on_left_released() -> void:
	moving_left = false

func _on_right_pressed() -> void:
	moving_right = true

func _on_right_released() -> void:
	moving_right = false

func _on_jump_pressed() -> void:
	_touch_jump_held = true
	jump()

func _on_jump_released() -> void:
	_touch_jump_held = false

func _on_dash_pressed() -> void:
	dash()

func _on_grapple_pressed() -> void:
	grapple()

func _on_attack_pressed() -> void:
	attack()

## Le bouton menu ouvre une pause au lieu de quitter brutalement : on ne
## perd plus sa partie sur un tap accidentel.
func _on_menu_pressed() -> void:
	if _pause_layer == null:
		_open_pause()

func _open_pause() -> void:
	get_tree().paused = true
	_pause_layer = CanvasLayer.new()
	_pause_layer.layer = 5
	_pause_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_pause_layer)

	var dim := ColorRect.new()
	dim.color = Color(0.04, 0.03, 0.08, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pause_layer.add_child(dim)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.offset_left = -130.0
	box.offset_right = 130.0
	box.offset_top = -130.0
	box.offset_bottom = 130.0
	box.add_theme_constant_override("separation", 14)
	_pause_layer.add_child(box)

	var title := Label.new()
	title.text = "Pause"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 38)
	box.add_child(title)

	# Stats de la tentative en cours.
	var tsec := int(Challenge.get_time_elapsed())
	var stats := Label.new()
	stats.text = "Temps %d:%02d  •  Orbes %d/%d  •  Dégâts %d" % [
		tsec / 60, tsec % 60,
		Challenge.orbs_collected, Challenge.total_orbs, Challenge.damage_taken,
	]
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.add_theme_font_size_override("font_size", 16)
	stats.add_theme_color_override("font_color", Color(0.9, 0.88, 0.8, 0.85))
	box.add_child(stats)

	var resume := _pause_button("Reprendre", Color(0.45, 0.75, 0.4))
	resume.pressed.connect(_close_pause)
	box.add_child(resume)

	var retry := _pause_button("Recommencer", Color(0.92, 0.65, 0.3))
	retry.pressed.connect(func():
		get_tree().paused = false
		get_tree().reload_current_scene()
	)
	box.add_child(retry)

	var menu := _pause_button("Retour au menu", Color(0.6, 0.5, 0.45))
	menu.pressed.connect(func():
		get_tree().paused = false
		Transition.goto("res://scenes/main_menu.tscn")
	)
	box.add_child(menu)

func _pause_button(label: String, accent: Color) -> Button:
	var b := Button.new()
	b.text = label
	b.custom_minimum_size = Vector2(0, 54)
	b.add_theme_font_size_override("font_size", 24)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.09, 0.17, 0.92)
	sb.border_color = accent
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(8.0)
	var hov: StyleBoxFlat = sb.duplicate()
	hov.bg_color = Color(0.2, 0.15, 0.22, 0.95)
	var prs: StyleBoxFlat = sb.duplicate()
	prs.bg_color = Color(0.34, 0.2, 0.18, 0.95)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", hov)
	b.add_theme_stylebox_override("pressed", prs)
	return b

func _close_pause() -> void:
	get_tree().paused = false
	if _pause_layer != null:
		_pause_layer.queue_free()
		_pause_layer = null
