extends SceneTree

## Tests del candado de la oficina (RF-19 CA1, CA5 y CA7, RF-26 CA1).
## Se corre solo con `godot --headless --script res://tests/test_candado.gd`.

const Afirmaciones := preload("res://tests/afirmaciones.gd")


func _initialize() -> void:
	var fallas: PackedStringArray = correr(self)
	for falla: String in fallas:
		printerr("FALLA: ", falla)
	print("test_candado: %d fallas" % fallas.size())
	quit(1 if fallas.size() > 0 else 0)


static func correr(_arbol: SceneTree) -> PackedStringArray:
	var a: Afirmaciones = Afirmaciones.new()
	_probar_validacion(a)
	_probar_ingreso(a)
	_probar_digitos_revelados(a)
	return a.fallas


## RF-19 CA7: correcto, incorrecto, menos de 4 dígitos, no numéricos y ceros
## adelante.
static func _probar_validacion(a: Afirmaciones) -> void:
	a.verdadero(Candado.es_correcto("0427", "0427"), "el código correcto con cero adelante abre")
	a.verdadero(not Candado.es_correcto("4270", "0427"), "un código incorrecto no abre")
	a.verdadero(not Candado.es_correcto("427", "0427"), "menos de 4 dígitos no abre aunque coincida el número")
	a.verdadero(not Candado.es_correcto("042", "042"), "un código de 3 dígitos no es válido")
	a.verdadero(not Candado.es_correcto("04a7", "04a7"), "caracteres no numéricos no abren")
	a.verdadero(not Candado.es_correcto("+427", "+427"), "un signo no cuenta como dígito")
	a.verdadero(not Candado.es_correcto("", ""), "vacío no abre")
	a.verdadero(Candado.es_codigo_valido("0000"), "«0000» es un código válido")
	a.verdadero(not Candado.es_codigo_valido("04270"), "5 dígitos no es un código válido")
	a.verdadero(not Candado.es_codigo_valido("０４２７"), "dígitos de ancho completo no son válidos")


## RF-19 CA1: sólo dígitos, hasta 4, con borrado.
static func _probar_ingreso(a: Afirmaciones) -> void:
	var ingresado: String = ""
	for digito: String in ["0", "x", "4", "2", "7", "9"]:
		ingresado = Candado.agregar_digito(ingresado, digito)
	a.verdadero(ingresado == "0427", "se ignoran los no dígitos y el quinto dígito (quedó «%s»)" % ingresado)
	ingresado = Candado.borrar_digito(ingresado)
	a.verdadero(ingresado == "042", "borrar saca el último dígito (quedó «%s»)" % ingresado)
	a.verdadero(Candado.borrar_digito("") == "", "borrar sin dígitos no hace nada")
	a.verdadero(Candado.agregar_digito("", "12") == "", "no se agregan dos caracteres juntos")


## RF-19 CA5 y RF-26 CA1: el dígito de cada recuerdo y el código parcial.
static func _probar_digitos_revelados(a: Afirmaciones) -> void:
	var esperados: Array[String] = ["0", "4", "2", "7"]
	for posicion: int in range(1, 5):
		var digito: String = Candado.digito_revelado("0427", posicion)
		a.verdadero(digito == esperados[posicion - 1], "el recuerdo %d revela «%s»" % [posicion, digito])
	a.verdadero(Candado.digito_revelado("0427", 0) == "" and Candado.digito_revelado("0427", 5) == "", "fuera de 1 a 4 no hay dígito")
	a.verdadero(Candado.codigo_parcial("0427", 0, "_") == "_ _ _ _", "sin revelar se ven 4 ocultos")
	a.verdadero(Candado.codigo_parcial("0427", 2, "_") == "0 4 _ _", "con 2 revelados: «%s»" % Candado.codigo_parcial("0427", 2, "_"))
	a.verdadero(Candado.codigo_parcial("0427", 4, "*") == "0 4 2 7", "con 4 revelados se ve el código entero")
