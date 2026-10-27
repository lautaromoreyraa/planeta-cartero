extends SceneTree

## Corre todos los tests headless y sale con código distinto de 0 si alguno
## falla. Uso: `godot --headless --script res://tests/correr_tests.gd`.
##
## Cada test expone `static func correr(arbol: SceneTree) -> PackedStringArray`
## con las fallas encontradas; así se puede correr también por separado.

const PRUEBAS: Array[String] = [
	"res://tests/test_geometria_esferica.gd",
	"res://tests/test_planeta.gd",
	"res://tests/test_jugador_en_planeta.gd",
	"res://tests/test_configuracion.gd",
	"res://tests/test_seleccion_de_interactuable.gd",
	"res://tests/test_inventario_de_cartas.gd",
	"res://tests/test_cartas_en_escena.gd",
	"res://tests/test_candado.gd",
	"res://tests/test_secuencia_de_entrega.gd",
	"res://tests/test_guardado.gd",
]


func _initialize() -> void:
	var total: int = 0
	for ruta: String in PRUEBAS:
		var prueba: GDScript = load(ruta)
		var fallas: PackedStringArray = await prueba.call("correr", self)
		for falla: String in fallas:
			printerr("FALLA [%s]: %s" % [ruta.get_file(), falla])
		print("%s: %s" % [ruta.get_file(), "OK" if fallas.is_empty() else "%d fallas" % fallas.size()])
		total += fallas.size()
	print("Total: %d fallas" % total)
	quit(1 if total > 0 else 0)
