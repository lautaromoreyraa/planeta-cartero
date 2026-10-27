class_name Cartel
extends ObjetoEnSuperficie

## Cartel con la pista del orden de entrega (RF-14).
##
## Se puede leer siempre y sin límite (RNF-16): no guarda estado, sólo avisa
## con `leido` y la escena principal muestra el texto del config.

signal leido

@onready var _interactuable: Interactuable = $Interactuable


func _ready() -> void:
	super._ready()
	_interactuable.interactuado.connect(leido.emit)
