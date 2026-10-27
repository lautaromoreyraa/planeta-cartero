class_name MenuDeOpciones
extends VBoxContainer

## Lista de opciones que se elige con el teclado (flechas o W/S y Enter) o
## con un clic (RF-07 CA6, RF-08 CA2, RF-28 CA7).
##
## Cada opción es un `Button`: el foco de teclado marca la elegida y el
## mouse, al pasar por encima, le pasa el foco, así teclado y mouse muestran
## siempre la misma opción marcada. La marca es la variación `OpcionElegida`
## del tema. Las flechas las mueve la navegación de foco de Godot; W/S y la
## acción `aceptar` se leen acá para que valgan las mismas teclas que en el
## resto del juego. Espacio no elige: no está en `ui_accept` (project.godot)
## para que un salto apretado de más no elija una opción por accidente.

signal elegida(indice: int)

## Apagado, no responde: lo usa quien lo muestra y lo oculta, o quien ya
## eligió y no quiere una segunda elección.
var activo: bool = true

var _elegida: int = 0


func configurar(textos: PackedStringArray) -> void:
	for i: int in range(textos.size()):
		var opcion: Button = Button.new()
		opcion.text = textos[i]
		opcion.focus_entered.connect(_marcar.bind(i))
		opcion.mouse_entered.connect(opcion.grab_focus)
		opcion.pressed.connect(_elegir.bind(i))
		add_child(opcion)
	# Las flechas dan la vuelta, igual que W/S.
	var cantidad: int = get_child_count()
	for i: int in range(cantidad):
		var opcion: Button = get_child(i) as Button
		opcion.focus_neighbor_top = opcion.get_path_to(get_child(posmod(i - 1, cantidad)))
		opcion.focus_neighbor_bottom = opcion.get_path_to(get_child(posmod(i + 1, cantidad)))
	seleccionar(0)


## Marca la opción `indice` y le da el foco, si el menú está a la vista.
func seleccionar(indice: int) -> void:
	_marcar(indice)
	var opcion: Button = get_child(indice) as Button
	if opcion != null and opcion.is_visible_in_tree():
		opcion.grab_focus()


func _marcar(indice: int) -> void:
	_elegida = indice
	for i: int in range(get_child_count()):
		var opcion: Button = get_child(i) as Button
		opcion.theme_type_variation = &"OpcionElegida" if i == _elegida else &""


func _elegir(indice: int) -> void:
	if activo:
		elegida.emit(indice)


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
		_elegir(_elegida)
		return
	else:
		return
	get_viewport().set_input_as_handled()
