class_name Guia
extends Control

## Flecha de la guía hacia el próximo objetivo (RF-30). Se dibuja apuntando
## hacia arriba y se gira con `rotation` alrededor de su centro
## (`pivot_offset` en la escena): 0 es «adelante» en la vista.
##
## Los colores salen del tema (tipo `Guia`), como el resto de la interfaz.

## Puntos de la flecha, en proporción al tamaño del control.
const PUNTA: PackedVector2Array = [
	Vector2(0.5, 0.0), Vector2(0.95, 0.55), Vector2(0.65, 0.55),
	Vector2(0.65, 1.0), Vector2(0.35, 1.0), Vector2(0.35, 0.55), Vector2(0.05, 0.55),
]
## Grosor del borde en píxeles de la base de 1920x1080.
const GROSOR_DEL_BORDE: float = 6.0


func _draw() -> void:
	var puntos: PackedVector2Array = PackedVector2Array()
	for punto: Vector2 in PUNTA:
		puntos.append(punto * size)
	draw_colored_polygon(puntos, get_theme_color(&"relleno", &"Guia"))
	puntos.append(puntos[0])
	draw_polyline(puntos, get_theme_color(&"borde", &"Guia"), GROSOR_DEL_BORDE, true)
