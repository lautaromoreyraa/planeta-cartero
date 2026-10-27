class_name DetectorDeInteraccion
extends Node3D

## Busca el interactuable más cercano al jugador y le pasa la tecla E (RF-06).
##
## Va como hijo del jugador, a la altura del pecho, para que la distancia se
## mida desde el cuerpo y no desde los pies. Avisa con una señal cuando
## cambia el objeto en rango, y el HUD la usa para mostrar el indicador.

signal objetivo_cambiado(objetivo: Interactuable)

## Metros desde el pecho del jugador. Corto a propósito: desde el piso no
## alcanza una carta apoyada en un techo, hay que saltar (RF-10 CA2).
const RADIO: float = 1.4

var _objetivo: Interactuable = null


func _physics_process(_delta: float) -> void:
	_actualizar_objetivo()
	if _objetivo != null and Input.is_action_just_pressed("interact"):
		_objetivo.interactuar()
		# El objeto pudo retirarse al usarlo; se vuelve a elegir en el mismo
		# frame para no quedar apuntando a algo que se va a liberar.
		_actualizar_objetivo()


func _actualizar_objetivo() -> void:
	var candidatos: Array[Interactuable] = []
	var posiciones: PackedVector3Array = PackedVector3Array()
	for nodo: Node in get_tree().get_nodes_in_group(Interactuable.GRUPO):
		var interactuable: Interactuable = nodo as Interactuable
		if interactuable != null and interactuable.habilitado:
			candidatos.append(interactuable)
			posiciones.append(interactuable.global_position)

	var nuevo: Interactuable = null
	var indice: int = SeleccionDeInteractuable.indice_del_mas_cercano(global_position, posiciones, RADIO)
	if indice >= 0:
		nuevo = candidatos[indice]
	if nuevo != _objetivo:
		_objetivo = nuevo
		objetivo_cambiado.emit(_objetivo)
