class_name SeleccionDeInteractuable
extends RefCounted

## Elige sobre qué objeto actúa E (RF-06 CA2 y CA3), sin depender de escenas
## para poder probarlo headless.

## Índice de la posición más cercana a `origen` dentro de `radio` (inclusive),
## o -1 si ninguna está en rango. Con dos a la misma distancia gana la
## primera, para que la elección no salte entre frames.
static func indice_del_mas_cercano(origen: Vector3, posiciones: PackedVector3Array, radio: float) -> int:
	var elegido: int = -1
	var mejor: float = radio * radio
	for i: int in range(posiciones.size()):
		var distancia: float = origen.distance_squared_to(posiciones[i])
		if distancia <= mejor and (elegido == -1 or distancia < mejor):
			elegido = i
			mejor = distancia
	return elegido
