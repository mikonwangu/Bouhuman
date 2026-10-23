class_name StickFigure
extends Node2D
## 棒人間プレースホルダ描画

@export var figure_color: Color = Color(0.9, 0.9, 0.85)
@export var facing: float = 1.0
@export var pose_phase: float = 0.0
@export var attacking: bool = false

var _base_scale := 1.0


func _process(delta: float) -> void:
	pose_phase += delta * (12.0 if attacking else 6.0)
	queue_redraw()


func _draw() -> void:
	var c := figure_color
	var s := _base_scale
	var bob := sin(pose_phase) * 2.0
	var arm_swing := sin(pose_phase) * (18.0 if attacking else 8.0) * facing

	# 頭
	draw_circle(Vector2(0, -40 + bob) * s, 10 * s, c)
	# 胴
	draw_line(Vector2(0, -30 + bob) * s, Vector2(0, 10 + bob) * s, c, 3.0)
	# 腕
	draw_line(Vector2(0, -18 + bob) * s, Vector2((-22 + arm_swing) * facing, -5 + bob) * s, c, 3.0)
	draw_line(Vector2(0, -18 + bob) * s, Vector2((20 + arm_swing * 0.3) * facing, 0 + bob) * s, c, 3.0)
	# 脚
	var step := sin(pose_phase * 0.5) * 6.0
	draw_line(Vector2(0, 10 + bob) * s, Vector2((-12 - step) * facing, 42 + bob) * s, c, 3.0)
	draw_line(Vector2(0, 10 + bob) * s, Vector2((12 + step) * facing, 42 + bob) * s, c, 3.0)
