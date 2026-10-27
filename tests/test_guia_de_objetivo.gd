extends SceneTree

## Tests de GuiaDeObjetivo: a qué apunta la guía en cada fase y que cambiar
## `entrega.orden` no cambie el objetivo (RF-30 CA3 a CA6).
## Se corre solo con `godot --headless --script res://tests/test_guia_de_objetivo.gd`.

const Afirmaciones := preload("res://tests/afirmaciones.gd")

const IDS: PackedStringArray = ["casa_a", "casa_b", "casa_c", "casa_d"]
const BUZONES: PackedVector3Array = [Vector3(10, 0, 0), Vector3(0, 0, 10), Vector3(-10, 0, 0), Vector3(0, 0, -10)]
const PUERTA: Vector3 = Vector3(7, 7, 0)
const CARTA_FINAL: Vector3 = Vector3(7, 6, 0)
## Órdenes distintos que comparten las dos primeras casas, para comparar el
## mismo estado (las mismas casas entregadas) con un orden y con otro.
const ORDENES: Array[PackedStringArray] = [
	["casa_c", "casa_a", "casa_d", "casa_b"],
	["casa_c", "casa_a", "casa_b", "casa_d"],
]
## Posiciones de la jugadora desde donde se compara.
const POSICIONES: PackedVector3Array = [
	Vector3(0, 10, 0), Vector3(9, 1, 1), Vector3(-1, 1, 9), Vector3(-9, -1, 1), Vector3(1, -1, -9), Vector3(0, -10, 0),
]


func _initialize() -> void:
	var fallas: PackedStringArray = correr(self)
	for falla: String in fallas:
		printerr("FALLA: ", falla)
	print("test_guia_de_objetivo: %d fallas" % fallas.size())
	quit(1 if fallas.size() > 0 else 0)


static func correr(_arbol: SceneTree) -> PackedStringArray:
	var a: Afirmaciones = Afirmaciones.new()
	_probar_recoleccion(a)
	_probar_entrega(a)
	_probar_sin_revelar_el_orden(a)
	_probar_oficina_y_final(a)
	return a.fallas


static func _elegir(jugadora: Vector3, cartas: PackedVector3Array, secuencia: SecuenciaDeEntrega, candado_abierto: bool = false) -> Vector3:
	return GuiaDeObjetivo.elegir(jugadora, cartas, IDS, BUZONES, secuencia, PUERTA, CARTA_FINAL, candado_abierto)


static func _secuencia(orden: PackedStringArray, entregas: int) -> SecuenciaDeEntrega:
	var secuencia: SecuenciaDeEntrega = SecuenciaDeEntrega.new(orden)
	secuencia.restaurar(entregas, entregas)
	return secuencia


## RF-30 CA3: con cartas en el planeta apunta a la más cercana, aunque ya
## haya cartas en la mano o entregas hechas.
static func _probar_recoleccion(a: Afirmaciones) -> void:
	var cartas: PackedVector3Array = [Vector3(0, 10, 1), Vector3(0, -10, 1)]
	a.vectores_cerca(_elegir(Vector3(0, 9, 3), cartas, _secuencia(ORDENES[0], 0)), cartas[0], 0.0, "RF-30 CA3: no apunta a la carta más cercana")
	a.vectores_cerca(_elegir(Vector3(0, -9, 3), cartas, _secuencia(ORDENES[0], 0)), cartas[1], 0.0, "RF-30 CA3: no apunta a la carta más cercana")
	a.vectores_cerca(_elegir(Vector3(9, 0, 0), cartas, _secuencia(ORDENES[0], 1)), cartas[0], 0.0, "RF-30 CA3: con cartas en el planeta apunta a un buzón")


## RF-30 CA4: con todas las cartas juntadas apunta al buzón pendiente más
## cercano y nunca a uno ya entregado en la secuencia actual.
static func _probar_entrega(a: Afirmaciones) -> void:
	var ninguna: PackedVector3Array = PackedVector3Array()
	a.vectores_cerca(_elegir(Vector3(9, 1, 0), ninguna, _secuencia(ORDENES[0], 0)), BUZONES[0], 0.0, "RF-30 CA4: no apunta al buzón más cercano")
	# casa_c y casa_a ya entregadas: junto a casa_a apunta a otra.
	var con_dos: SecuenciaDeEntrega = _secuencia(ORDENES[0], 2)
	for posicion: Vector3 in POSICIONES:
		var objetivo: Vector3 = _elegir(posicion, ninguna, con_dos)
		a.verdadero(objetivo != BUZONES[0] and objetivo != BUZONES[2], "RF-30 CA4: desde %s apunta a un buzón ya entregado" % posicion)
	# Después de un error la secuencia vuelve a cero: todos pendientes otra vez.
	var con_error: SecuenciaDeEntrega = _secuencia(ORDENES[0], 2)
	con_error.entregar("casa_b", 2)
	a.vectores_cerca(_elegir(Vector3(9, 1, 0), ninguna, con_error), BUZONES[0], 0.0, "RF-30 CA4: tras un error no vuelve a apuntar a todos los buzones")


## RF-30 CA5: para el mismo estado y la misma posición, el orden del config
## no cambia el objetivo.
static func _probar_sin_revelar_el_orden(a: Afirmaciones) -> void:
	var ninguna: PackedVector3Array = PackedVector3Array()
	var cartas: PackedVector3Array = [Vector3(3, 9, 0)]
	for entregas: int in [0, 2]:
		for posicion: Vector3 in POSICIONES:
			for quedan: PackedVector3Array in [ninguna, cartas]:
				var primero: Vector3 = _elegir(posicion, quedan, _secuencia(ORDENES[0], entregas))
				var segundo: Vector3 = _elegir(posicion, quedan, _secuencia(ORDENES[1], entregas))
				a.vectores_cerca(primero, segundo, 0.0, "RF-30 CA5: con %d entregas, desde %s, el orden cambia el objetivo" % [entregas, posicion])
	# Mismo estado inicial con todos los órdenes posibles de las casas.
	var invertido: PackedStringArray = ["casa_b", "casa_d", "casa_a", "casa_c"]
	for posicion: Vector3 in POSICIONES:
		a.vectores_cerca(
			_elegir(posicion, ninguna, _secuencia(invertido, 0)),
			_elegir(posicion, ninguna, _secuencia(ORDENES[0], 0)),
			0.0, "RF-30 CA5: desde %s, invertir el orden cambia el objetivo" % posicion
		)


## RF-30 CA6: con la zona 2 completa apunta a la puerta; con el candado
## abierto, a la carta final.
static func _probar_oficina_y_final(a: Afirmaciones) -> void:
	var ninguna: PackedVector3Array = PackedVector3Array()
	a.vectores_cerca(_elegir(Vector3(0, 10, 0), ninguna, _secuencia(ORDENES[0], 4)), PUERTA, 0.0, "RF-30 CA6: con la zona 2 completa no apunta a la puerta")
	a.vectores_cerca(_elegir(Vector3(0, 10, 0), ninguna, _secuencia(ORDENES[0], 4), true), CARTA_FINAL, 0.0, "con el candado abierto no apunta a la carta final")
