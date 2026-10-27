class_name InventarioDeCartas
extends RefCounted

## Cartas que la jugadora lleva encima (RF-11, RF-12).
##
## No depende de escenas: guarda sólo los identificadores, que son también
## lo que serializa el guardado (RF-21 CA5). Cuenta las cartas juntadas;
## las que están en la mano las calcula la escena principal restando las
## entregadas.

signal cantidad_cambiada(cantidad: int)
## Recoger una carta es un checkpoint (RF-11 CA3): el guardado se conecta
## a esta señal.
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


## Copia de los ids juntados, para el guardado.
func ids() -> PackedStringArray:
	return _ids.duplicate()
