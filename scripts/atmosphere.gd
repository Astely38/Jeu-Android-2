class_name Atmosphere
extends Object
## Utilitaires d'ambiance visuelle réutilisables entre les niveaux.

## Âme libérée : au moment où un esprit est vaincu, une petite lumière
## chaude s'élève de sa position et s'efface — l'âme rendue à la Flamme.
## Posée sur le niveau (host) : elle survit à la disparition de l'ennemi.
static func release_soul(host: Node, at: Vector2, tint: Color) -> void:
	if host == null or not is_instance_valid(host):
		return
	var soul := Node2D.new()
	soul.z_index = 2
	host.add_child(soul)
	soul.global_position = at
	var glow := Sprite2D.new()
	glow.texture = load("res://assets/mist.svg")
	glow.modulate = Color(tint.r, tint.g, tint.b, 0.75)
	glow.scale = Vector2(0.6, 0.6)
	soul.add_child(glow)
	var core := Polygon2D.new()
	var pts := PackedVector2Array()
	for k in 10:
		var a := k * TAU / 10.0
		pts.append(Vector2(cos(a) * 4.0, sin(a) * 4.0))
	core.polygon = pts
	core.color = Color(1.0, 0.97, 0.85, 0.95)
	soul.add_child(core)
	var sparks := CPUParticles2D.new()
	sparks.amount = 8
	sparks.one_shot = true
	sparks.emitting = true
	sparks.explosiveness = 0.5
	sparks.lifetime = 0.9
	sparks.direction = Vector2(0, -1)
	sparks.spread = 35.0
	sparks.gravity = Vector2(0, -30)
	sparks.initial_velocity_min = 20.0
	sparks.initial_velocity_max = 55.0
	sparks.scale_amount_min = 1.0
	sparks.scale_amount_max = 2.0
	sparks.color = Color(tint.r, tint.g, tint.b, 0.8)
	soul.add_child(sparks)
	var t := host.create_tween()
	t.set_parallel(true)
	t.tween_property(soul, "position:y", soul.position.y - 78.0, 1.0) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	t.tween_property(soul, "scale", Vector2(0.4, 0.4), 1.0)
	t.tween_property(soul, "modulate:a", 0.0, 1.0)
	t.chain().tween_callback(soul.queue_free)

## Gerbe d'étincelles ponctuelle (one-shot) posée sur le niveau, qui se
## libère puis se nettoie toute seule. Sert de récompense visuelle
## (checkpoint allumé, etc.).
static func spark_burst(host: Node, at: Vector2, tint: Color) -> void:
	if host == null or not is_instance_valid(host):
		return
	var b := CPUParticles2D.new()
	b.one_shot = true
	b.emitting = true
	b.explosiveness = 0.9
	b.amount = 18
	b.lifetime = 0.7
	b.direction = Vector2(0, -1)
	b.spread = 180.0
	b.gravity = Vector2(0, 80)
	b.initial_velocity_min = 45.0
	b.initial_velocity_max = 135.0
	b.scale_amount_min = 1.2
	b.scale_amount_max = 2.8
	b.color = tint
	b.z_index = 3
	host.add_child(b)
	b.global_position = at
	b.finished.connect(b.queue_free)

## Éclatement à la mort d'un ennemi : une brève onde de choc claire + une volée
## de petits éclats angulaires projetés tout autour, teintés à la couleur de
## l'esprit. Vient RENFORCER release_soul/spark_burst pour un coup de grâce plus
## « croustillant ». Posé sur le niveau (host) : survit à la disparition du corps.
static func death_burst(host: Node, at: Vector2, tint: Color) -> void:
	if host == null or not is_instance_valid(host):
		return
	# Onde de choc : anneau clair qui s'étend et s'efface vite.
	var ring := Line2D.new()
	ring.width = 3.0
	ring.default_color = Color(1.0, 1.0, 1.0, 0.7)
	ring.closed = true
	var rp := PackedVector2Array()
	for i in 20:
		var a := i * TAU / 20.0
		rp.append(Vector2(cos(a) * 8.0, sin(a) * 8.0))
	ring.points = rp
	ring.z_index = 24
	host.add_child(ring)
	ring.global_position = at
	var gt := host.create_tween()
	gt.set_parallel(true)
	gt.tween_property(ring, "scale", Vector2(3.2, 3.2), 0.25)
	gt.tween_property(ring, "modulate:a", 0.0, 0.25)
	gt.chain().tween_callback(ring.queue_free)
	# Éclats angulaires projetés dans toutes les directions.
	var n := 7
	for i in n:
		var ang := TAU * float(i) / float(n) + randf() * 0.6
		var shard := Polygon2D.new()
		var s := randf_range(2.5, 4.5)
		shard.polygon = PackedVector2Array([
			Vector2(-s, -s * 0.5), Vector2(s * 1.4, 0.0), Vector2(-s, s * 0.5),
		])
		shard.color = Color(tint.r, tint.g, tint.b, 0.95)
		shard.z_index = 24
		shard.rotation = ang
		host.add_child(shard)
		shard.global_position = at
		var target := at + Vector2(cos(ang), sin(ang)) * randf_range(26.0, 52.0)
		var st := host.create_tween()
		st.set_parallel(true)
		st.tween_property(shard, "global_position", target, 0.32).set_ease(Tween.EASE_OUT)
		st.tween_property(shard, "rotation", ang + randf_range(-2.0, 2.0), 0.32)
		st.tween_property(shard, "modulate:a", 0.0, 0.32)
		st.chain().tween_callback(shard.queue_free)

## Fait « respirer » un nœud (halo de portail, aura…) : une boucle douce de
## son alpha et de son échelle autour de leurs valeurs actuelles. Purement
## visuel — n'affecte pas le jeu. À appeler une fois le nœud DANS l'arbre.
static func breathe(node: Node2D, amount := 0.14, period := 2.4) -> void:
	if node == null or not is_instance_valid(node) or not node.is_inside_tree():
		return
	var base_a: float = node.modulate.a
	var base_s: Vector2 = node.scale
	var tw := node.create_tween().set_loops()
	tw.tween_property(node, "modulate:a", minf(1.0, base_a * 1.4), period * 0.5).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(node, "scale", base_s * (1.0 + amount), period * 0.5).set_trans(Tween.TRANS_SINE)
	tw.tween_property(node, "modulate:a", base_a, period * 0.5).set_trans(Tween.TRANS_SINE)
	tw.parallel().tween_property(node, "scale", base_s, period * 0.5).set_trans(Tween.TRANS_SINE)

## Ajoute un plan de silhouettes sombres en avant-plan (feuillages suspendus
## en haut, herbes en bas), défilant plus vite que le décor pour créer de la
## profondeur. Basé sur Parallax2D (Node2D) : il respecte le z-index, donc il
## passe DEVANT le jeu mais reste SOUS l'interface (CanvasLayer). `tint` donne
## la teinte sombre propre au niveau (feuillage, pierre, brume…).
static func add_foreground(host: Node, tint: Color) -> void:
	var fg := Parallax2D.new()
	fg.scroll_scale = Vector2(1.55, 1.02)
	fg.repeat_size = Vector2(1500, 0)
	fg.z_index = 4
	host.add_child(fg)
	# Deux touffes de feuillage suspendues au haut de l'écran.
	for tx in [220.0, 900.0]:
		_frond_cluster(fg, Vector2(float(tx), -12.0), tint)
	# Herbes sombres qui montent du bas de l'écran.
	for bx in [560.0, 1230.0]:
		_grass_clump(fg, Vector2(float(bx), 560.0), tint)

static func _poly(parent: Node, points: PackedVector2Array, color: Color, pos: Vector2) -> void:
	var p := Polygon2D.new()
	p.polygon = points
	p.color = color
	p.position = pos
	parent.add_child(p)

## Grappe de feuillage qui pend du haut de l'écran (tige + feuilles molles).
static func _frond_cluster(parent: Node, top: Vector2, tint: Color) -> void:
	var dark := Color(tint.r * 0.7, tint.g * 0.7, tint.b * 0.7, tint.a)
	_poly(parent, PackedVector2Array([
		Vector2(-5, 0), Vector2(5, 0), Vector2(3, 150), Vector2(-3, 150),
	]), dark, top)
	var ly := 30.0
	var kk := 0
	while ly < 150.0:
		var side := 1.0 if kk % 2 == 0 else -1.0
		var w := 70.0 - ly * 0.2
		_poly(parent, PackedVector2Array([
			Vector2(0, ly - 14), Vector2(side * w, ly - 4),
			Vector2(side * (w + 10.0), ly + 20), Vector2(side * (w - 20.0), ly + 22),
			Vector2(0, ly + 12),
		]), tint, top)
		ly += 34.0
		kk += 1

## Bouquet d'herbes/silhouettes sombres montant du bas de l'écran.
static func _grass_clump(parent: Node, base: Vector2, tint: Color) -> void:
	var b := 0
	while b < 9:
		var bx := -70.0 + float(b) * 18.0
		var bh := 90.0 + float((b * 37) % 70)
		var lean := (float(b % 3) - 1.0) * 16.0
		_poly(parent, PackedVector2Array([
			Vector2(bx - 8, 0), Vector2(bx + 8, 0),
			Vector2(bx + lean + 3, -bh), Vector2(bx + lean - 3, -bh),
		]), tint, base)
		b += 1
