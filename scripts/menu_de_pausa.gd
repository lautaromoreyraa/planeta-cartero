class_name MenuDePausa
extends CanvasLayer

## Menú de pausa con «Continuar» y «Salir» que abre Esc durante el juego,
## también con un diálogo abierto o en la carta final (RF-07).
##
## Va último en la escena principal para recibir el teclado antes que los
## diálogos; mientras está abierto se queda con todas las teclas, así nada de
## lo que está atrás reacciona. Al cerrarse deja la pausa como estaba: si
## había un diálogo abierto, el juego sigue detenido detrás de él.

## Textos por defecto si falta la clave en el config (RF-22 CA2).
const TITULO_POR_DEFECTO: String = "Pausa"
const CONTINUAR_POR_DEFECTO: String = "Continuar"
const SALIR_POR_DEFECTO: String = "Salir"
const INDICACION_POR_DEFECTO: String = "Flechas para elegir, Enter o clic para aceptar"

@onready var _titulo: Label = $Centro/Panel/Contenido/Titulo
@onready var _opciones: MenuDeOpciones = $Centro/Panel/Contenido/Opciones
@onready var _indicacion: Label = $Centro/Panel/Contenido/Indicacion

var _pausa_previa: bool = false


func _ready() -> void:
	_opciones.activo = false
	_opciones.elegida.connect(_al_elegir)


func configurar(config: Configuracion) -> void:
	_titulo.text = config.texto("pausa.titulo", TITULO_POR_DEFECTO)
	_indicacion.text = config.texto("pausa.indicacion", INDICACION_POR_DEFECTO)
	_opciones.configurar(PackedStringArray([
		config.texto("pausa.continuar", CONTINUAR_POR_DEFECTO),
		config.texto("pausa.salir", SALIR_POR_DEFECTO),
	]))


func _unhandled_input(evento: InputEvent) -> void:
	if evento.is_action_pressed("pause"):
		if visible:
			_cerrar()
		else:
			_abrir()
	elif not visible or not (evento is InputEventKey or evento is InputEventAction):
		return
	get_viewport().set_input_as_handled()


func _abrir() -> void:
	_pausa_previa = get_tree().paused
	get_tree().paused = true
	# Visible antes de elegir la primera opción: sólo así puede tomar el foco.
	visible = true
	_opciones.seleccionar(0)
	_opciones.activo = true


func _cerrar() -> void:
	visible = false
	_opciones.activo = false
	get_tree().paused = _pausa_previa


func _al_elegir(indice: int) -> void:
	if indice == 0:
		_cerrar()
	else:
		# Lo que se conserva es el último checkpoint (RF-07 CA5, RF-21).
		get_tree().quit()
