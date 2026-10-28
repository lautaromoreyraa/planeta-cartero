class_name CamaraSeguidora
extends Node3D

## Cámara en tercera persona que sigue a la cartera y se gira con el mouse
## (RF-05, RF-28, RT-10).
##
## El soporte guarda su propio rumbo y lo transporta por la superficie igual
## que el personaje: cada frame se reproyecta sobre el plano del nuevo
## «arriba», sin ejes globales, así en los polos no hay giros bruscos. El
## mouse gira ese rumbo alrededor del «arriba» y cambia la inclinación del
## brazo. Si el mouse queda quieto un rato mientras el personaje camina, la
## cámara vuelve sola detrás de él, despacio.
##
## Sólo lee el mouse en `_unhandled_input`, que no se llama con el árbol en
## pausa: con un menú o un diálogo abierto el cursor está libre y moverlo no
## gira la cámara (RF-28 CA8).
##
## La luz direccional («Sol») va dentro de este soporte a propósito: en un
## planeta tan chico una luz fija dejaría de noche la mitad del mundo, y
## colgada de la cámara ilumina siempre la zona donde se juega.

## Radianes por píxel de mouse. Fija: no hay menú para cambiarla (RF-28 CA4).
const SENSIBILIDAD: float = 0.003
## Inclinación del brazo sobre el plano tangente al personaje, en radianes
## (positiva, la cámara queda arriba). Los límites dejan la cámara siempre
## sobre la superficie y lejos de la vista cenital (RF-28 CA3).
const INCLINACION_POR_DEFECTO: float = deg_to_rad(25.0)
const INCLINACION_MINIMA: float = deg_to_rad(-10.0)
const INCLINACION_MAXIMA: float = deg_to_rad(65.0)
## Segundos con el mouse quieto antes de que la cámara vuelva sola (RF-28 CA5).
const ESPERA_DE_LA_VUELTA: float = 3.0
## Radianes por segundo de la vuelta automática, en rumbo y en inclinación.
## La mitad del máximo de RNF-14 para que la vuelta no se note como un tirón.
const GIRO_DE_VUELTA: float = PI / 2.0
## Por debajo de esta rapidez (m/s) el personaje está quieto y la cámara no
## vuelve sola: si se detuvo a mirar alrededor, la vista queda donde la dejó.
const RAPIDEZ_PARA_VOLVER: float = 0.5
## Si el personaje mira a más de este ángulo del rumbo de la cámara (por
## ejemplo, al caminar hacia ella con S), la vuelta no lo persigue: si lo
## hiciera, daría media vuelta y S pasaría a significar lo contrario.
const ANGULO_DE_SEGUIMIENTO: float = deg_to_rad(100.0)
## Tope de giro del «arriba» del soporte: 180°/s, el máximo que permite
## RNF-14. Sólo actúa si el personaje se reubica de golpe.
const GIRO_MAXIMO: float = PI
## Suavizado exponencial de la posición: más alto, sigue más pegada.
const SUAVIZADO_DE_POSICION: float = 8.0
## Ante un obstáculo la cámara se acerca rápido para no atravesarlo...
const SUAVIZADO_AL_ACERCARSE: float = 20.0
## ...y vuelve a alejarse despacio para que no rebote.
const SUAVIZADO_AL_ALEJARSE: float = 3.0

@export var objetivo: Jugador

@onready var _brazo: SpringArm3D = $Brazo
@onready var _camara: Camera3D = $Camara

## Distancia suavizada de la cámara al pivote del brazo.
var _distancia: float
var _arriba: Vector3
var _adelante: Vector3
var _inclinacion: float = INCLINACION_POR_DEFECTO
## Segundos desde el último movimiento del mouse.
var _sin_mouse: float = 0.0


func _ready() -> void:
	# Sin objetivo no hay a quién seguir: se avisa con un mensaje claro en vez
	# de dejar que falle más abajo al pedirle el RID a un nulo.
	if objetivo == null:
		push_error("CamaraSeguidora: falta asignar «objetivo» (el Jugador) en la escena.")
		set_physics_process(false)
		set_process_unhandled_input(false)
		return
	# El brazo no tiene que chocar con el propio personaje.
	_brazo.add_excluded_object(objetivo.get_rid())
	global_transform = objetivo.global_transform
	_arriba = global_basis.y
	_adelante = -global_basis.z
	_distancia = _brazo.spring_length
	_inclinar_brazo()
	_ubicar_camara()


func _unhandled_input(evento: InputEvent) -> void:
	var movimiento: InputEventMouseMotion = evento as InputEventMouseMotion
	if movimiento == null:
		return
	# `screen_relative` y no `relative`: está en píxeles de la pantalla, sin
	# el escalado de la interfaz, así la sensibilidad es la misma con
	# cualquier resolución. Mouse a la derecha, la vista gira a la derecha;
	# mouse arriba, la vista sube, así que la cámara baja (RF-28 CA2).
	var desplazamiento: Vector2 = movimiento.screen_relative
	_adelante = _adelante.rotated(_arriba, -desplazamiento.x * SENSIBILIDAD)
	_inclinacion = clampf(_inclinacion + desplazamiento.y * SENSIBILIDAD, INCLINACION_MINIMA, INCLINACION_MAXIMA)
	_sin_mouse = 0.0
	global_basis = GeometriaEsferica.base_alineada(_arriba, _adelante)
	_inclinar_brazo()
	_ubicar_camara()
	get_viewport().set_input_as_handled()


func _physics_process(delta: float) -> void:
	var arriba: Vector3 = GeometriaEsferica.arriba_en(objetivo.global_position, Planeta.CENTRO)
	_arriba = GeometriaEsferica.girar_vector_hacia(_arriba, arriba, GIRO_MAXIMO * delta)
	# Transporte del rumbo: se reproyecta sobre el plano del nuevo «arriba».
	_adelante = GeometriaEsferica.base_alineada(_arriba, _adelante) * Vector3.FORWARD

	_sin_mouse += delta
	if _sin_mouse >= ESPERA_DE_LA_VUELTA and objetivo.rapidez() > RAPIDEZ_PARA_VOLVER:
		_volver(delta)

	var posicion: Vector3 = global_position.lerp(
		objetivo.global_position, 1.0 - exp(-SUAVIZADO_DE_POSICION * delta)
	)
	global_transform = Transform3D(GeometriaEsferica.base_alineada(_arriba, _adelante), posicion)
	_inclinar_brazo()

	# El SpringArm3D calcula hasta dónde llega sin chocar, pero salta de golpe;
	# la cámara se mueve hacia ese largo con suavizado (RNF-14 CA2).
	var largo_libre: float = _brazo.get_hit_length()
	var suavizado: float = SUAVIZADO_AL_ACERCARSE if largo_libre < _distancia else SUAVIZADO_AL_ALEJARSE
	_distancia = lerpf(_distancia, largo_libre, 1.0 - exp(-suavizado * delta))
	_ubicar_camara()


## Vuelta automática hacia atrás del personaje y a la inclinación por
## defecto, acotada a GIRO_DE_VUELTA (RF-28 CA5, RNF-14 CA1).
func _volver(delta: float) -> void:
	var mirada: Vector3 = objetivo.mirada()
	if GeometriaEsferica.angulo_en_plano(_adelante, mirada, _arriba) < ANGULO_DE_SEGUIMIENTO:
		_adelante = GeometriaEsferica.girar_hacia(_adelante, mirada, _arriba, GIRO_DE_VUELTA * delta)
	_inclinacion = move_toward(_inclinacion, INCLINACION_POR_DEFECTO, GIRO_DE_VUELTA * delta)


## El brazo se extiende sobre su +Z (hacia atrás); girarlo −inclinación
## sobre X lo levanta.
func _inclinar_brazo() -> void:
	_brazo.rotation = Vector3(-_inclinacion, 0.0, 0.0)


func _ubicar_camara() -> void:
	# La cámara queda en la punta del brazo mirando al pivote.
	_camara.global_transform = _brazo.global_transform.translated_local(Vector3(0.0, 0.0, _distancia))
