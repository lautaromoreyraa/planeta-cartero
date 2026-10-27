class_name SecuenciaDeEntrega
extends RefCounted

## Reglas de la entrega en orden de la zona 2 (RF-15, RF-17), sin depender
## de escenas para poder probarlas headless (RT-05).
##
## Las cartas son intercambiables (RF-15 CA6), así que la secuencia sólo
## cuenta cuántas entregas correctas lleva: las cartas en la mano son las
## juntadas menos esas. Por eso, al reiniciar la secuencia tras un error, las
## entregadas vuelven solas al inventario (RF-17 CA3).

enum Resultado { CORRECTA, ERROR, YA_ENTREGADA, SIN_CARTAS }

var _orden: PackedStringArray
## Entregas correctas de la secuencia actual: los primeros `_entregas` ids
## de `_orden` ya recibieron su carta.
var _entregas: int = 0
## Máximo de entregas correctas alcanzado: los dígitos revelados no se
## pierden con un error (RF-17 CA4).
var _digitos_revelados: int = 0


func _init(orden: PackedStringArray) -> void:
	_orden = orden


## Entrega una carta en el buzón de `casa_id` con `cartas_en_mano` cartas.
func entregar(casa_id: String, cartas_en_mano: int) -> Resultado:
	if cartas_en_mano <= 0:
		return Resultado.SIN_CARTAS
	if fue_entregada(casa_id):
		return Resultado.YA_ENTREGADA
	if _entregas < _orden.size() and _orden[_entregas] == casa_id:
		_entregas += 1
		_digitos_revelados = maxi(_digitos_revelados, _entregas)
		return Resultado.CORRECTA
	_entregas = 0
	return Resultado.ERROR


## Verdadero si el buzón de `casa_id` ya recibió su carta en esta secuencia.
func fue_entregada(casa_id: String) -> bool:
	var posicion: int = _orden.find(casa_id)
	return posicion >= 0 and posicion < _entregas


func entregas() -> int:
	return _entregas


func digitos_revelados() -> int:
	return _digitos_revelados


## La cuarta entrega correcta completa la zona 2 (RF-15 CA7).
func completa() -> bool:
	return _entregas == _orden.size()


## Vuelve al estado de un guardado. Devuelve falso, sin cambiar nada, si los
## valores no son posibles para este orden.
func restaurar(entregas_guardadas: int, digitos_guardados: int) -> bool:
	if entregas_guardadas < 0 or entregas_guardadas > _orden.size():
		return false
	if digitos_guardados < entregas_guardadas or digitos_guardados > _orden.size():
		return false
	_entregas = entregas_guardadas
	_digitos_revelados = digitos_guardados
	return true
