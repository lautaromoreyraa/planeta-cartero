class_name MenuDeOpciones
extends VBoxContainer

## Lista de opciones que se elige sólo con el teclado: flechas o W/S para
## moverse y Enter para aceptar (RF-07 CA6, RF-08 CA2).
##
## Usa las acciones de movimiento en lugar de las `ui_*` de Godot para que
## Espacio (que está en `ui_accept`) no elija una opción por accidente. La
## opción elegida se marca con la variación `OpcionElegida` del tema.

signal elegida(indice: int)

## Apagado, no responde al teclado: lo usa quien lo muestra y lo oculta.
var activo: bool = true

var _elegida: int = 0


func configurar(textos: PackedStringArray) -> void:
	for texto: String in textos:
		var opcion: Label = Label.new()
		opcion.text = texto
		opcion.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		add_child(opcion)
	seleccionar(0)


func seleccionar(indice: int) -> void:
	_elegida = indice
	for i: int in range(get_child_count()):
		var opcion: Label = get_child(i) as Label
		opcion.theme_type_variation = &"OpcionElegida" if i == _elegida else &""


func _unhandled_input(evento: InputEvent) -> void:
	var cantidad: int = get_child_count()
	if not activo or cantidad == 0:
		return
	if evento.is_action_pressed("move_forward", true):
		seleccionar(posmod(_elegida - 1, cantidad))
	elif evento.is_action_pressed("move_back", true):
		seleccionar(posmod(_elegida + 1, cantidad))
	elif evento.is_action_pressed("aceptar"):
		get_viewport().set_input_as_handled()
		elegida.emit(_elegida)
		return
	else:
		return
	get_viewport().set_input_as_handled()
