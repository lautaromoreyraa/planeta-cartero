extends Node3D

## Escena principal del juego.
##
## En el hito 1 Esc cierra el juego directamente; el comportamiento definitivo
## (pausa o salida) se decide en el hito 3 (RF-07).


func _unhandled_input(evento: InputEvent) -> void:
	if evento.is_action_pressed("pause"):
		get_tree().quit()
