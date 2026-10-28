class_name Personaje
extends Node3D

## Modelo animado de la cartera (RF-29): elige la animación según lo que
## hace el jugador y reproduce los gestos de los momentos puntuales.
##
## Es una escena aparte con el modelo de Kenney adentro, así cambiar de
## personaje es reemplazar el hijo `Modelo` sin tocar el jugador. No mueve
## nada ni bloquea la entrada: un gesto se corta en cuanto el personaje
## camina o salta, así la jugadora nunca pierde el control (RF-29 CA4).

enum Gesto { RECOGER, INTERACTUAR, FESTEJAR }

## Nombres de las animaciones tal como vienen en los GLB de Mini Characters.
const QUIETA: StringName = &"idle"
const CAMINANDO: StringName = &"walk"
const SUBIENDO: StringName = &"jump"
const BAJANDO: StringName = &"fall"
const ANIMACION_DE_GESTO: Dictionary[Gesto, StringName] = {
	Gesto.RECOGER: &"pick-up",
	Gesto.INTERACTUAR: &"interact-right",
	Gesto.FESTEJAR: &"emote-yes",
}
## Los GLB traen todas las animaciones sin bucle; estas se repiten mientras
## dure el estado (RF-29 CA2). `fall` también, para una caída larga.
const EN_BUCLE: Array[StringName] = [QUIETA, CAMINANDO, BAJANDO]
## Por debajo de esta rapidez (m/s) el personaje se considera quieto: el
## frenado deja unos centímetros por segundo que no tienen que verse como pasos.
const RAPIDEZ_PARA_CAMINAR: float = 0.3
## Segundos de mezcla entre animaciones, para que no salte de pose.
const MEZCLA: float = 0.15

@onready var _animaciones: AnimationPlayer = $Modelo/AnimationPlayer

## Gesto en curso; vacío si no hay ninguno.
var _gesto: StringName = &""


func _ready() -> void:
	for nombre: StringName in EN_BUCLE:
		_animaciones.get_animation(nombre).loop_mode = Animation.LOOP_LINEAR
	_animaciones.animation_finished.connect(_al_terminar)
	_animaciones.play(QUIETA)


## Lo llama el jugador en cada frame de física con su estado.
func actualizar(en_el_piso: bool, rapidez: float, velocidad_vertical: float) -> void:
	var animacion: StringName = QUIETA
	if not en_el_piso:
		animacion = SUBIENDO if velocidad_vertical > 0.0 else BAJANDO
	elif rapidez > RAPIDEZ_PARA_CAMINAR:
		animacion = CAMINANDO
	if not _gesto.is_empty():
		if animacion == QUIETA:
			return
		_gesto = &""
	# `assigned_animation` y no `current_animation`: una animación sin bucle
	# que terminó (como `jump`) se queda en su última pose en vez de reiniciarse.
	if _animaciones.assigned_animation != animacion:
		_animaciones.play(animacion, MEZCLA)


func hacer_gesto(gesto: Gesto) -> void:
	_gesto = ANIMACION_DE_GESTO[gesto]
	_animaciones.play(_gesto, MEZCLA)


## Al terminar un gesto vuelve a la animación del estado en el próximo frame.
func _al_terminar(nombre: StringName) -> void:
	if nombre == _gesto:
		_gesto = &""
