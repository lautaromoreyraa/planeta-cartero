class_name Guardado
extends RefCounted

## Lee y escribe el archivo de guardado en `user://` (RF-21).
##
## Es el único archivo que escribe el juego (RNF-02 CA2). Se lee como datos
## con `JSON.parse` y nunca como código (RNF-03). Un archivo ilegible o
## incoherente se trata como si no existiera, sin errores en la salida, y la
## partida empieza de cero (RF-21 CA6).

const RUTA: String = "user://partida.json"


static func escribir(ruta: String, estado: EstadoDePartida) -> bool:
	var archivo: FileAccess = FileAccess.open(ruta, FileAccess.WRITE)
	if archivo == null:
		push_warning("No se pudo guardar la partida en %s (error %d)." % [ruta, FileAccess.get_open_error()])
		return false
	archivo.store_string(JSON.stringify(estado.a_diccionario(), "\t"))
	archivo.close()
	return true


## El estado guardado en `ruta`, o nulo si no hay un guardado válido para el
## config con esas cartas y esa cantidad de casas.
static func leer(ruta: String, ids_de_cartas: PackedStringArray, cantidad_de_casas: int) -> EstadoDePartida:
	if not FileAccess.file_exists(ruta):
		return null
	# Se lee como bytes y se descarta lo que no es ASCII antes de decodificar:
	# el juego sólo escribe ids ASCII, y decodificar basura como UTF-8 deja
	# errores en la salida (RF-21 CA6).
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(ruta)
	for byte: int in bytes:
		if byte == 0 or byte > 127:
			return null
	var json: JSON = JSON.new()
	if json.parse(bytes.get_string_from_ascii()) != OK:
		return null
	return EstadoDePartida.desde_diccionario(json.data, ids_de_cartas, cantidad_de_casas)


static func borrar(ruta: String) -> void:
	if FileAccess.file_exists(ruta):
		DirAccess.remove_absolute(ruta)
