class_name CamaraSeguidora
extends Node3D

## Cámara en tercera persona que sigue a la cartera desde atrás y arriba (RF-05).
##
## El soporte copia el «arriba» del personaje y transporta su propio rumbo por
## la superficie, igual que el personaje, así que en los polos no hay giros
## bruscos. No responde al mouse: sólo se acomoda detrás del personaje.
##
## La luz direccional («Sol») va dentro de este soporte a propósito: en un
## planeta tan chico una luz fija dejaría de noche la mitad del mundo, y
## colgada de la cámara ilumina siempre la zona donde se juega.

## Tope de giro del soporte: 180°/s, el máximo que permite RNF-14.
const GIRO_MAXIMO: float = PI
## Radianes por segundo con los que el rumbo se acomoda detrás del personaje.
## Bastante más lento que el personaje para que la cámara acompañe sin sacudir.
const GIRO_DE_RUMBO: float = PI / 2.0
## Si el personaje mira a más de este ángulo del rumbo de la cámara (por
## ejemplo, al caminar hacia ella con S), la cámara no lo persigue: si lo
## hiciera, daría media vuelta y S pasaría a significar lo contrario.
const ANGULO_DE_SEGUIMIENTO: float = deg_to_rad(100.0)
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


func _ready() -> void:
	# Sin objetivo no hay a quién seguir: se avisa con un mensaje claro en vez
	# de dejar que falle más abajo al pedirle el RID a un nulo.
	if objetivo == null:
		push_error("CamaraSeguidora: falta asignar «objetivo» (el Jugador) en la escena.")
		set_physics_process(false)
		return
	# El brazo no tiene que chocar con el propio personaje.
	_brazo.add_excluded_object(objetivo.get_rid())
	global_transform = objetivo.global_transform
	_distancia = _brazo.spring_length
	_ubicar_camara()


func _physics_process(delta: float) -> void:
	var arriba: Vector3 = GeometriaEsferica.arriba_en(objetivo.global_position, Planeta.CENTRO)
	var adelante: Vector3 = -global_basis.z
	var mirada: Vector3 = objetivo.mirada()
	if GeometriaEsferica.angulo_en_plano(adelante, mirada, arriba) < ANGULO_DE_SEGUIMIENTO:
		adelante = GeometriaEsferica.girar_hacia(adelante, mirada, arriba, GIRO_DE_RUMBO * delta)

	var deseada: Quaternion = GeometriaEsferica.base_alineada(arriba, adelante).get_rotation_quaternion()
	var rotacion: Quaternion = GeometriaEsferica.rotar_hacia(
		global_basis.get_rotation_quaternion(), deseada, GIRO_MAXIMO * delta
	)
	var posicion: Vector3 = global_position.lerp(
		objetivo.global_position, 1.0 - exp(-SUAVIZADO_DE_POSICION * delta)
	)
	global_transform = Transform3D(Basis(rotacion), posicion)

	# El SpringArm3D calcula hasta dónde llega sin chocar, pero salta de golpe;
	# la cámara se mueve hacia ese largo con suavizado (RNF-14 CA2).
	var largo_libre: float = _brazo.get_hit_length()
	var suavizado: float = SUAVIZADO_AL_ACERCARSE if largo_libre < _distancia else SUAVIZADO_AL_ALEJARSE
	_distancia = lerpf(_distancia, largo_libre, 1.0 - exp(-suavizado * delta))
	_ubicar_camara()


func _ubicar_camara() -> void:
	# El brazo se extiende sobre su +Z; la cámara queda en la punta mirando al pivote.
	_camara.global_transform = _brazo.global_transform.translated_local(Vector3(0.0, 0.0, _distancia))
