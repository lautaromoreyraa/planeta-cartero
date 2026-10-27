class_name PanelDelCandado
extends CanvasLayer

## Interfaz del candado de 4 dígitos de la oficina (RF-19).
##
## Las reglas viven en `Candado`; acá sólo se lee el teclado y se muestra lo
## ingresado. Como los diálogos, pausa el juego mientras está abierto y
## procesa siempre. E la cierra sin probar el código (CA4): es la misma tecla
## que la abrió y no es un dígito.

signal abierto

## Textos por defecto si falta la clave en el config (RF-22 CA2).
const TITULO_POR_DEFECTO: String = "Candado"
const INDICACION_POR_DEFECTO: String = "Números para escribir, Retroceso para borrar, Enter para probar, E para salir"
const AVISO_DE_ERROR_POR_DEFECTO: String = "Ese no es el código."
const OCULTO_POR_DEFECTO: String = "_"
## El aviso de error queda al menos este tiempo en pantalla (RNF-15).
const SEGUNDOS_DEL_AVISO: float = 2.5

@onready var _titulo: Label = $Centro/Panel/Contenido/Titulo
@onready var _digitos: Label = $Centro/Panel/Contenido/Digitos
@onready var _error: Label = $Centro/Panel/Contenido/Error
@onready var _indicacion: Label = $Centro/Panel/Contenido/Indicacion

var _codigo: String = ""
var _oculto: String = OCULTO_POR_DEFECTO
var _ingresado: String = ""
## Cuenta los errores para que el temporizador de uno viejo no oculte el
## aviso de uno nuevo.
var _errores: int = 0


func configurar(config: Configuracion, codigo: String) -> void:
	_codigo = codigo
	_titulo.text = config.texto("oficina.titulo_candado", TITULO_POR_DEFECTO)
	_indicacion.text = config.texto("oficina.indicacion_candado", INDICACION_POR_DEFECTO)
	_error.text = config.texto("oficina.aviso_error", AVISO_DE_ERROR_POR_DEFECTO)
	_oculto = config.texto("hud.digito_oculto", OCULTO_POR_DEFECTO)


func abrir() -> void:
	_ingresado = ""
	_error.visible = false
	_mostrar_ingresado()
	visible = true
	get_tree().paused = true


func _unhandled_input(evento: InputEvent) -> void:
	if not visible:
		return
	if evento.is_action_pressed("interact"):
		_cerrar()
	elif evento.is_action_pressed("aceptar"):
		_probar()
	elif evento.is_action_pressed("borrar", true):
		_ingresado = Candado.borrar_digito(_ingresado)
	elif evento is InputEventKey and evento.is_pressed() and not evento.is_echo():
		var digito: String = _digito_de(evento as InputEventKey)
		if digito.is_empty():
			return
		_ingresado = Candado.agregar_digito(_ingresado, digito)
	else:
		return
	_mostrar_ingresado()
	get_viewport().set_input_as_handled()


func _probar() -> void:
	if Candado.es_correcto(_ingresado, _codigo):
		_cerrar()
		abierto.emit()
		return
	# Sin límite de intentos: se vacía el campo y se avisa (RF-19 CA3).
	_ingresado = ""
	_errores += 1
	_error.visible = true
	get_tree().create_timer(SEGUNDOS_DEL_AVISO).timeout.connect(_ocultar_error.bind(_errores))


func _ocultar_error(numero_de_error: int) -> void:
	if numero_de_error == _errores:
		_error.visible = false


func _cerrar() -> void:
	visible = false
	get_tree().paused = false


func _mostrar_ingresado() -> void:
	_digitos.text = Candado.codigo_parcial(_ingresado, _ingresado.length(), _oculto)


## Dígito de la tecla, de la fila de números o del teclado numérico; vacío
## si no es un número.
static func _digito_de(evento: InputEventKey) -> String:
	for tecla: Key in [evento.keycode, evento.physical_keycode]:
		if tecla >= KEY_0 and tecla <= KEY_9:
			return str(tecla - KEY_0)
		if tecla >= KEY_KP_0 and tecla <= KEY_KP_9:
			return str(tecla - KEY_KP_0)
	return ""
