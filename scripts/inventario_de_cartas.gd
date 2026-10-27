class_name InventarioDeCartas
extends RefCounted

## Cartas que la jugadora lleva encima (RF-11, RF-12).
##
## No depende de escenas: guarda sólo los identificadores, que son también
## lo que va a serializar el guardado del hito 3 (RF-21 CA5).

signal cantidad_cambiada(cantidad: int)
## Recoger una carta es un checkpoint (RF-11 CA3): el guardado del hito 3
## se conecta a esta señal.
signal carta_recogida(id: String)

var _ids: PackedStringArray = PackedStringArray()


## Suma la carta y devuelve verdadero; si ya estaba o no tiene id, no hace
## nada y devuelve falso, para que una carta no se cuente dos veces (RF-11 CA2).
func recoger(id: String) -> bool:
	if id.is_empty() or _ids.has(id):
		return false
	_ids.append(id)
	cantidad_cambiada.emit(cantidad())
	carta_recogida.emit(id)
	return true


func cantidad() -> int:
	return _ids.size()
