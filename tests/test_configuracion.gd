extends SceneTree

## Tests del cargador del config: claves anidadas, valores por defecto ante
## claves faltantes o JSON inválido, prioridad del config local (RF-27),
## validación completa (RF-22 CA3) y placeholders del config versionado
## (RNF-06 CA4).
## Se corre solo con `godot --headless --script res://tests/test_configuracion.gd`.

const Afirmaciones := preload("res://tests/afirmaciones.gd")
const RUTA_LOCAL_DE_PRUEBA: String = "user://test_config_local.json"
const RUTA_BASE_DE_PRUEBA: String = "user://test_config_base.json"

## Textos personales que en el `config.json` versionado tienen que ser
## placeholders entre corchetes (RNF-06 CA4).
const TEXTOS_PERSONALES: Array[String] = [
	"inicio.titulo",
	"inicio.subtitulo",
	"entrega.pista",
	"entrega.aviso_error",
	"entrega.sin_cartas",
	"oficina.aviso_cerrada",
	"oficina.aviso_error",
	"final.mensaje",
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
	_probar_valores_invalidos(a)
	_probar_prioridad_del_local(a)
	_probar_config_del_repo(a)
	_probar_placeholders_del_repo(a)
	_probar_config_local_real(a)
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
	config.texto("hud.no_existe", "defecto")
	a.verdadero(config.avisos.size() == 3, "la misma clave faltante se anota una sola vez")


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
	a.verdadero(not config.validar().is_empty(), "un config vacío no pasa la validación")


## RF-22 CA2: orden, código, casas e imágenes inválidos caen en valores
## jugables y quedan anotados.
static func _probar_valores_invalidos(a: Afirmaciones) -> void:
	var config: Configuracion = Configuracion.desde_texto(JSON.stringify({
		"entrega": {
			"casas": [{"id": "x", "rotulo": "X"}, {"id": "y", "rotulo": "Y"}, {"id": "z", "rotulo": "Z"}, {"id": "w", "rotulo": "W"}],
			"orden": ["x", "y", "x", "w"],
			"recuerdos": [{"texto": "uno", "imagen": "res://scripts/jugador.gd"}],
		},
		"oficina": {"codigo": 427},
		"final": {"imagen": "user://foto.png"},
	}))
	a.verdadero(config.orden_de_entrega() == PackedStringArray(["x", "y", "z", "w"]), "un orden con repetidos cae en el orden de las casas")
	a.verdadero(config.codigo() == "0000", "un código numérico (sin ceros adelante) cae en «0000»")
	a.verdadero(config.recuerdo(0)["imagen"] == "", "una imagen fuera de assets/personal no se usa")
	a.verdadero(config.recuerdo(3)["texto"] == "", "un recuerdo que falta queda vacío")
	a.verdadero(config.imagen_final() == "", "una foto final en user:// no se usa")
	a.verdadero(config.avisos.size() >= 5, "cada valor inválido deja un aviso (hay %d)" % config.avisos.size())
	var pocas: Configuracion = Configuracion.desde_texto('{"entrega": {"casas": [{"id": "x", "rotulo": "X"}]}}')
	a.verdadero(pocas.casas().size() == 4, "con menos de 4 casas se usan 4 casas por defecto")
	a.verdadero(Configuracion.es_ruta_de_imagen_valida("res://assets/personal/foto.JPG"), "una foto de assets/personal es válida")
	a.verdadero(not Configuracion.es_ruta_de_imagen_valida("res://assets/personal/../../scripts/x.png"), "una ruta con «..» no es válida")


## RF-27 CA1 a CA3: local presente, ausente e inválido.
static func _probar_prioridad_del_local(a: Afirmaciones) -> void:
	_escribir(RUTA_BASE_DE_PRUEBA, '{"pausa": {"titulo": "base"}}')
	_escribir(RUTA_LOCAL_DE_PRUEBA, '{"pausa": {"titulo": "local"}}')
	var con_local: Configuracion = Configuracion.cargar(RUTA_LOCAL_DE_PRUEBA, RUTA_BASE_DE_PRUEBA)
	a.verdadero(con_local.texto("pausa.titulo", "") == "local", "RF-27 CA1: con el local presente se usa el local")
	a.verdadero(con_local.texto("pausa.salir", "defecto") == "defecto", "RF-27 CA1: el local reemplaza el archivo entero, no clave por clave")

	DirAccess.remove_absolute(RUTA_LOCAL_DE_PRUEBA)
	var sin_local: Configuracion = Configuracion.cargar(RUTA_LOCAL_DE_PRUEBA, RUTA_BASE_DE_PRUEBA)
	a.verdadero(sin_local.texto("pausa.titulo", "") == "base", "RF-27 CA1: sin el local se usa el base")
	a.verdadero(sin_local.avisos.is_empty(), "sin el local no hay avisos")

	_escribir(RUTA_LOCAL_DE_PRUEBA, '{"pausa": ')
	var local_roto: Configuracion = Configuracion.cargar(RUTA_LOCAL_DE_PRUEBA, RUTA_BASE_DE_PRUEBA)
	a.verdadero(local_roto.texto("pausa.titulo", "") == "base", "RF-27 CA2: con el local inválido se usa el base")
	a.verdadero(local_roto.avisos.size() == 2, "RF-27 CA2: el local inválido deja su aviso y el de reemplazo (hay %d)" % local_roto.avisos.size())
	DirAccess.remove_absolute(RUTA_LOCAL_DE_PRUEBA)
	DirAccess.remove_absolute(RUTA_BASE_DE_PRUEBA)


## RF-22 CA3: el config del repo tiene todas las claves y valores válidos.
static func _probar_config_del_repo(a: Afirmaciones) -> void:
	_validar_completo(a, Configuracion.desde_archivo(Configuracion.RUTA), "config.json")


## RF-27 CA4: si Lautaro tiene su config local, también se valida, y además
## que las imágenes que nombra existan.
static func _probar_config_local_real(a: Afirmaciones) -> void:
	if not FileAccess.file_exists(Configuracion.RUTA_LOCAL):
		return
	var local: Configuracion = Configuracion.desde_archivo(Configuracion.RUTA_LOCAL)
	_validar_completo(a, local, "config.local.json")
	var imagenes: Array[String] = [local.imagen_final()]
	for i: int in range(Configuracion.CANTIDAD_DE_CASAS):
		imagenes.append(local.recuerdo(i)["imagen"])
	for imagen: String in imagenes:
		a.verdadero(imagen.is_empty() or ResourceLoader.exists(imagen), "config.local.json: no existe la imagen %s" % imagen)


static func _validar_completo(a: Afirmaciones, config: Configuracion, nombre: String) -> void:
	var problemas: PackedStringArray = config.validar()
	a.verdadero(problemas.is_empty(), "%s tiene problemas: %s" % [nombre, " | ".join(problemas)])
	a.verdadero(config.texto("hud.formato_cartas", "").contains("{n}"), "%s: hud.formato_cartas tiene el marcador {n}" % nombre)
	a.verdadero(config.texto("hud.formato_codigo", "").contains("{codigo}"), "%s: hud.formato_codigo tiene el marcador {codigo}" % nombre)
	var formato_digito: String = config.texto("entrega.formato_digito", "")
	a.verdadero(formato_digito.contains("{posicion}") and formato_digito.contains("{digito}"), "%s: entrega.formato_digito tiene {posicion} y {digito}" % nombre)
	a.verdadero(config.ids_de_cartas().size() == 4, "%s: recoleccion.cartas tiene 4 cartas" % nombre)


## RNF-06 CA4: el config versionado sólo tiene placeholders y el código «0000».
static func _probar_placeholders_del_repo(a: Afirmaciones) -> void:
	var config: Configuracion = Configuracion.desde_archivo(Configuracion.RUTA)
	var personales: PackedStringArray = PackedStringArray()
	for clave: String in TEXTOS_PERSONALES:
		personales.append(config.texto(clave, ""))
	for casa: Dictionary in config.casas():
		personales.append(casa["rotulo"])
	for i: int in range(Configuracion.CANTIDAD_DE_CASAS):
		personales.append(config.recuerdo(i)["texto"])
	for id: String in config.ids_de_cartas():
		var al_recoger: String = config.texto_al_recoger(id)
		if not al_recoger.is_empty():
			personales.append(al_recoger)
	var placeholder: RegEx = RegEx.create_from_string("\\[[^\\]]+\\]")
	for texto: String in personales:
		a.verdadero(placeholder.search(texto) != null, "RNF-06 CA4: «%s» no es un placeholder entre corchetes" % texto)
	a.verdadero(config.codigo() == "0000", "RNF-06 CA4: el código del config versionado no es «0000»")


static func _escribir(ruta: String, contenido: String) -> void:
	var archivo: FileAccess = FileAccess.open(ruta, FileAccess.WRITE)
	archivo.store_string(contenido)
	archivo.close()
