extends SceneTree

## Test de integración del hito 2: carga la escena principal y comprueba las
## cartas repartidas, la interacción con E y el HUD (RF-06, RF-10 a RF-12).
## Corre en tiempo real (unos 6 s).
## Se corre solo con `godot --headless --script res://tests/test_cartas_en_escena.gd`.

const Afirmaciones := preload("res://tests/afirmaciones.gd")
const ESCENA_PRINCIPAL: PackedScene = preload("res://scenes/principal.tscn")
const FRAMES_POR_SEGUNDO: int = 60
## Altura del techo de casa.tscn sobre la superficie, en metros.
const ALTURA_DEL_TECHO: float = 1.65
## Altura de la cara de arriba de plataforma.tscn sobre la superficie.
const ALTURA_DE_LA_PLATAFORMA: float = 1.4


func _initialize() -> void:
	var fallas: PackedStringArray = await correr(self)
	for falla: String in fallas:
		printerr("FALLA: ", falla)
	print("test_cartas_en_escena: %d fallas" % fallas.size())
	quit(1 if fallas.size() > 0 else 0)


static func correr(arbol: SceneTree) -> PackedStringArray:
	var a: Afirmaciones = Afirmaciones.new()
	_probar_reparto(a)
	await _probar_recoger_del_piso(arbol, a)
	await _probar_carta_del_techo(arbol, a)
	await _probar_carta_de_la_plataforma(arbol, a)
	return a.fallas


## Registra el último objetivo que anunció el detector.
class Espia:
	extends RefCounted
	var objetivo: Interactuable = null
	## Si en algún momento hubo algo en rango.
	var hubo_objetivo: bool = false

	func anotar(nuevo: Interactuable) -> void:
		objetivo = nuevo
		hubo_objetivo = hubo_objetivo or nuevo != null


static func _cartas_de(escena: Node3D) -> Array[Carta]:
	var cartas: Array[Carta] = []
	for nodo: Node in escena.get_node("Cartas").get_children():
		var carta: Carta = nodo as Carta
		if carta != null and not carta.is_queued_for_deletion():
			cartas.append(carta)
	return cartas


static func _carta(escena: Node3D, id: String) -> Carta:
	for carta: Carta in _cartas_de(escena):
		if carta.id == id:
			return carta
	return null


## Instancia la escena con el jugador parado en `latitud`/`longitud` a
## `altura` metros de la superficie, mirando hacia el norte.
static func _cargar(arbol: SceneTree, latitud: float, longitud: float, altura: float, espia: Espia) -> Node3D:
	var escena: Node3D = ESCENA_PRINCIPAL.instantiate()
	var jugador: Jugador = escena.get_node("Jugador")
	jugador.transform = GeometriaEsferica.transform_en_superficie(
		Planeta.CENTRO, Planeta.RADIO + altura, deg_to_rad(latitud), deg_to_rad(longitud), 0.0
	)
	var detector: DetectorDeInteraccion = escena.get_node("Jugador/DetectorDeInteraccion")
	detector.objetivo_cambiado.connect(espia.anotar)
	arbol.root.add_child(escena)
	await _avanzar(arbol, FRAMES_POR_SEGUNDO)
	return escena


static func _avanzar(arbol: SceneTree, frames: int) -> void:
	for _i: int in range(frames):
		await arbol.physics_frame


## La E se manda como evento porque el detector la lee como evento.
static func _apretar_e(arbol: SceneTree) -> void:
	for apretada: bool in [true, false]:
		var evento: InputEventAction = InputEventAction.new()
		evento.action = &"interact"
		evento.pressed = apretada
		Input.parse_input_event(evento)
		await _avanzar(arbol, 2)


static func _descargar(arbol: SceneTree, escena: Node3D) -> void:
	for accion: String in ["move_forward", "move_back", "move_left", "move_right", "jump", "interact"]:
		Input.action_release(accion)
	escena.queue_free()
	await arbol.process_frame


static func _texto_del_hud(escena: Node3D) -> String:
	var etiqueta: Label = escena.get_node("Hud/Lineas/Cartas")
	return etiqueta.text


static func _indicador_visible(escena: Node3D) -> bool:
	var indicador: Label = escena.get_node("Hud/Indicador")
	return indicador.visible


## RF-10 CA1 y CA2: cuatro cartas con ids distintos del config y al menos una
## en altura. Que se alcancen (CA3) lo prueban los recorridos de abajo.
static func _probar_reparto(a: Afirmaciones) -> void:
	var escena: Node3D = ESCENA_PRINCIPAL.instantiate()
	var cartas: Array[Carta] = _cartas_de(escena)
	a.verdadero(cartas.size() == 4, "RF-10 CA1: hay %d cartas en la escena" % cartas.size())

	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Configuracion.RUTA))
	var ids_del_config: PackedStringArray = PackedStringArray()
	for entrada: Dictionary in config["recoleccion"]["cartas"]:
		ids_del_config.append(entrada["id"])
	var ids: PackedStringArray = PackedStringArray()
	var en_altura: int = 0
	for carta: Carta in cartas:
		a.verdadero(not ids.has(carta.id), "RF-10: el id %s está repetido" % carta.id)
		a.verdadero(ids_del_config.has(carta.id), "RF-10: el id %s no está en recoleccion.cartas del config" % carta.id)
		ids.append(carta.id)
		if carta.altura > ALTURA_DE_LA_PLATAFORMA:
			en_altura += 1
	a.verdadero(en_altura >= 1, "RF-10 CA2: ninguna carta está sobre un techo o plataforma")
	escena.free()


## RF-06, RF-11 y RF-12 con la carta del piso más cercana al inicio.
static func _probar_recoger_del_piso(arbol: SceneTree, a: Afirmaciones) -> void:
	var espia: Espia = Espia.new()
	# Lejos de todo: sin indicador, y E no hace nada (RF-06 CA2).
	var escena: Node3D = await _cargar(arbol, 90.0, 0.0, 0.1, espia)
	a.verdadero(_texto_del_hud(escena) == "Cartas: 0/4", "RF-12 CA1: el HUD arranca en «%s»" % _texto_del_hud(escena))
	a.verdadero(espia.objetivo == null and not _indicador_visible(escena), "RF-06 CA2: hay indicador lejos de todo interactuable")
	await _apretar_e(arbol)
	a.verdadero(_cartas_de(escena).size() == 4, "RF-06 CA2: E lejos de todo recogió una carta")
	await _descargar(arbol, escena)

	# Parada sobre la carta 1.
	escena = await _cargar(arbol, 70.0, 20.0, 0.1, espia)
	var carta: Carta = _carta(escena, "carta_1")
	a.verdadero(espia.objetivo != null and carta != null and espia.objetivo.get_parent() == carta, "RF-06 CA1: junto a la carta 1 no es el objetivo")
	a.verdadero(_indicador_visible(escena), "RF-06 CA1: junto a la carta 1 no aparece el indicador")
	await _apretar_e(arbol)
	a.verdadero(not is_instance_valid(carta), "RF-11 CA1: la carta recogida sigue en el planeta")
	a.verdadero(_cartas_de(escena).size() == 3, "RF-11 CA1: quedan %d cartas en el planeta" % _cartas_de(escena).size())
	a.verdadero(_texto_del_hud(escena) == "Cartas: 1/4", "RF-11 CA1: el HUD muestra «%s»" % _texto_del_hud(escena))
	a.verdadero(espia.objetivo == null and not _indicador_visible(escena), "RF-11: el indicador sigue tras recoger la carta")
	await _apretar_e(arbol)
	a.verdadero(_texto_del_hud(escena) == "Cartas: 1/4", "RF-11 CA2: E otra vez en el mismo lugar cambió el HUD")
	await _descargar(arbol, escena)


## RF-10 CA2 y CA3: la carta del techo no se alcanza desde el piso pegado a
## la pared, sí saltando, y se recoge parada en el techo.
static func _probar_carta_del_techo(arbol: SceneTree, a: Afirmaciones) -> void:
	var espia: Espia = Espia.new()
	var escena: Node3D = await _cargar(arbol, 18.0, 0.0, 0.1, espia)
	# Camina hacia el norte contra la pared de la casa.
	Input.action_press("move_forward")
	await _avanzar(arbol, FRAMES_POR_SEGUNDO)
	Input.action_release("move_forward")
	await _avanzar(arbol, 10)
	var jugador: Jugador = escena.get_node("Jugador")
	var carta: Carta = _carta(escena, "carta_2")
	# Distancia sobre la superficie hasta el centro de la casa: pegada a la
	# pared es medio ancho de la casa (1,1 m) más el radio del cuerpo.
	var sobre_la_superficie: float = jugador.global_position.angle_to(carta.global_position) * Planeta.RADIO
	a.verdadero(sobre_la_superficie < 1.7, "el jugador no llegó a la pared de la casa (quedó a %.2f m)" % sobre_la_superficie)
	a.verdadero(not espia.hubo_objetivo, "RF-10 CA2: la carta del techo se alcanza desde el piso")

	# Saltando contra la pared sube al techo y la carta queda en rango.
	Input.action_press("move_forward")
	Input.action_press("jump")
	await _avanzar(arbol, 2)
	Input.action_release("jump")
	await _avanzar(arbol, 25)
	Input.action_release("move_forward")
	await _avanzar(arbol, 30)
	a.verdadero(espia.hubo_objetivo, "RF-10 CA3: saltando contra la casa la carta del techo nunca quedó en rango")
	await _descargar(arbol, escena)

	escena = await _cargar(arbol, 30.0, 0.0, ALTURA_DEL_TECHO + 0.1, espia)
	await _apretar_e(arbol)
	a.verdadero(_carta(escena, "carta_2") == null, "RF-10 CA3: parada en el techo no recogió la carta 2")
	await _descargar(arbol, escena)


## RF-10 CA3: la carta de la plataforma se recoge parada sobre ella.
static func _probar_carta_de_la_plataforma(arbol: SceneTree, a: Afirmaciones) -> void:
	var espia: Espia = Espia.new()
	var escena: Node3D = await _cargar(arbol, 50.0, -60.0, ALTURA_DE_LA_PLATAFORMA + 0.1, espia)
	await _apretar_e(arbol)
	a.verdadero(_carta(escena, "carta_3") == null, "RF-10 CA3: parada en la plataforma no recogió la carta 3")
	await _descargar(arbol, escena)
