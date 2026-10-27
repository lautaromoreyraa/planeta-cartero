class_name Oficina
extends ObjetoEnSuperficie

## Oficina de correo de la zona 3: puerta con candado y la carta final
## adentro (RF-18 a RF-20).
##
## No sabe si la zona 2 está completa ni cuál es el código: avisa con
## señales y la escena principal decide (RNF-20). Al abrirse, la puerta
## desaparece y la carta final se puede usar desde el umbral.

signal puerta_usada
signal carta_final_usada

@onready var _puerta: StaticBody3D = $Puerta
@onready var _interactuable_de_la_puerta: Interactuable = $InteractuableDeLaPuerta
@onready var _carta_final: Node3D = $CartaFinal
@onready var _interactuable_de_la_carta: Interactuable = $CartaFinal/Interactuable


func _ready() -> void:
	super._ready()
	_interactuable_de_la_carta.habilitado = false
	_interactuable_de_la_puerta.interactuado.connect(puerta_usada.emit)
	_interactuable_de_la_carta.interactuado.connect(carta_final_usada.emit)


## Abre la puerta para siempre en esta partida (RF-18 CA3).
func abrir() -> void:
	_interactuable_de_la_puerta.habilitado = false
	_interactuable_de_la_carta.habilitado = true
	_carta_final.visible = true
	_puerta.queue_free()
