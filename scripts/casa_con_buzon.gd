class_name CasaConBuzon
extends ObjetoEnSuperficie

## Casa de la zona 2 con su buzón y su rótulo (RF-13).
##
## El id y el rótulo los asigna la escena principal desde `entrega.casas`
## del config, por posición, así Lautaro puede renombrar las casas sin tocar
## escenas. El buzón no sabe de la secuencia: avisa con `buzon_usado` y la
## escena principal decide (RNF-20).

signal buzon_usado(casa: CasaConBuzon)

## Grados que gira la banderita del buzón cuando ya recibió su carta.
const GIRO_DE_LA_BANDERA: float = 90.0

## Identificador de `entrega.casas`; es lo que se compara con `entrega.orden`.
var id: String = ""

@onready var _interactuable: Interactuable = $Buzon/Interactuable
@onready var _bandera: Node3D = $Buzon/Bandera
@onready var _rotulo: Label3D = $Buzon/Rotulo


func _ready() -> void:
	super._ready()
	_interactuable.interactuado.connect(_al_usar_el_buzon)


func configurar(nuevo_id: String, rotulo: String) -> void:
	id = nuevo_id
	_rotulo.text = rotulo


## Dónde está el buzón, para la guía (RF-30 CA4).
func posicion_del_buzon() -> Vector3:
	return _interactuable.global_position


## Un buzón entregado no acepta otra carta (RF-15 CA3): se apaga, así ni
## siquiera aparece la E, y la bandera levantada lo muestra de lejos.
func marcar_entregado(entregado: bool) -> void:
	_interactuable.habilitado = not entregado
	_bandera.rotation_degrees.z = GIRO_DE_LA_BANDERA if entregado else 0.0


func _al_usar_el_buzon() -> void:
	buzon_usado.emit(self)
