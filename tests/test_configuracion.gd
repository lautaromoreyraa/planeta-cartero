extends SceneTree

## Tests del cargador del config: lectura de claves anidadas, textos por
## defecto ante claves faltantes o JSON inválido, y que el `config.json` del
## repo tenga los textos que usa el juego.
## Se corre solo con `godot --headless --script res://tests/test_configuracion.gd`.

const Afirmaciones := preload("res://tests/afirmaciones.gd")

## Claves que el juego ya lee del config; se suman las de cada hito.
const CLAVES_EN_USO: Array[String] = [
	"hud.formato_cartas",
	"hud.indicador_interaccion",
]


func _initialize() -> void:
	var fallas: PackedStringArray = correr(self)
	for falla: String in fallas:
		printerr("FALLA: ", falla)
	print("test_configuracion: %d fallas" % fallas.size())
	quit(1 if fallas.size() > 0 else 0)


static func correr(_arbol: SceneTree) -> PackedStringArray:
	var a: Afirmaciones = Afirmaciones.new()
	_probar_claves_anidadas(a)
	_probar_clave_faltante(a)
	_probar_json_invalido(a)
	_probar_archivo_inexistente(a)
	_probar_config_del_repo(a)
	return a.fallas


static func _probar_claves_anidadas(a: Afirmaciones) -> void:
	var config: Configuracion = Configuracion.desde_texto('{"hud": {"formato_cartas": "Cartas: {n}/4"}}')
	a.verdadero(config.avisos.is_empty(), "un JSON válido no deja avisos")
	a.verdadero(config.texto("hud.formato_cartas", "x") == "Cartas: {n}/4", "lee una clave anidada")
	a.verdadero(config.avisos.is_empty(), "leer una clave existente no deja avisos")


static func _probar_clave_faltante(a: Afirmaciones) -> void:
	var config: Configuracion = Configuracion.desde_texto('{"hud": {"formato_cartas": 4}}')
	a.verdadero(config.texto("hud.no_existe", "defecto") == "defecto", "una clave faltante devuelve el texto por defecto")
	a.verdadero(config.texto("hud.formato_cartas.n", "defecto") == "defecto", "una ruta que atraviesa un valor que no es objeto devuelve el defecto")
	a.verdadero(config.texto("hud.formato_cartas", "defecto") == "defecto", "un valor que no es texto devuelve el defecto")
	a.verdadero(config.avisos.size() == 3, "cada texto por defecto queda anotado como aviso (hay %d)" % config.avisos.size())


static func _probar_json_invalido(a: Afirmaciones) -> void:
	var rota: Configuracion = Configuracion.desde_texto('{"hud": ')
	a.verdadero(rota.avisos.size() == 1, "un JSON inválido deja un aviso")
	a.verdadero(rota.texto("hud.formato_cartas", "defecto") == "defecto", "con JSON inválido se usan los textos por defecto")
	var lista: Configuracion = Configuracion.desde_texto("[1, 2]")
	a.verdadero(lista.avisos.size() == 1, "un JSON que no es objeto deja un aviso")


static func _probar_archivo_inexistente(a: Afirmaciones) -> void:
	var config: Configuracion = Configuracion.desde_archivo("res://data/no_existe.json")
	a.verdadero(config.avisos.size() == 1, "un archivo inexistente deja un aviso")
	a.verdadero(config.texto("hud.formato_cartas", "defecto") == "defecto", "sin archivo se usan los textos por defecto")


static func _probar_config_del_repo(a: Afirmaciones) -> void:
	var config: Configuracion = Configuracion.desde_archivo(Configuracion.RUTA)
	for clave: String in CLAVES_EN_USO:
		a.verdadero(not config.texto(clave, "").is_empty(), "el config del repo tiene el texto «%s»" % clave)
	a.verdadero(config.texto("hud.formato_cartas", "").contains("{n}"), "hud.formato_cartas tiene el marcador {n}")
	a.verdadero(config.avisos.is_empty(), "el config del repo se lee sin avisos: %s" % ", ".join(config.avisos))
