extends SceneTree

## Tests de la elección del interactuable sobre el que actúa E (RF-06).
## Se corre solo con `godot --headless --script res://tests/test_seleccion_de_interactuable.gd`.

const Afirmaciones := preload("res://tests/afirmaciones.gd")


func _initialize() -> void:
	var fallas: PackedStringArray = correr(self)
	for falla: String in fallas:
		printerr("FALLA: ", falla)
	print("test_seleccion_de_interactuable: %d fallas" % fallas.size())
	quit(1 if fallas.size() > 0 else 0)


static func correr(_arbol: SceneTree) -> PackedStringArray:
	var a: Afirmaciones = Afirmaciones.new()
	var origen: Vector3 = Vector3(0, 10, 0)

	a.verdadero(SeleccionDeInteractuable.indice_del_mas_cercano(origen, PackedVector3Array(), 1.5) == -1, "sin objetos no hay elegido")

	var lejos: PackedVector3Array = PackedVector3Array([Vector3(0, 10, 3), Vector3(2, 10, 0)])
	a.verdadero(SeleccionDeInteractuable.indice_del_mas_cercano(origen, lejos, 1.5) == -1, "RF-06 CA2: lejos de todo no hay elegido")

	var dos: PackedVector3Array = PackedVector3Array([Vector3(0, 10, 1.2), Vector3(0.5, 10, 0), Vector3(3, 10, 0)])
	a.verdadero(SeleccionDeInteractuable.indice_del_mas_cercano(origen, dos, 1.5) == 1, "RF-06 CA3: con dos en rango gana el más cercano")

	var borde: PackedVector3Array = PackedVector3Array([Vector3(0, 10, 1.5)])
	a.verdadero(SeleccionDeInteractuable.indice_del_mas_cercano(origen, borde, 1.5) == 0, "el borde del radio cuenta como en rango")

	var empate: PackedVector3Array = PackedVector3Array([Vector3(1, 10, 0), Vector3(-1, 10, 0)])
	a.verdadero(SeleccionDeInteractuable.indice_del_mas_cercano(origen, empate, 1.5) == 0, "en un empate gana el primero")
	return a.fallas
