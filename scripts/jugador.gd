class_name Jugador
extends CharacterBody3D

## La cartera: camina, salta y cae siempre hacia el centro del planeta.
##
## En cada frame «arriba» se recalcula desde el centro (RT-09): se actualiza
## `up_direction` para que `is_on_floor()` funcione en cualquier punto, la
## gravedad tira hacia el centro y el cuerpo se alinea con la superficie.

## Metros por segundo. Con el radio del planeta, una vuelta dura unos 12,6 s.
const VELOCIDAD: float = 5.0
## Alta para que arranque y frene casi en seco: frena en ~0,13 s (RF-03 CA2).
const ACELERACION: float = 40.0
const GRAVEDAD: float = 20.0
## Altura del salto = IMPULSO² / (2·GRAVEDAD) ≈ 2 m: alcanza los techos (1,5 m)
## y, como la gravedad no se debilita con la altura, nunca saca del planeta.
const IMPULSO_DE_SALTO: float = 9.0
## Radianes por segundo con los que el cuerpo gira hacia donde camina.
const VELOCIDAD_DE_GIRO: float = 4.0 * PI
## Más lejos que esto del centro se considera perdido y se reubica (RNF-13).
const DISTANCIA_MAXIMA: float = Planeta.RADIO + 15.0
## Más cerca que esto del centro atravesó el suelo: también se reubica.
const DISTANCIA_MINIMA: float = Planeta.RADIO * 0.5

## Lugar despejado donde empieza la partida; se usa también para reubicar.
var _punto_seguro: Vector3


func _ready() -> void:
	_punto_seguro = global_position
	_alinear(GeometriaEsferica.arriba_en(global_position, Planeta.CENTRO), -global_basis.z)


func _physics_process(delta: float) -> void:
	if GeometriaEsferica.fuera_de_rango(global_position, Planeta.CENTRO, DISTANCIA_MINIMA, DISTANCIA_MAXIMA):
		_reubicar()

	var arriba: Vector3 = GeometriaEsferica.arriba_en(global_position, Planeta.CENTRO)
	up_direction = arriba

	# La velocidad se separa en la parte que sube o baja y la que recorre la
	# superficie, para que la entrada sólo toque la segunda.
	var vertical: Vector3 = arriba * velocity.dot(arriba)
	var horizontal: Vector3 = velocity - vertical
	var deseada: Vector3 = _direccion_de_entrada(arriba) * VELOCIDAD
	horizontal = horizontal.move_toward(deseada, ACELERACION * delta)

	if is_on_floor() and Input.is_action_just_pressed("jump"):
		vertical = arriba * IMPULSO_DE_SALTO
	else:
		vertical -= arriba * GRAVEDAD * delta
	velocity = horizontal + vertical

	var rumbo: Vector3 = -global_basis.z
	if deseada.length_squared() > GeometriaEsferica.EPSILON:
		rumbo = GeometriaEsferica.girar_hacia(rumbo, deseada, arriba, VELOCIDAD_DE_GIRO * delta)
	_alinear(arriba, rumbo)

	move_and_slide()


## Hacia dónde mira el personaje sobre la superficie; la cámara lo sigue.
func mirada() -> Vector3:
	return -global_basis.z


func _alinear(arriba: Vector3, mirada_deseada: Vector3) -> void:
	global_basis = GeometriaEsferica.base_alineada(arriba, mirada_deseada)


func _direccion_de_entrada(arriba: Vector3) -> Vector3:
	var entrada: Vector2 = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var camara: Camera3D = get_viewport().get_camera_3d()
	if camara == null or entrada == Vector2.ZERO:
		return Vector3.ZERO
	return GeometriaEsferica.direccion_relativa(entrada, camara.global_basis, arriba)


func _reubicar() -> void:
	global_position = _punto_seguro
	velocity = Vector3.ZERO
