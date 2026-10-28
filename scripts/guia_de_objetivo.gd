class_name GuiaDeObjetivo
extends RefCounted

## Elige hacia dónde apunta la guía en pantalla (RF-30), sin depender de
## escenas para poder probarla headless.
##
## No conoce `entrega.orden`: en la fase de entrega mira sólo qué buzones
## siguen pendientes y elige el más cercano a la jugadora, así la guía
## ayuda a no perderse sin revelar el orden (RF-30 CA5).


## Posición a la que apunta la guía según la fase del juego:
## 1. Con el candado abierto, la carta final.
## 2. Con la zona 2 completa, la puerta de la oficina (RF-30 CA6).
## 3. Con cartas sin juntar, la más cercana (RF-30 CA3); también después de
##    un error, si todavía quedan cartas en el planeta.
## 4. Si no, el buzón pendiente más cercano: uno que no recibió su carta en
##    la secuencia actual (RF-30 CA4).
## `ids_de_buzones` y `buzones` van en paralelo.
static func elegir(
	jugadora: Vector3,
	cartas: PackedVector3Array,
	ids_de_buzones: PackedStringArray,
	buzones: PackedVector3Array,
	secuencia: SecuenciaDeEntrega,
	puerta: Vector3,
	carta_final: Vector3,
	candado_abierto: bool
) -> Vector3:
	if candado_abierto:
		return carta_final
	if secuencia.completa():
		return puerta
	if not cartas.is_empty():
		return _mas_cercana(jugadora, cartas)
	var pendientes: PackedVector3Array = PackedVector3Array()
	for i: int in range(mini(ids_de_buzones.size(), buzones.size())):
		if not secuencia.fue_entregada(ids_de_buzones[i]):
			pendientes.append(buzones[i])
	# Sin pendientes la secuencia estaría completa; la puerta es el respaldo.
	return puerta if pendientes.is_empty() else _mas_cercana(jugadora, pendientes)


static func _mas_cercana(origen: Vector3, posiciones: PackedVector3Array) -> Vector3:
	return posiciones[SeleccionDeInteractuable.indice_del_mas_cercano(origen, posiciones, INF)]
