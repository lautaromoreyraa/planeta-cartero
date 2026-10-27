class_name Configuracion
extends RefCounted

## Contenido editable del juego leído del config activo (RF-22, RF-27, RNF-23).
##
## No depende de escenas para poder probarla headless. El archivo se lee
## como datos con `JSON.parse`, nunca como código (RNF-03). Si existe
## `config.local.json` (el contenido real, fuera de git) se usa ese archivo
## entero; si no, el `config.json` versionado con placeholders.
##
## Si falta una clave o tiene un valor inválido, el juego sigue con el valor
## por defecto que pasa quien pregunta. Los problemas se juntan en `avisos`
## para que los tests de los casos inválidos no ensucien la consola; el juego
## llama a `activar_salida()` para que además se informen en la salida.

const RUTA: String = "res://data/config.json"
const RUTA_LOCAL: String = "res://data/config.local.json"
## Las imágenes sólo pueden salir de esta carpeta y con estas extensiones:
## así una ruta del config nunca carga un recurso con código adentro (RNF-03).
const CARPETA_DE_IMAGENES: String = "res://assets/personal/"
const EXTENSIONES_DE_IMAGEN: PackedStringArray = ["png", "jpg", "jpeg", "webp"]
const CANTIDAD_DE_CASAS: int = 4

## Claves de texto que el juego lee; todas obligatorias (sección 5 del SRS).
const CLAVES_DE_TEXTO: PackedStringArray = [
	"inicio.titulo",
	"inicio.subtitulo",
	"inicio.opcion_continuar",
	"inicio.opcion_nueva_partida",
	"inicio.indicacion",
	"pausa.titulo",
	"pausa.continuar",
	"pausa.salir",
	"pausa.indicacion",
	"dialogo.indicacion",
	"hud.formato_cartas",
	"hud.indicador_interaccion",
	"hud.formato_codigo",
	"hud.digito_oculto",
	"entrega.pista",
	"entrega.formato_digito",
	"entrega.aviso_error",
	"entrega.sin_cartas",
	"oficina.aviso_cerrada",
	"oficina.aviso_error",
	"oficina.titulo_candado",
	"oficina.indicacion_candado",
	"final.mensaje",
	"final.indicacion",
]

## Problemas encontrados al leer o al consultar el config, sin repetidos.
var avisos: PackedStringArray = PackedStringArray()
## Archivo del que salió el contenido; sirve para los avisos.
var origen: String = "texto"

var _datos: Dictionary = {}
var _salida_activa: bool = false


## Config activo: `ruta_local` si existe y es un objeto JSON válido; si no,
## `ruta_base` (RF-27). Las rutas son parámetros para poder probarlo.
static func cargar(ruta_local: String = RUTA_LOCAL, ruta_base: String = RUTA) -> Configuracion:
	if FileAccess.file_exists(ruta_local):
		var local: Configuracion = desde_archivo(ruta_local)
		if local.avisos.is_empty():
			return local
		var base: Configuracion = desde_archivo(ruta_base)
		var avisos_previos: PackedStringArray = local.avisos.duplicate()
		avisos_previos.append_array(base.avisos)
		base.avisos = avisos_previos
		base._avisar("Se ignora %s y se usa %s." % [ruta_local, ruta_base])
		return base
	return desde_archivo(ruta_base)


## Config activo para el juego: informa en la salida los problemas de
## lectura y de validación, y los que aparezcan después (RF-22 CA2).
static func cargar_para_el_juego() -> Configuracion:
	var config: Configuracion = cargar()
	config.activar_salida()
	config.validar()
	return config


static func desde_archivo(ruta: String) -> Configuracion:
	if not FileAccess.file_exists(ruta):
		var vacia: Configuracion = Configuracion.new()
		vacia.origen = ruta
		vacia._avisar("No se encontró el config en %s; se usan los textos por defecto." % ruta)
		return vacia
	return desde_texto(FileAccess.get_file_as_string(ruta), ruta)


## `origen_del_texto` sólo sirve para que los avisos digan de dónde salió.
static func desde_texto(contenido: String, origen_del_texto: String = "texto") -> Configuracion:
	var config: Configuracion = Configuracion.new()
	config.origen = origen_del_texto
	var json: JSON = JSON.new()
	if json.parse(contenido) != OK:
		config._avisar("El config de %s no es JSON válido (línea %d: %s); se usan los textos por defecto." % [
			origen_del_texto, json.get_error_line(), json.get_error_message()
		])
		return config
	if json.data is Dictionary:
		config._datos = json.data
	else:
		config._avisar("El config de %s no es un objeto JSON; se usan los textos por defecto." % origen_del_texto)
	return config


## Verdadero si `ruta` es una imagen permitida (ver `CARPETA_DE_IMAGENES`).
static func es_ruta_de_imagen_valida(ruta: String) -> bool:
	return ruta.begins_with(CARPETA_DE_IMAGENES) \
		and not ruta.contains("..") \
		and EXTENSIONES_DE_IMAGEN.has(ruta.get_extension().to_lower())


## Informa en la salida los avisos pendientes y los que aparezcan después.
## Lo usa el juego; los tests no, para que la consola quede limpia.
func activar_salida() -> void:
	_salida_activa = true
	for aviso: String in avisos:
		push_warning(aviso)


## Lee todo lo que usa el juego y devuelve los problemas encontrados
## (RF-22 CA2 y CA3). Sin problemas, el config está completo.
func validar() -> PackedStringArray:
	avisos.clear()
	for clave: String in CLAVES_DE_TEXTO:
		texto(clave, "")
	tutorial(PackedStringArray())
	ids_de_cartas()
	casas()
	orden_de_entrega()
	codigo()
	for i: int in range(CANTIDAD_DE_CASAS):
		recuerdo(i)
	imagen_final()
	return avisos.duplicate()


## Texto en `clave`, con los niveles separados por puntos («hud.formato_cartas»).
## Si la clave falta o no es un texto, devuelve `por_defecto` y lo anota.
func texto(clave: String, por_defecto: String) -> String:
	var valor: Variant = _buscar(clave)
	if valor is String:
		return valor
	# El aviso no nombra el valor por defecto para que la validación y las
	# lecturas del juego dejen el mismo mensaje y se informe una sola vez.
	_avisar("Falta el texto «%s» en el config; se usa el texto por defecto." % clave)
	return por_defecto


## Líneas del tutorial (`inicio.tutorial`): una lista no vacía de textos.
func tutorial(por_defecto: PackedStringArray) -> PackedStringArray:
	var valor: Variant = _buscar("inicio.tutorial")
	var lineas: PackedStringArray = PackedStringArray()
	if valor is Array:
		for linea: Variant in valor:
			if linea is String:
				lineas.append(linea)
	if lineas.is_empty() or lineas.size() != (valor as Array).size():
		_avisar("«inicio.tutorial» tiene que ser una lista de textos; se usa el tutorial por defecto.")
		return por_defecto
	return lineas


## Ids de `recoleccion.cartas`, en orden.
func ids_de_cartas() -> PackedStringArray:
	var ids: PackedStringArray = PackedStringArray()
	for carta: Dictionary in _lista_de_objetos("recoleccion.cartas", ["id"]):
		ids.append(carta["id"])
	return ids


## Texto opcional que se muestra al recoger la carta `id`; vacío si no hay.
func texto_al_recoger(id: String) -> String:
	for carta: Dictionary in _lista_de_objetos("recoleccion.cartas", ["id"]):
		if carta["id"] == id and carta.get("texto_al_recoger") is String:
			return carta["texto_al_recoger"]
	return ""


## Las casas de `entrega.casas` como diccionarios con `id` y `rotulo`. Si no
## son exactamente 4 con ids distintos, se usan casas por defecto para que la
## zona 2 siga siendo jugable.
func casas() -> Array[Dictionary]:
	var lista: Array[Dictionary] = _lista_de_objetos("entrega.casas", ["id", "rotulo"])
	var ids: PackedStringArray = PackedStringArray()
	for casa: Dictionary in lista:
		if not ids.has(casa["id"]):
			ids.append(casa["id"])
	if lista.size() == CANTIDAD_DE_CASAS and ids.size() == CANTIDAD_DE_CASAS:
		return lista
	_avisar("«entrega.casas» tiene que tener %d casas con «id» y «rotulo» distintos; se usan casas por defecto." % CANTIDAD_DE_CASAS)
	var por_defecto: Array[Dictionary] = []
	for letra: String in ["a", "b", "c", "d"]:
		por_defecto.append({"id": "casa_" + letra, "rotulo": "Casa " + letra.to_upper()})
	return por_defecto


## Ids de las casas en el orden de entrega correcto: los 4 de `casas()`, sin
## repetir. Si no, se usa el orden en que están listadas las casas.
func orden_de_entrega() -> PackedStringArray:
	var ids_de_casas: PackedStringArray = PackedStringArray()
	for casa: Dictionary in casas():
		ids_de_casas.append(casa["id"])
	var valor: Variant = _buscar("entrega.orden")
	var orden: PackedStringArray = PackedStringArray()
	if valor is Array:
		for id: Variant in valor:
			if id is String and ids_de_casas.has(id) and not orden.has(id):
				orden.append(id)
	if valor is Array and orden.size() == CANTIDAD_DE_CASAS and (valor as Array).size() == CANTIDAD_DE_CASAS:
		return orden
	_avisar("«entrega.orden» tiene que listar una vez cada id de «entrega.casas»; se usa el orden de las casas.")
	return ids_de_casas


## Código del candado: 4 dígitos como texto, para conservar los ceros.
func codigo() -> String:
	var valor: Variant = _buscar("oficina.codigo")
	if valor is String and Candado.es_codigo_valido(valor):
		return valor
	_avisar("«oficina.codigo» tiene que ser un texto de 4 dígitos; se usa «0000».")
	return "0000"


## Recuerdo de la entrega correcta número `indice` + 1, con `texto` e
## `imagen` (vacía si no hay o si la ruta no es válida).
func recuerdo(indice: int) -> Dictionary:
	var lista: Array[Dictionary] = _lista_de_objetos("entrega.recuerdos", ["texto", "imagen"])
	if lista.size() != CANTIDAD_DE_CASAS:
		_avisar("«entrega.recuerdos» tiene que tener %d recuerdos con «texto» e «imagen»." % CANTIDAD_DE_CASAS)
	if indice < 0 or indice >= lista.size():
		return {"texto": "", "imagen": ""}
	var elegido: Dictionary = lista[indice]
	return {"texto": elegido["texto"], "imagen": _imagen(elegido["imagen"], "entrega.recuerdos[%d].imagen" % indice)}


## Ruta de la foto de la pantalla final, o vacía.
func imagen_final() -> String:
	var valor: Variant = _buscar("final.imagen")
	if not valor is String:
		_avisar("Falta «final.imagen» en el config (puede ser \"\").")
		return ""
	return _imagen(valor, "final.imagen")


func _imagen(ruta: String, clave: String) -> String:
	if ruta.is_empty() or es_ruta_de_imagen_valida(ruta):
		return ruta
	_avisar("«%s» tiene que estar en %s y ser %s; se muestra sin imagen." % [
		clave, CARPETA_DE_IMAGENES, ", ".join(EXTENSIONES_DE_IMAGEN)
	])
	return ""


## Elementos de la lista en `clave` que son objetos con todas las claves de
## `requeridas` como textos. Avisa si alguno no lo es.
func _lista_de_objetos(clave: String, requeridas: Array[String]) -> Array[Dictionary]:
	var valor: Variant = _buscar(clave)
	var lista: Array[Dictionary] = []
	if not valor is Array:
		_avisar("Falta la lista «%s» en el config." % clave)
		return lista
	for elemento: Variant in valor:
		var completo: bool = elemento is Dictionary
		if completo:
			for requerida: String in requeridas:
				completo = completo and (elemento as Dictionary).get(requerida) is String
		if completo:
			lista.append(elemento)
		else:
			_avisar("Un elemento de «%s» no tiene %s como textos." % [clave, ", ".join(requeridas)])
	return lista


func _buscar(clave: String) -> Variant:
	var actual: Variant = _datos
	for parte: String in clave.split("."):
		if not actual is Dictionary or not (actual as Dictionary).has(parte):
			return null
		actual = (actual as Dictionary)[parte]
	return actual


func _avisar(mensaje: String) -> void:
	if avisos.has(mensaje):
		return
	avisos.append(mensaje)
	if _salida_activa:
		push_warning(mensaje)
