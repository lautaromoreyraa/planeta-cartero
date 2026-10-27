class_name Dialogo
extends CanvasLayer

## Ventana de texto con imagen opcional: tutorial, pista, recuerdos, avisos
## y carta final (RF-09, RF-14, RF-16, RF-17, RF-20).
##
## Mientras está abierta el juego queda en pausa, así WASD, Espacio y E no
## mueven el mundo. Procesa siempre para seguir leyendo el teclado en pausa,
## y el menú de pausa, que va después en el árbol, recibe Esc antes que ella.
## El texto largo se desplaza con las flechas (RNF-09) y la imagen se escala
## conservando la proporción dentro de su recuadro.

## Texto por defecto si falta la clave en el config (RF-22 CA2).
const INDICACION_POR_DEFECTO: String = "Enter o E para cerrar"
## Píxeles que avanza el texto por cada pulsación de flecha.
const PASO_DE_DESPLAZAMIENTO: int = 60

@onready var _imagen: TextureRect = $Centro/Panel/Contenido/Imagen
@onready var _desplazable: ScrollContainer = $Centro/Panel/Contenido/Desplazable
@onready var _texto: Label = $Centro/Panel/Contenido/Desplazable/Texto
@onready var _indicacion: Label = $Centro/Panel/Contenido/Indicacion

var _indicacion_por_defecto: String = INDICACION_POR_DEFECTO
var _cerrable: bool = true


func configurar(config: Configuracion) -> void:
	_indicacion_por_defecto = config.texto("dialogo.indicacion", INDICACION_POR_DEFECTO)


## Muestra `texto` y, si existe, la imagen de `ruta_de_imagen`. Sin
## `indicacion` se usa la de cerrar; un diálogo no `cerrable` (la carta
## final) queda abierto y sólo se sale por el menú de pausa.
func mostrar(texto: String, ruta_de_imagen: String = "", indicacion: String = "", cerrable: bool = true) -> void:
	_texto.text = texto
	_imagen.texture = _cargar_imagen(ruta_de_imagen)
	_imagen.visible = _imagen.texture != null
	_indicacion.text = indicacion if not indicacion.is_empty() else _indicacion_por_defecto
	_cerrable = cerrable
	_desplazable.scroll_vertical = 0
	visible = true
	get_tree().paused = true


func _unhandled_input(evento: InputEvent) -> void:
	if not visible:
		return
	if _cerrable and (evento.is_action_pressed("aceptar") or evento.is_action_pressed("interact")):
		visible = false
		get_tree().paused = false
	elif evento.is_action_pressed("move_forward", true):
		_desplazable.scroll_vertical -= PASO_DE_DESPLAZAMIENTO
	elif evento.is_action_pressed("move_back", true):
		_desplazable.scroll_vertical += PASO_DE_DESPLAZAMIENTO
	else:
		return
	get_viewport().set_input_as_handled()


## La imagen es opcional: si la ruta está vacía o el archivo no existe se
## muestra sólo el texto, sin ensuciar la salida (RF-16 CA2). El detalle
## queda en el modo detallado (`--verbose`) para quien prepara el contenido.
static func _cargar_imagen(ruta: String) -> Texture2D:
	if ruta.is_empty():
		return null
	if not ResourceLoader.exists(ruta):
		print_verbose("No existe la imagen %s; se muestra sólo el texto." % ruta)
		return null
	return load(ruta) as Texture2D
