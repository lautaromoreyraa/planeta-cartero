extends SceneTree

## Tests de la entrega en orden de la zona 2 (RF-15 CA8, RF-17).
## Se corre solo con `godot --headless --script res://tests/test_secuencia_de_entrega.gd`.

const Afirmaciones := preload("res://tests/afirmaciones.gd")
const ORDEN: PackedStringArray = ["casa_c", "casa_a", "casa_d", "casa_b"]
const R := SecuenciaDeEntrega.Resultado


func _initialize() -> void:
	var fallas: PackedStringArray = correr(self)
	for falla: String in fallas:
		printerr("FALLA: ", falla)
	print("test_secuencia_de_entrega: %d fallas" % fallas.size())
	quit(1 if fallas.size() > 0 else 0)


static func correr(_arbol: SceneTree) -> PackedStringArray:
	var a: Afirmaciones = Afirmaciones.new()
	_probar_orden_correcto(a)
	_probar_error_en_la_primera(a)
	_probar_error_en_la_tercera(a)
	_probar_buzon_repetido(a)
	_probar_una_sola_carta(a)
	_probar_sin_cartas(a)
	_probar_restaurar(a)
	return a.fallas


## Entrega las casas de `casas` con las cartas en mano que quedan de
## `juntadas`, como lo hace el juego.
static func _entregar(secuencia: SecuenciaDeEntrega, casas: PackedStringArray, juntadas: int) -> Array[int]:
	var resultados: Array[int] = []
	for casa: String in casas:
		resultados.append(secuencia.entregar(casa, juntadas - secuencia.entregas()))
	return resultados


## RF-15 CA1 y CA7: el orden del config completa la zona con 4 correctas.
static func _probar_orden_correcto(a: Afirmaciones) -> void:
	var secuencia: SecuenciaDeEntrega = SecuenciaDeEntrega.new(ORDEN)
	var resultados: Array[int] = _entregar(secuencia, ORDEN, 4)
	a.verdadero(resultados == [R.CORRECTA, R.CORRECTA, R.CORRECTA, R.CORRECTA], "el orden correcto da 4 entregas correctas (%s)" % [resultados])
	a.verdadero(secuencia.completa(), "RF-15 CA7: la cuarta entrega completa la zona 2")
	a.verdadero(secuencia.digitos_revelados() == 4, "RF-19 CA6: completar la zona revela los 4 dígitos")


## RF-15 CA2 y RF-17 CA2: un error en la primera no avanza.
static func _probar_error_en_la_primera(a: Afirmaciones) -> void:
	var secuencia: SecuenciaDeEntrega = SecuenciaDeEntrega.new(ORDEN)
	a.verdadero(secuencia.entregar("casa_a", 4) == R.ERROR, "RF-15 CA2: empezar por otra casa es un error")
	a.verdadero(secuencia.entregas() == 0 and secuencia.digitos_revelados() == 0, "un error en la primera no revela nada")
	a.verdadero(secuencia.entregar("casa_c", 4) == R.CORRECTA, "RF-17 CA2: tras el error la siguiente correcta es la primera del orden")


## RF-17 CA2 a CA4: un error en la tercera reinicia, devuelve las cartas y
## conserva los dígitos.
static func _probar_error_en_la_tercera(a: Afirmaciones) -> void:
	var secuencia: SecuenciaDeEntrega = SecuenciaDeEntrega.new(ORDEN)
	_entregar(secuencia, PackedStringArray(["casa_c", "casa_a"]), 3)
	a.verdadero(3 - secuencia.entregas() == 1, "con 3 juntadas y 2 entregadas queda 1 en la mano")
	a.verdadero(secuencia.entregar("casa_b", 1) == R.ERROR, "la casa equivocada en la tercera es un error")
	a.verdadero(secuencia.entregas() == 0, "RF-17 CA2: el error reinicia la secuencia")
	a.verdadero(3 - secuencia.entregas() == 3, "RF-17 CA3: las cartas entregadas vuelven a la mano (3 en el HUD)")
	a.verdadero(secuencia.digitos_revelados() == 2, "RF-17 CA4: se conservan los 2 dígitos revelados")
	a.verdadero(not secuencia.fue_entregada("casa_c"), "RF-17 CA2: los buzones vuelven a aceptar cartas")
	var resultados: Array[int] = _entregar(secuencia, ORDEN, 4)
	a.verdadero(resultados == [R.CORRECTA, R.CORRECTA, R.CORRECTA, R.CORRECTA], "RF-17 CA5: después del error se completa igual")


## RF-15 CA3: un buzón ya entregado no acepta otra carta.
static func _probar_buzon_repetido(a: Afirmaciones) -> void:
	var secuencia: SecuenciaDeEntrega = SecuenciaDeEntrega.new(ORDEN)
	secuencia.entregar("casa_c", 4)
	a.verdadero(secuencia.entregar("casa_c", 3) == R.YA_ENTREGADA, "RF-15 CA3: el mismo buzón no acepta una segunda carta")
	a.verdadero(secuencia.entregas() == 1, "un buzón repetido no cambia la secuencia ni cuenta como error")
	_entregar(secuencia, PackedStringArray(["casa_a", "casa_d", "casa_b"]), 4)
	a.verdadero(secuencia.entregar("casa_c", 4) == R.YA_ENTREGADA, "con la zona completa ningún buzón acepta cartas")
	a.verdadero(secuencia.completa(), "la zona completa no se pierde")


## RF-15 CA5 y CA6: se entrega desde la primera carta juntada.
static func _probar_una_sola_carta(a: Afirmaciones) -> void:
	var secuencia: SecuenciaDeEntrega = SecuenciaDeEntrega.new(ORDEN)
	a.verdadero(secuencia.entregar("casa_c", 1) == R.CORRECTA, "RF-15 CA5: con 1 carta el primer buzón es una entrega correcta")
	a.verdadero(secuencia.entregar("casa_a", 0) == R.SIN_CARTAS, "sin cartas en la mano no se puede seguir")
	a.verdadero(secuencia.entregas() == 1, "intentar sin cartas no cambia la secuencia")


## RF-15 CA4: sin cartas, ningún buzón cambia el estado.
static func _probar_sin_cartas(a: Afirmaciones) -> void:
	var secuencia: SecuenciaDeEntrega = SecuenciaDeEntrega.new(ORDEN)
	a.verdadero(secuencia.entregar("casa_a", 0) == R.SIN_CARTAS, "RF-15 CA4: sin cartas el buzón avisa y no es error")
	a.verdadero(secuencia.entregas() == 0 and secuencia.digitos_revelados() == 0, "RF-15 CA4: sin cartas no cambia el estado")


## RF-21 CA3: restaurar sólo acepta estados posibles.
static func _probar_restaurar(a: Afirmaciones) -> void:
	var secuencia: SecuenciaDeEntrega = SecuenciaDeEntrega.new(ORDEN)
	a.verdadero(secuencia.restaurar(1, 3), "se restaura 1 entrega con 3 dígitos revelados")
	a.verdadero(secuencia.fue_entregada("casa_c") and not secuencia.fue_entregada("casa_a"), "tras restaurar, el primer buzón figura entregado")
	a.verdadero(secuencia.entregar("casa_a", 2) == R.CORRECTA, "tras restaurar sigue la secuencia")
	a.verdadero(not secuencia.restaurar(3, 2), "no se restauran menos dígitos que entregas")
	a.verdadero(not secuencia.restaurar(5, 5), "no se restauran más entregas que casas")
	a.verdadero(secuencia.entregas() == 2, "una restauración rechazada no cambia nada")
