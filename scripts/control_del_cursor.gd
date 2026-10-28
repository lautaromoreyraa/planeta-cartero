class_name ControlDelCursor
extends Node

## Captura el cursor mientras se juega y lo libera con el juego detenido
## (RF-28 CA1, CA6 y CA7; RF-07 CA8).
##
## Todo lo que interrumpe el juego (la pausa, los diálogos, el candado y la
## carta final) pone el árbol en pausa, así que alcanza con mirar eso: no
## hace falta que cada ventana se acuerde de soltar y volver a capturar el
## cursor. Procesa siempre para notar el cambio también con el árbol en pausa,
## y avisa con una señal para que el HUD oculte la guía (RF-30 CA1).

signal juego_en_curso_cambiado(en_curso: bool)

var _en_curso: bool = false


func _ready() -> void:
	_aplicar(not get_tree().paused)


func _process(_delta: float) -> void:
	var en_curso: bool = not get_tree().paused
	if en_curso != _en_curso:
		_aplicar(en_curso)


func _aplicar(en_curso: bool) -> void:
	_en_curso = en_curso
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if en_curso else Input.MOUSE_MODE_VISIBLE
	juego_en_curso_cambiado.emit(en_curso)
