class_name UiScroll
extends Object
## Utilitaire d'interface : rend un ScrollContainer confortable au doigt.
## - désactive le défilement horizontal (source de glissements parasites) ;
## - épaissit et colore la barre verticale pour qu'elle soit facile à
##   attraper et bien visible ;
## - augmente la zone morte de glissement, pour qu'un glissement du doigt
##   n'importe où dans la liste fasse défiler au lieu d'activer un bouton.

static func make_touch_friendly(scroll: ScrollContainer) -> void:
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	# Un glissement de plus de 12 px devient un défilement (et annule le
	# clic sur le bouton sous le doigt) — le rend beaucoup plus tolérant.
	scroll.scroll_deadzone = 12

	var vbar := scroll.get_v_scroll_bar()
	vbar.custom_minimum_size = Vector2(26, 0)

	var grab := StyleBoxFlat.new()
	grab.bg_color = Color(0.92, 0.65, 0.3, 0.92)
	grab.set_corner_radius_all(9)
	grab.content_margin_left = 3.0
	grab.content_margin_right = 3.0
	var grab_hl: StyleBoxFlat = grab.duplicate()
	grab_hl.bg_color = Color(1.0, 0.8, 0.42, 1.0)
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.08, 0.07, 0.14, 0.55)
	track.set_corner_radius_all(9)

	vbar.add_theme_stylebox_override("grabber", grab)
	vbar.add_theme_stylebox_override("grabber_highlight", grab_hl)
	vbar.add_theme_stylebox_override("grabber_pressed", grab_hl)
	vbar.add_theme_stylebox_override("scroll", track)
