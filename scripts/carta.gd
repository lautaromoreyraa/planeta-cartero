class_name Carta
extends ObjetoEnSuperficie

## Carta recolectable de la zona 1 (RF-10, RF-11).
##
## No sabe nada del inventario: avisa con `recogida` y la escena principal
## decide si la acepta y la retira (RNF-20). Gira despacio para que se vea
## de lejos sobre el planeta, sobre todo las que están en techos.

signal recogida(carta: Carta)

## Radianes por segundo del giro de la malla.
const VELOCIDAD_DE_GIRO: float = PI / 2.0

## Identificador de `recoleccion.cartas` del config; es lo que se guarda.
@export var id: String = ""

@onready var _malla: Node3D = $Malla
@onready var _interactuable: Interactuable = $Interactuable


func _ready() -> void:
	super._ready()
	_interactuable.interactuado.connect(_al_interactuar)


func _process(delta: float) -> void:
	_malla.rotate_y(VELOCIDAD_DE_GIRO * delta)


## Saca la carta del planeta. Se deshabilita antes de liberarla para que el
## detector deje de elegirla en el mismo frame.
func retirar() -> void:
	_interactuable.habilitado = false
	queue_free()


func _al_interactuar() -> void:
	recogida.emit(self)
