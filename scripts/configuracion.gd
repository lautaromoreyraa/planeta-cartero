class_name Configuracion
extends RefCounted

## Contenido editable del juego leído de `data/config.json` (RF-22, RNF-23).
##
## No depende de escenas para poder probarla headless. El archivo se lee
## como datos con `JSON.parse`, nunca como código (RNF-03). Si el archivo
## falta, no es JSON válido o le falta una clave, el juego sigue con el
## texto por defecto que pasa quien pregunta; los problemas se juntan en
## `avisos` para que la escena los informe en la salida, y así los tests de
## los casos inválidos no ensucian la consola.
##
## Por ahora lee sólo `config.json`; la prioridad de `config.local.json`
## (RF-27) se suma en el hito 3.

const RUTA: String = "res://data/config.json"

## Problemas encontrados al leer o al consultar el config.
var avisos: PackedStringArray = PackedStringArray()

var _datos: Dictionary = {}


static func desde_archivo(ruta: String) -> Configuracion:
	if not FileAccess.file_exists(ruta):
		var vacia: Configuracion = Configuracion.new()
		vacia.avisos.append("No se encontró el config en %s; se usan los textos por defecto." % ruta)
		return vacia
	return desde_texto(FileAccess.get_file_as_string(ruta), ruta)


## `origen` sólo sirve para que los avisos digan de dónde salió el texto.
static func desde_texto(contenido: String, origen: String = "texto") -> Configuracion:
	var config: Configuracion = Configuracion.new()
	var json: JSON = JSON.new()
	if json.parse(contenido) != OK:
		config.avisos.append("El config de %s no es JSON válido (línea %d: %s); se usan los textos por defecto." % [
			origen, json.get_error_line(), json.get_error_message()
		])
		return config
	if json.data is Dictionary:
		config._datos = json.data
	else:
		config.avisos.append("El config de %s no es un objeto JSON; se usan los textos por defecto." % origen)
	return config


## Texto en `clave`, con los niveles separados por puntos («hud.formato_cartas»).
## Si la clave falta o no es un texto, devuelve `por_defecto` y lo anota.
func texto(clave: String, por_defecto: String) -> String:
	var valor: Variant = _buscar(clave)
	if valor is String:
		return valor
	avisos.append("Falta el texto «%s» en el config; se usa «%s»." % [clave, por_defecto])
	return por_defecto


func _buscar(clave: String) -> Variant:
	var actual: Variant = _datos
	for parte: String in clave.split("."):
		if not actual is Dictionary or not (actual as Dictionary).has(parte):
			return null
		actual = (actual as Dictionary)[parte]
	return actual
