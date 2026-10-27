class_name EstadoDePartida
extends RefCounted

## Progreso de una partida en un checkpoint (RF-21), sin depender de escenas
## para poder probarlo headless (RT-05).
##
## Guarda sólo estado del juego: ids de cartas, cantidades y banderas. Nada
## de textos, rutas ni el código del candado, que salen siempre del config
## (RF-21 CA5, RNF-02). Los buzones entregados no se guardan aparte porque
## son los primeros `entregas` de `entrega.orden`.

const VERSION: int = 1

## Ids de las cartas juntadas: las demás siguen en el planeta.
var cartas_recogidas: PackedStringArray = PackedStringArray()
## Entregas correctas de la secuencia actual (índice de la secuencia).
var entregas: int = 0
var digitos_revelados: int = 0
var candado_abierto: bool = false


func a_diccionario() -> Dictionary:
	return {
		"version": VERSION,
		"cartas_recogidas": Array(cartas_recogidas),
		"entregas": entregas,
		"digitos_revelados": digitos_revelados,
		"candado_abierto": candado_abierto,
	}


func es_igual(otro: EstadoDePartida) -> bool:
	return otro != null and a_diccionario() == otro.a_diccionario()


## Estado leído de `datos`, o nulo si no es un guardado coherente con el
## config cargado: claves faltantes, tipos inesperados, ids de cartas que no
## existen o combinaciones imposibles (RF-21 CA6).
static func desde_diccionario(datos: Variant, ids_de_cartas: PackedStringArray, cantidad_de_casas: int) -> EstadoDePartida:
	if not datos is Dictionary:
		return null
	var diccionario: Dictionary = datos
	if _entero(diccionario.get("version")) != VERSION:
		return null
	var recogidas: Variant = diccionario.get("cartas_recogidas")
	var entregas_leidas: int = _entero(diccionario.get("entregas"))
	var digitos_leidos: int = _entero(diccionario.get("digitos_revelados"))
	var candado: Variant = diccionario.get("candado_abierto")
	if not recogidas is Array or not candado is bool:
		return null

	var estado: EstadoDePartida = EstadoDePartida.new()
	for id: Variant in recogidas:
		if not id is String or not ids_de_cartas.has(id) or estado.cartas_recogidas.has(id):
			return null
		estado.cartas_recogidas.append(id)
	estado.entregas = entregas_leidas
	estado.digitos_revelados = digitos_leidos
	estado.candado_abierto = candado
	return estado if estado._es_posible(cantidad_de_casas) else null


## Las entregas no superan las cartas juntadas ni las casas; los dígitos
## revelados son al menos las entregas actuales; el candado sólo se abre con
## la zona 2 completa.
func _es_posible(cantidad_de_casas: int) -> bool:
	if entregas < 0 or entregas > mini(cartas_recogidas.size(), cantidad_de_casas):
		return false
	if digitos_revelados < entregas or digitos_revelados > mini(cartas_recogidas.size(), cantidad_de_casas):
		return false
	return not candado_abierto or entregas == cantidad_de_casas


## JSON lee todos los números como float: se acepta sólo si es entero.
## Devuelve -1 (inválido para todos los campos) si no lo es.
static func _entero(valor: Variant) -> int:
	if valor is int:
		return valor
	if valor is float and is_equal_approx(valor, roundf(valor)):
		return roundi(valor)
	return -1
