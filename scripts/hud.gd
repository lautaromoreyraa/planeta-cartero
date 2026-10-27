class_name Hud
extends CanvasLayer

## HUD mínimo: cartas en la mano (RF-12), código parcial (RF-26), avisos
## breves, indicador de la tecla E sobre el interactuable en rango (RF-06) y
## la flecha de la guía (RF-30).
##
## No busca a nadie: la escena principal le pasa el config y lo conecta a
## las señales del detector y le avisa los cambios (RNF-20). Las líneas van
## en un contenedor que crece con el texto, así un formato largo del config
## no se corta (RNF-09).

## Textos por defecto si falta la clave en el config (RF-22 CA2).
const FORMATO_CARTAS_POR_DEFECTO: String = "Cartas: {n}"
const FORMATO_CODIGO_POR_DEFECTO: String = "Código: {codigo}"
const DIGITO_OCULTO_POR_DEFECTO: String = "_"
const INDICADOR_POR_DEFECTO: String = "E"
## Metros por encima del interactuable donde se dibuja el indicador.
const ALTURA_DEL_INDICADOR: float = 0.5
## Segundos de juego que queda en pantalla un aviso breve.
const SEGUNDOS_DEL_AVISO: float = 3.0

@onready var _cartas: Label = $Lineas/Cartas
@onready var _codigo: Label = $Lineas/Codigo
@onready var _aviso: Label = $Aviso
@onready var _indicador: Label = $Indicador
@onready var _guia: Guia = $Guia

var _formato_cartas: String = FORMATO_CARTAS_POR_DEFECTO
var _formato_codigo: String = FORMATO_CODIGO_POR_DEFECTO
var _digito_oculto: String = DIGITO_OCULTO_POR_DEFECTO
var _objetivo: Interactuable = null
## Cuenta los avisos para que el temporizador de uno viejo no oculte uno nuevo.
var _avisos: int = 0


func _ready() -> void:
	# Sin objetivo no hay indicador que reubicar en cada frame.
	set_process(false)


func configurar(config: Configuracion) -> void:
	_formato_cartas = config.texto("hud.formato_cartas", FORMATO_CARTAS_POR_DEFECTO)
	_formato_codigo = config.texto("hud.formato_codigo", FORMATO_CODIGO_POR_DEFECTO)
	_digito_oculto = config.texto("hud.digito_oculto", DIGITO_OCULTO_POR_DEFECTO)
	_indicador.text = config.texto("hud.indicador_interaccion", INDICADOR_POR_DEFECTO)


func mostrar_cartas(cantidad: int) -> void:
	_cartas.text = _formato_cartas.format({"n": cantidad})


## La línea del código aparece con el primer dígito revelado y queda hasta
## el final de la partida (RF-26 CA2 y CA3).
func mostrar_codigo(codigo: String, revelados: int) -> void:
	_codigo.visible = revelados > 0
	_codigo.text = _formato_codigo.format({"codigo": Candado.codigo_parcial(codigo, revelados, _digito_oculto)})


## Aviso que no interrumpe el juego, como el texto al recoger una carta.
func mostrar_aviso(texto: String) -> void:
	_avisos += 1
	_aviso.text = texto
	_aviso.visible = true
	# Con `process_always` apagado el tiempo no corre mientras hay un diálogo.
	get_tree().create_timer(SEGUNDOS_DEL_AVISO, false).timeout.connect(_ocultar_aviso.bind(_avisos))


## Ángulo de la flecha de la guía, en radianes y en sentido horario desde
## arriba de la pantalla (ver `GeometriaEsferica.angulo_en_pantalla`).
func orientar_guia(angulo: float) -> void:
	_guia.rotation = angulo


## La guía se ve siempre durante el juego y se oculta con un menú, un
## diálogo, el candado o la carta final en pantalla (RF-30 CA1).
func mostrar_guia(visible_en_juego: bool) -> void:
	_guia.visible = visible_en_juego


## `objetivo` nulo oculta el indicador.
func mostrar_objetivo(objetivo: Interactuable) -> void:
	_objetivo = objetivo
	set_process(_objetivo != null)
	_ubicar_indicador()


func _process(_delta: float) -> void:
	_ubicar_indicador()


func _ocultar_aviso(numero_de_aviso: int) -> void:
	if numero_de_aviso == _avisos:
		_aviso.visible = false


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
