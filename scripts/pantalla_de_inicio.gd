class_name PantallaDeInicio
extends Control

## Primera pantalla del juego: título de cumpleaños y «Continuar» / «Nueva
## partida» (RF-08). Esc cierra el juego (RF-07 CA1).
##
## Carga el config y el guardado una sola vez, arma la escena del juego con
## eso y la pone en su lugar; la escena del juego no lee el guardado por su
## cuenta, así los tests que la cargan sola no tocan la partida real.

const ESCENA_DEL_JUEGO: PackedScene = preload("res://scenes/principal.tscn")

## Textos por defecto si falta la clave en el config (RF-22 CA2).
const TITULO_POR_DEFECTO: String = "¡Feliz cumpleaños!"
const CONTINUAR_POR_DEFECTO: String = "Continuar"
const NUEVA_PARTIDA_POR_DEFECTO: String = "Nueva partida"
const INDICACION_POR_DEFECTO: String = "Flechas para elegir, Enter o clic para aceptar, Esc para salir"

## Archivo de guardado; los tests lo cambian antes de agregar la escena.
var ruta_de_guardado: String = Guardado.RUTA

@onready var _titulo: Label = $Centro/Contenido/Titulo
@onready var _subtitulo: Label = $Centro/Contenido/Subtitulo
@onready var _opciones: MenuDeOpciones = $Centro/Contenido/Opciones
@onready var _indicacion: Label = $Centro/Contenido/Indicacion

var _config: Configuracion = null
var _guardado: EstadoDePartida = null


func _ready() -> void:
	_config = Configuracion.cargar_para_el_juego()
	# Un guardado que no corresponde al config cargado se ignora (RF-21 CA6).
	_guardado = Guardado.leer(ruta_de_guardado, _config.ids_de_cartas(), Configuracion.CANTIDAD_DE_CASAS)

	_titulo.text = _config.texto("inicio.titulo", TITULO_POR_DEFECTO)
	_subtitulo.text = _config.texto("inicio.subtitulo", "")
	_indicacion.text = _config.texto("inicio.indicacion", INDICACION_POR_DEFECTO)
	var opciones: PackedStringArray = PackedStringArray()
	if _guardado != null:
		opciones.append(_config.texto("inicio.opcion_continuar", CONTINUAR_POR_DEFECTO))
	opciones.append(_config.texto("inicio.opcion_nueva_partida", NUEVA_PARTIDA_POR_DEFECTO))
	_opciones.configurar(opciones)
	_opciones.elegida.connect(_al_elegir)


func _unhandled_input(evento: InputEvent) -> void:
	if evento.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		get_tree().quit()


func _al_elegir(indice: int) -> void:
	_opciones.activo = false
	var continuar: bool = _guardado != null and indice == 0
	var juego: Principal = ESCENA_DEL_JUEGO.instantiate()
	juego.config = _config
	juego.ruta_de_guardado = ruta_de_guardado
	if continuar:
		juego.estado_inicial = _guardado
	else:
		# «Nueva partida» borra el guardado anterior (RF-21 CA4).
		Guardado.borrar(ruta_de_guardado)
		juego.mostrar_tutorial = true
	get_tree().change_scene_to_node(juego)
