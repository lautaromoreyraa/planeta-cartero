extends SceneTree

## Tests del guardado por checkpoints (RF-21 CA5 a CA7).
## Se corre solo con `godot --headless --script res://tests/test_guardado.gd`.

const Afirmaciones := preload("res://tests/afirmaciones.gd")
const RUTA_DE_PRUEBA: String = "user://test_guardado.json"
const IDS: PackedStringArray = ["carta_1", "carta_2", "carta_3", "carta_4"]
const CASAS: int = 4


func _initialize() -> void:
	var fallas: PackedStringArray = correr(self)
	for falla: String in fallas:
		printerr("FALLA: ", falla)
	print("test_guardado: %d fallas" % fallas.size())
	quit(1 if fallas.size() > 0 else 0)


static func correr(_arbol: SceneTree) -> PackedStringArray:
	var a: Afirmaciones = Afirmaciones.new()
	_probar_ida_y_vuelta(a)
	_probar_contenido(a)
	_probar_invalidos(a)
	_probar_archivos(a)
	return a.fallas


static func _estado(recogidas: Array[String], entregas: int, digitos: int, candado: bool) -> EstadoDePartida:
	var estado: EstadoDePartida = EstadoDePartida.new()
	estado.cartas_recogidas = PackedStringArray(recogidas)
	estado.entregas = entregas
	estado.digitos_revelados = digitos
	estado.candado_abierto = candado
	return estado


## Un estado por cada tipo de checkpoint (RF-21 CA1).
static func _checkpoints() -> Array[EstadoDePartida]:
	return [
		_estado(["carta_2"], 0, 0, false),
		_estado(["carta_2", "carta_4", "carta_1"], 2, 2, false),
		_estado(["carta_2", "carta_4", "carta_1"], 0, 2, false),
		_estado(["carta_1", "carta_2", "carta_3", "carta_4"], 4, 4, false),
		_estado(["carta_1", "carta_2", "carta_3", "carta_4"], 4, 4, true),
	]


## RF-21 CA7: guardar y leer devuelve el mismo estado en cada checkpoint.
static func _probar_ida_y_vuelta(a: Afirmaciones) -> void:
	for estado: EstadoDePartida in _checkpoints():
		a.verdadero(Guardado.escribir(RUTA_DE_PRUEBA, estado), "se escribe el guardado")
		var leido: EstadoDePartida = Guardado.leer(RUTA_DE_PRUEBA, IDS, CASAS)
		a.verdadero(estado.es_igual(leido), "RF-21 CA7: el estado %s vuelve igual" % [estado.a_diccionario()])
	Guardado.borrar(RUTA_DE_PRUEBA)


## RF-21 CA5: sólo estado del juego, sin textos ni el código.
static func _probar_contenido(a: Afirmaciones) -> void:
	var datos: Dictionary = _checkpoints()[4].a_diccionario()
	var claves: Array = datos.keys()
	claves.sort()
	a.verdadero(claves == ["candado_abierto", "cartas_recogidas", "digitos_revelados", "entregas", "version"], "RF-21 CA5: el guardado tiene claves de más o de menos: %s" % [claves])


## RF-21 CA6: corrupto, JSON inválido, claves faltantes, tipos inesperados,
## ids que no existen y combinaciones imposibles.
static func _probar_invalidos(a: Afirmaciones) -> void:
	var valido: Dictionary = _checkpoints()[1].a_diccionario()
	var casos: Dictionary = {
		"no es un objeto": [1, 2],
		"sin versión": _sin(valido, "version"),
		"otra versión": _con(valido, "version", 2),
		"sin cartas": _sin(valido, "cartas_recogidas"),
		"sin candado": _sin(valido, "candado_abierto"),
		"entregas como texto": _con(valido, "entregas", "2"),
		"entregas con decimales": _con(valido, "entregas", 1.5),
		"candado como número": _con(valido, "candado_abierto", 1),
		"cartas como texto": _con(valido, "cartas_recogidas", "carta_1"),
		"id que no existe": _con(valido, "cartas_recogidas", ["carta_1", "carta_9"]),
		"carta repetida": _con(valido, "cartas_recogidas", ["carta_1", "carta_1"]),
		"más entregas que cartas": _con(valido, "entregas", 4),
		"entregas negativas": _con(valido, "entregas", -1),
		"menos dígitos que entregas": _con(valido, "digitos_revelados", 1),
		"más dígitos que cartas": _con(valido, "digitos_revelados", 4),
		"candado sin la zona 2": _con(valido, "candado_abierto", true),
	}
	for nombre: String in casos:
		var estado: EstadoDePartida = EstadoDePartida.desde_diccionario(casos[nombre], IDS, CASAS)
		a.verdadero(estado == null, "RF-21 CA6: se aceptó un guardado con %s" % nombre)
	a.verdadero(EstadoDePartida.desde_diccionario(valido, IDS, CASAS) != null, "el guardado de referencia es válido")


## RF-21 CA4 y CA6 con archivos: ausente, basura y JSON inválido.
static func _probar_archivos(a: Afirmaciones) -> void:
	Guardado.borrar(RUTA_DE_PRUEBA)
	a.verdadero(Guardado.leer(RUTA_DE_PRUEBA, IDS, CASAS) == null, "sin archivo no hay guardado")
	var contenidos: Array[PackedByteArray] = [
		PackedByteArray(),
		"{\"version\": 1, ".to_ascii_buffer(),
		PackedByteArray([0, 255, 254, 65, 10]),
		"{\"version\": 1, \"cartas_recogidas\": [\"cañón\"]}".to_utf8_buffer(),
		"null".to_ascii_buffer(),
	]
	for contenido: PackedByteArray in contenidos:
		var archivo: FileAccess = FileAccess.open(RUTA_DE_PRUEBA, FileAccess.WRITE)
		archivo.store_buffer(contenido)
		archivo.close()
		a.verdadero(Guardado.leer(RUTA_DE_PRUEBA, IDS, CASAS) == null, "RF-21 CA6: se aceptó el archivo %s" % [contenido])
	Guardado.borrar(RUTA_DE_PRUEBA)
	a.verdadero(not FileAccess.file_exists(RUTA_DE_PRUEBA), "RF-21 CA4: borrar elimina el archivo")


static func _sin(datos: Dictionary, clave: String) -> Dictionary:
	var copia: Dictionary = datos.duplicate(true)
	copia.erase(clave)
	return copia


static func _con(datos: Dictionary, clave: String, valor: Variant) -> Dictionary:
	var copia: Dictionary = datos.duplicate(true)
	copia[clave] = valor
	return copia
