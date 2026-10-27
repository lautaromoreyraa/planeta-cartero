class_name Hud
extends CanvasLayer

## HUD mínimo: contador de cartas (RF-12) e indicador de la tecla E sobre el
## interactuable en rango (RF-06 CA1).
##
## No busca a nadie: la escena principal le pasa el config y lo conecta a
## las señales del inventario y del detector (RNF-20).

## Textos por defecto si falta la clave en el config (RF-22 CA2).
const FORMATO_CARTAS_POR_DEFECTO: String = "Cartas: {n}/4"
const INDICADOR_POR_DEFECTO: String = "E"
## Metros por encima del interactuable donde se dibuja el indicador.
const ALTURA_DEL_INDICADOR: float = 0.5

@onready var _cartas: Label = $Cartas
@onready var _indicador: Label = $Indicador

var _formato_cartas: String = FORMATO_CARTAS_POR_DEFECTO
var _objetivo: Interactuable = null


func configurar(config: Configuracion) -> void:
	_formato_cartas = config.texto("hud.formato_cartas", FORMATO_CARTAS_POR_DEFECTO)
	_indicador.text = config.texto("hud.indicador_interaccion", INDICADOR_POR_DEFECTO)


func mostrar_cartas(cantidad: int) -> void:
	_cartas.text = _formato_cartas.format({"n": cantidad})


## `objetivo` nulo oculta el indicador.
func mostrar_objetivo(objetivo: Interactuable) -> void:
	_objetivo = objetivo
	_ubicar_indicador()


func _process(_delta: float) -> void:
	_ubicar_indicador()


## El indicador sigue al objeto en pantalla para que se entienda a qué se
## refiere la E cuando hay varias cosas cerca.
func _ubicar_indicador() -> void:
	var camara: Camera3D = get_viewport().get_camera_3d()
	if _objetivo == null or camara == null:
		_indicador.visible = false
		return
	var punto: Vector3 = _objetivo.global_position + _objetivo.global_basis.y * ALTURA_DEL_INDICADOR
	if camara.is_position_behind(punto):
		_indicador.visible = false
		return
	_indicador.visible = true
	_indicador.position = camara.unproject_position(punto) - _indicador.size / 2.0
