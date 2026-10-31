class_name CrosshairReticle
extends Control

## Custom-drawn crisp vector Tactical FPS Reticle (zero font dependency!).
## Dynamically tightens during Aim-Down-Sights (ADS) and shifts color on target lock.

var reticle_color: Color = Color(0.35, 0.95, 1.0, 0.92)
var gap: float = 7.0
var tick_len: float = 9.0


func set_state(col: Color, is_ads: bool) -> void:
	var target_gap := 4.0 if is_ads else 7.5
	if reticle_color != col or absf(gap - target_gap) > 0.1:
		reticle_color = col
		gap = target_gap
		queue_redraw()


func _draw() -> void:
	var c := size * 0.5
	var shadow := Color(0.02, 0.04, 0.08, 0.75)
	var dirs := [Vector2.UP, Vector2.DOWN, Vector2.LEFT, Vector2.RIGHT]
	for d in dirs:
		draw_line(c + d * gap, c + d * (gap + tick_len), shadow, 3.6, true)
		draw_line(c + d * gap, c + d * (gap + tick_len), reticle_color, 2.0, true)
	draw_circle(c, 2.2, shadow)
	draw_circle(c, 1.5, reticle_color)
