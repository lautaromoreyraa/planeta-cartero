class_name Jugador
extends CharacterBody3D

## La cartera: camina, salta y cae siempre hacia el centro del planeta.
##
## En cada frame «arriba» se recalcula desde el centro (RT-09): se actualiza
## `up_direction` para que `is_on_floor()` funcione en cualquier punto, la
## gravedad tira hacia el centro y el cuerpo se alinea con la superficie.
## El modelo animado vive en su propia escena (`Personaje`): el jugador sólo
## le cuenta qué está haciendo.

## Metros por segundo. Con el radio del planeta, una vuelta dura unos 12,6 s.
const VELOCIDAD: float = 5.0
## Arranque progresivo: llega a la velocidad máxima en 0,25 s, así el primer
## frame es más lento que el máximo y a los 0,3 s ya está a fondo (RF-03 CA3).
const ACELERACION: float = 20.0
## Frenado más brusco que el arranque: se detiene en ~0,17 s (RF-03 CA2).
const FRENADO: float = 30.0
## Gravedad de la subida. La altura del salto es IMPULSO² / (2·GRAVEDAD).
const GRAVEDAD: float = 20.0
## La bajada usa más gravedad que la subida (RF-04 CA6): el salto se siente
## menos flotante y la altura máxima no cambia, porque sólo depende de la subida.
const MULTIPLICADOR_DE_CAIDA: float = 1.6
## Altura del salto ≈ 2 m: alcanza el techo de las casas (1,65 m) y las
## plataformas (1,4 m) con margen y, como la gravedad no se debilita con la
## altura, nunca saca del planeta (RF-04 CA3).
const IMPULSO_DE_SALTO: float = 9.0
## Radianes por segundo con los que el cuerpo gira hacia donde camina: media
## vuelta dura 0,25 s, progresiva pero sin sentirse lenta (RF-03 CA4).
const VELOCIDAD_DE_GIRO: float = 4.0 * PI
## Más lejos que esto del centro se considera perdido y se reubica (RNF-13).
const DISTANCIA_MAXIMA: float = Planeta.RADIO + 15.0
## Más cerca que esto del centro atravesó el suelo: también se reubica.
const DISTANCIA_MINIMA: float = Planeta.RADIO * 0.5

@onready var _personaje: Personaje = $Personaje

## Lugar despejado donde empieza la partida; se usa también para reubicar.
var _punto_seguro: Vector3
var _salto: ControlDeSalto = ControlDeSalto.new()


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
	var cambio: float = ACELERACION if deseada.length_squared() > GeometriaEsferica.EPSILON else FRENADO
	horizontal = horizontal.move_toward(deseada, cambio * delta)

	if _salto.actualizar(delta, is_on_floor(), Input.is_action_just_pressed("jump")):
		vertical = arriba * IMPULSO_DE_SALTO
	else:
		var cayendo: bool = vertical.dot(arriba) < 0.0
		vertical -= arriba * GRAVEDAD * (MULTIPLICADOR_DE_CAIDA if cayendo else 1.0) * delta
	velocity = horizontal + vertical

	var rumbo: Vector3 = -global_basis.z
	if deseada.length_squared() > GeometriaEsferica.EPSILON:
		rumbo = GeometriaEsferica.girar_hacia(rumbo, deseada, arriba, VELOCIDAD_DE_GIRO * delta)
	_alinear(arriba, rumbo)

	move_and_slide()
	# Después del deslizamiento: contra una pared la velocidad real es cero y
	# el personaje no tiene que caminar en el lugar.
	_personaje.actualizar(is_on_floor(), rapidez(), velocity.dot(arriba))


## Hacia dónde mira el personaje sobre la superficie; la cámara lo sigue.
func mirada() -> Vector3:
	return -global_basis.z


## Velocidad sobre la superficie, en metros por segundo. La cámara la usa
## para saber si el personaje camina (RF-28 CA5).
func rapidez() -> float:
	var arriba: Vector3 = GeometriaEsferica.arriba_en(global_position, Planeta.CENTRO)
	return GeometriaEsferica.proyectar_en_plano(velocity, arriba).length()


## Animación de un momento puntual: recoger, interactuar o festejar (RF-29 CA4).
func hacer_gesto(gesto: Personaje.Gesto) -> void:
	_personaje.hacer_gesto(gesto)


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
