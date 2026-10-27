extends SceneTree

## Tests del inventario de cartas (RF-11 CA2 y CA3, RF-12).
## Se corre solo con `godot --headless --script res://tests/test_inventario_de_cartas.gd`.

const Afirmaciones := preload("res://tests/afirmaciones.gd")


func _initialize() -> void:
	var fallas: PackedStringArray = correr(self)
	for falla: String in fallas:
		printerr("FALLA: ", falla)
	print("test_inventario_de_cartas: %d fallas" % fallas.size())
	quit(1 if fallas.size() > 0 else 0)


static func correr(_arbol: SceneTree) -> PackedStringArray:
	var a: Afirmaciones = Afirmaciones.new()
	var inventario: InventarioDeCartas = InventarioDeCartas.new()
	var cantidades: Array[int] = []
	# Arrays y no PackedStringArray: las lambdas capturan una copia de los
	# arrays empaquetados y no verían lo que se agrega.
	var checkpoints: Array[String] = []
	inventario.cantidad_cambiada.connect(func(cantidad: int) -> void: cantidades.append(cantidad))
	inventario.carta_recogida.connect(func(id: String) -> void: checkpoints.append(id))

	a.verdadero(inventario.cantidad() == 0, "el inventario empieza vacío")
	a.verdadero(inventario.recoger("carta_1"), "recoger una carta nueva la acepta")
	a.verdadero(inventario.recoger("carta_3"), "recoger otra carta la acepta")
	a.verdadero(inventario.cantidad() == 2, "con dos cartas recogidas la cantidad es 2")
	a.verdadero(not inventario.recoger("carta_1"), "RF-11 CA2: una carta ya recogida no vuelve a recogerse")
	a.verdadero(not inventario.recoger(""), "una carta sin id no se recoge")
	a.verdadero(inventario.cantidad() == 2, "los rechazos no cambian la cantidad")
	a.verdadero(cantidades == [1, 2], "RF-12: avisa la cantidad sólo cuando cambia (avisó %s)" % [cantidades])
	a.verdadero(checkpoints == ["carta_1", "carta_3"], "RF-11 CA3: cada carta nueva emite un checkpoint (emitió %s)" % [checkpoints])
	return a.fallas
