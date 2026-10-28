extends SceneTree

## Test de integración del hito 3: recorre una partida entera simulando el
## teclado (nueva partida con tutorial, las 4 cartas, entregas con un error,
## candado con un error, carta final y pausa) y después la retoma desde el
## guardado con la pantalla de inicio (RF-07, RF-08, RF-09 a RF-21, RF-26,
## RNF-12).
## Los textos esperados salen del config activo, así sirve también con el
## contenido real. Corre en tiempo real (unos 15 s).
## Se corre solo con `godot --headless --script res://tests/test_recorrido_completo.gd`.

const Afirmaciones := preload("res://tests/afirmaciones.gd")
const ESCENA_PRINCIPAL: PackedScene = preload("res://scenes/principal.tscn")
const ESCENA_DE_INICIO: PackedScene = preload("res://scenes/pantalla_de_inicio.tscn")
const RUTA_DE_PRUEBA: String = "user://test_recorrido.json"
## Frames para que el jugador se apoye y el detector elija el objetivo.
const FRAMES_PARA_ASENTARSE: int = 20


func _initialize() -> void:
	var fallas: PackedStringArray = await correr(self)
	for falla: String in fallas:
		printerr("FALLA: ", falla)
	print("test_recorrido_completo: %d fallas" % fallas.size())
	quit(1 if fallas.size() > 0 else 0)


static func correr(arbol: SceneTree) -> PackedStringArray:
	var a: Afirmaciones = Afirmaciones.new()
	var config: Configuracion = Configuracion.cargar()
	Guardado.borrar(RUTA_DE_PRUEBA)
	await _probar_partida_nueva(arbol, a, config)
	await _probar_continuar(arbol, a, config)
	Guardado.borrar(RUTA_DE_PRUEBA)
	return a.fallas


static func _probar_partida_nueva(arbol: SceneTree, a: Afirmaciones, config: Configuracion) -> void:
	var escena: Principal = ESCENA_PRINCIPAL.instantiate()
	escena.ruta_de_guardado = RUTA_DE_PRUEBA
	escena.mostrar_tutorial = true
	arbol.root.add_child(escena)
	await _avanzar(arbol, 10)

	# RF-09: el tutorial aparece al empezar y se cierra con Enter.
	var tutorial: String = "\n".join(config.tutorial(PackedStringArray()))
	a.verdadero(_dialogo_abierto(escena) and _texto_del_dialogo(escena) == tutorial, "RF-09 CA1: no se ve el tutorial al empezar")
	a.verdadero(arbol.paused, "con el tutorial abierto el juego no está en pausa")
	a.verdadero(not _guia_visible(escena), "RF-30 CA1: la guía se ve con el tutorial abierto")
	await _accion(arbol, &"aceptar")
	a.verdadero(not _dialogo_abierto(escena) and not arbol.paused, "RF-09 CA3: Enter no cerró el tutorial")
	a.verdadero(_guia_visible(escena), "RF-30 CA1: al cerrar el tutorial no se ve la guía")

	await _probar_pausa(arbol, a, escena)

	# RF-18 CA1: antes de la zona 2 la puerta sólo avisa.
	var oficina: Oficina = escena.get_node("Oficina")
	await _ir_a(arbol, escena, oficina.get_node("InteractuableDeLaPuerta"), 0.05)
	await _accion(arbol, &"interact")
	a.verdadero(_texto_del_dialogo(escena) == config.texto("oficina.aviso_cerrada", ""), "RF-18 CA1: la puerta cerrada no muestra el aviso")
	a.verdadero(not _panel_del_candado(escena).visible, "RF-18 CA1: el candado se abrió antes de completar la zona 2")
	await _accion(arbol, &"interact")

	await _juntar_cartas(arbol, a, escena, config)
	await _entregar(arbol, a, escena, config)

	# RF-14 y RNF-16: la pista se relee después de entregar.
	await _ir_a(arbol, escena, escena.get_node("Cartel/Interactuable"), 0.05)
	for _vez: int in range(2):
		await _accion(arbol, &"interact")
		a.verdadero(_texto_del_dialogo(escena) == config.texto("entrega.pista", ""), "RF-14 CA2: el cartel no muestra la pista")
		await _accion(arbol, &"aceptar")

	await _abrir_candado(arbol, a, escena, config)

	# RF-20: la carta final muestra el mensaje y no se cierra; Esc pausa.
	await _ir_a(arbol, escena, oficina.get_node("CartaFinal/Interactuable"), 0.05)
	await _accion(arbol, &"interact")
	a.verdadero(_texto_del_dialogo(escena) == config.texto("final.mensaje", ""), "RF-20 CA1: no se ve el mensaje final")
	a.verdadero(not _guia_visible(escena), "RF-30 CA1: la guía se ve en la carta final")
	await _accion(arbol, &"aceptar")
	a.verdadero(_dialogo_abierto(escena), "la carta final se cerró con Enter")
	await _accion(arbol, &"pause")
	a.verdadero(_menu_de_pausa(escena).visible, "RF-20 CA3: Esc en la carta final no abre la pausa")
	await _accion(arbol, &"pause")
	a.verdadero(not _menu_de_pausa(escena).visible and _dialogo_abierto(escena) and arbol.paused, "RF-07 CA4: al cerrar la pausa no se volvió a la carta final")
	await _descargar(arbol, escena)


## RF-07: Esc pausa el mundo, Continuar y Esc lo reanudan.
static func _probar_pausa(arbol: SceneTree, a: Afirmaciones, escena: Principal) -> void:
	var jugador: Jugador = escena.get_node("Jugador")
	await _accion(arbol, &"pause")
	a.verdadero(_menu_de_pausa(escena).visible and arbol.paused, "RF-07 CA2: Esc no abrió la pausa")
	var antes: Vector3 = jugador.global_position
	Input.action_press("move_forward")
	await _avanzar(arbol, 20)
	Input.action_release("move_forward")
	a.verdadero(jugador.global_position.is_equal_approx(antes), "RF-07 CA3: el jugador se movió en pausa")
	await _accion(arbol, &"aceptar")
	a.verdadero(not _menu_de_pausa(escena).visible and not arbol.paused, "RF-07 CA4: «Continuar» no cerró la pausa")
	await _accion(arbol, &"pause")
	a.verdadero(not _guia_visible(escena), "RF-30 CA1: la guía se ve con la pausa abierta")
	await _accion(arbol, &"pause")
	a.verdadero(not _menu_de_pausa(escena).visible and not arbol.paused, "RF-07 CA4: Esc otra vez no cerró la pausa")
	# Un clic en «Continuar» llega como `pressed` del botón (RF-28 CA7).
	await _accion(arbol, &"pause")
	var continuar: Button = _menu_de_pausa(escena).get_node("Centro/Panel/Contenido/Opciones").get_child(0)
	continuar.pressed.emit()
	await _avanzar(arbol, 2)
	a.verdadero(not _menu_de_pausa(escena).visible and not arbol.paused, "RF-07 CA4: el clic en «Continuar» no cerró la pausa")
	a.verdadero(_guia_visible(escena), "RF-30 CA1: al cerrar la pausa no se ve la guía")


## RF-11 y RF-21 CA1: cada carta pasa al inventario y guarda.
static func _juntar_cartas(arbol: SceneTree, a: Afirmaciones, escena: Principal, config: Configuracion) -> void:
	var cartas: Array[Node] = escena.get_node("Cartas").get_children()
	for i: int in range(cartas.size()):
		var carta: Carta = cartas[i]
		var id: String = carta.id
		# Parada a la altura de la carta: sobre el techo o la plataforma si
		# está en altura, o apenas sobre el piso.
		await _ir_a(arbol, escena, carta, carta.altura - 0.3)
		await _accion(arbol, &"interact")
		a.verdadero(not is_instance_valid(carta), "RF-11 CA1: no se recogió la carta %s" % id)
		a.verdadero(_texto_del_hud(escena) == config.texto("hud.formato_cartas", "").format({"n": i + 1}), "RF-12 CA1: el HUD muestra «%s» con %d cartas" % [_texto_del_hud(escena), i + 1])
		var guardado: EstadoDePartida = Guardado.leer(RUTA_DE_PRUEBA, config.ids_de_cartas(), Configuracion.CANTIDAD_DE_CASAS)
		a.verdadero(guardado != null and guardado.cartas_recogidas.has(id), "RF-11 CA3: recoger %s no guardó" % id)


## RF-15 a RF-17 y RF-26: una entrega correcta, un error en la segunda y las
## 4 en orden.
static func _entregar(arbol: SceneTree, a: Afirmaciones, escena: Principal, config: Configuracion) -> void:
	var orden: PackedStringArray = config.orden_de_entrega()
	var codigo: String = config.codigo()
	var codigo_hud: Label = escena.get_node("Hud/Lineas/Codigo")
	a.verdadero(not codigo_hud.visible, "RF-26 CA3: la línea del código se ve antes de revelar un dígito")

	await _usar_buzon(arbol, escena, orden[0])
	a.verdadero(_texto_del_dialogo(escena).contains(config.recuerdo(0)["texto"]), "RF-16 CA1: no se ve el recuerdo 1")
	var digito: String = config.texto("entrega.formato_digito", "").format({"posicion": 1, "digito": codigo[0]})
	a.verdadero(_texto_del_dialogo(escena).contains(digito), "RF-19 CA5: el recuerdo 1 no muestra «%s»" % digito)
	await _accion(arbol, &"aceptar")
	a.verdadero(codigo_hud.visible, "RF-26 CA1: tras el primer dígito no se ve la línea del código")
	a.verdadero(_texto_del_hud(escena) == config.texto("hud.formato_cartas", "").format({"n": 3}), "RF-12: tras entregar el HUD muestra «%s»" % _texto_del_hud(escena))

	# Error en la segunda: vuelve la carta entregada y se conserva el dígito.
	await _usar_buzon(arbol, escena, orden[2])
	a.verdadero(_texto_del_dialogo(escena) == config.texto("entrega.aviso_error", ""), "RF-17 CA1: el error no muestra el aviso")
	await _avanzar(arbol, 130)
	a.verdadero(_dialogo_abierto(escena), "RNF-15: el aviso de error no quedó 2 segundos")
	await _accion(arbol, &"interact")
	a.verdadero(_texto_del_hud(escena) == config.texto("hud.formato_cartas", "").format({"n": 4}), "RF-17 CA3: tras el error el HUD muestra «%s»" % _texto_del_hud(escena))
	a.verdadero(codigo_hud.visible and codigo_hud.text.contains(codigo[0]), "RF-17 CA4: tras el error se perdió el dígito revelado")

	for i: int in range(orden.size()):
		await _usar_buzon(arbol, escena, orden[i])
		a.verdadero(_texto_del_dialogo(escena).contains(config.recuerdo(i)["texto"]), "RF-16 CA4: no se ve el recuerdo %d" % (i + 1))
		await _accion(arbol, &"aceptar")
		var guardado: EstadoDePartida = Guardado.leer(RUTA_DE_PRUEBA, config.ids_de_cartas(), Configuracion.CANTIDAD_DE_CASAS)
		a.verdadero(guardado != null and guardado.entregas == i + 1, "RF-15 CA7: la entrega %d no guardó" % (i + 1))
	var esperado: String = config.texto("hud.formato_codigo", "").format({
		"codigo": Candado.codigo_parcial(codigo, 4, config.texto("hud.digito_oculto", ""))
	})
	a.verdadero(codigo_hud.text == esperado, "RF-19 CA6: con la zona completa el HUD muestra «%s»" % codigo_hud.text)
	a.verdadero(_texto_del_hud(escena) == config.texto("hud.formato_cartas", "").format({"n": 0}), "con todo entregado el HUD muestra «%s»" % _texto_del_hud(escena))


## RF-18 CA2 y RF-19: candado con un código equivocado y después el bueno.
static func _abrir_candado(arbol: SceneTree, a: Afirmaciones, escena: Principal, config: Configuracion) -> void:
	var oficina: Oficina = escena.get_node("Oficina")
	var panel: PanelDelCandado = _panel_del_candado(escena)
	var digitos: Label = panel.get_node("Centro/Panel/Contenido/Digitos")
	var error: Label = panel.get_node("Centro/Panel/Contenido/Error")
	var codigo: String = config.codigo()
	var equivocado: String = "1234" if codigo != "1234" else "4321"

	await _ir_a(arbol, escena, oficina.get_node("InteractuableDeLaPuerta"), 0.05)
	await _accion(arbol, &"interact")
	a.verdadero(panel.visible and arbol.paused, "RF-18 CA2: con la zona 2 completa la puerta no abre el candado")
	await _accion(arbol, &"interact")
	a.verdadero(not panel.visible and not arbol.paused, "RF-19 CA4: E no cerró el candado")
	await _accion(arbol, &"interact")

	await _escribir(arbol, equivocado + "9")
	a.verdadero(digitos.text == " ".join(equivocado.split("")), "RF-19 CA1: el candado muestra «%s»" % digitos.text)
	await _accion(arbol, &"borrar")
	await _accion(arbol, &"aceptar")
	a.verdadero(panel.visible and error.visible, "RF-19 CA3: el código equivocado no muestra el aviso")
	a.verdadero(error.text == config.texto("oficina.aviso_error", ""), "RF-19 CA3: el aviso del candado no sale del config")
	a.verdadero(not digitos.text.contains(equivocado[0]), "RF-19 CA3: el campo no se vació tras el error")

	await _escribir(arbol, codigo)
	await _accion(arbol, &"aceptar")
	await _avanzar(arbol, 2)
	a.verdadero(not panel.visible and not arbol.paused, "RF-19 CA2: el código correcto no cerró el candado")
	a.verdadero(not oficina.has_node("Puerta"), "RF-19 CA2: el código correcto no abrió la puerta")
	var guardado: EstadoDePartida = Guardado.leer(RUTA_DE_PRUEBA, config.ids_de_cartas(), Configuracion.CANTIDAD_DE_CASAS)
	a.verdadero(guardado != null and guardado.candado_abierto, "RF-19 CA2: abrir el candado no guardó")


## RF-21 CA2 y CA3: la pantalla de inicio ofrece «Continuar» y restaura el
## último checkpoint; desde ahí se llega al final (RNF-12 CA3).
static func _probar_continuar(arbol: SceneTree, a: Afirmaciones, config: Configuracion) -> void:
	var inicio: PantallaDeInicio = ESCENA_DE_INICIO.instantiate()
	inicio.ruta_de_guardado = RUTA_DE_PRUEBA
	arbol.root.add_child(inicio)
	arbol.current_scene = inicio
	await _avanzar(arbol, 5)
	var opciones: Node = inicio.get_node("Centro/Contenido/Opciones")
	a.verdadero(opciones.get_child_count() == 2, "RF-21 CA2: con guardado hay %d opciones" % opciones.get_child_count())
	a.verdadero((inicio.get_node("Centro/Contenido/Titulo") as Label).text == config.texto("inicio.titulo", ""), "RF-08 CA1: el título no sale del config")
	await _accion(arbol, &"aceptar")
	await _avanzar(arbol, 10)

	var escena: Principal = arbol.current_scene as Principal
	a.verdadero(escena != null, "RF-21 CA3: «Continuar» no abrió el juego")
	if escena == null:
		return
	a.verdadero(not _dialogo_abierto(escena), "RF-09 CA4: al continuar se mostró el tutorial")
	a.verdadero(escena.get_node("Cartas").get_child_count() == 0, "RF-21 CA3: volvieron cartas al planeta")
	var codigo_hud: Label = escena.get_node("Hud/Lineas/Codigo")
	a.verdadero(codigo_hud.visible and codigo_hud.text.contains(" ".join(config.codigo().split(""))), "RF-26 CA4: al continuar el HUD no muestra el código")
	var oficina: Oficina = escena.get_node("Oficina")
	a.verdadero(not oficina.has_node("Puerta"), "RF-18 CA3: al continuar la puerta volvió a cerrarse")
	await _ir_a(arbol, escena, oficina.get_node("CartaFinal/Interactuable"), 0.05)
	await _accion(arbol, &"interact")
	a.verdadero(_texto_del_dialogo(escena) == config.texto("final.mensaje", ""), "RNF-12 CA3: al continuar no se llega a la carta final")
	await _descargar(arbol, escena)


static func _usar_buzon(arbol: SceneTree, escena: Principal, id: String) -> void:
	for nodo: Node in escena.get_node("Casas").get_children():
		var casa: CasaConBuzon = nodo as CasaConBuzon
		if casa.id == id:
			await _ir_a(arbol, escena, casa.get_node("Buzon/Interactuable"), 0.05)
			await _accion(arbol, &"interact")


## Para al jugador debajo de `objetivo`, con los pies a `altura` metros de
## la superficie, y espera a que el detector lo elija.
static func _ir_a(arbol: SceneTree, escena: Principal, objetivo: Node3D, altura: float) -> void:
	var jugador: Jugador = escena.get_node("Jugador")
	var arriba: Vector3 = GeometriaEsferica.arriba_en(objetivo.global_position, Planeta.CENTRO)
	jugador.global_transform = Transform3D(
		GeometriaEsferica.base_alineada(arriba, -jugador.global_basis.z),
		Planeta.CENTRO + arriba * (Planeta.RADIO + altura)
	)
	jugador.velocity = Vector3.ZERO
	await _avanzar(arbol, FRAMES_PARA_ASENTARSE)


static func _accion(arbol: SceneTree, accion: StringName) -> void:
	for apretada: bool in [true, false]:
		var evento: InputEventAction = InputEventAction.new()
		evento.action = accion
		evento.pressed = apretada
		Input.parse_input_event(evento)
		await _avanzar(arbol, 2)


static func _escribir(arbol: SceneTree, digitos: String) -> void:
	for digito: String in digitos:
		for apretada: bool in [true, false]:
			var evento: InputEventKey = InputEventKey.new()
			evento.keycode = (KEY_0 + int(digito)) as Key
			evento.pressed = apretada
			Input.parse_input_event(evento)
			await _avanzar(arbol, 2)


static func _avanzar(arbol: SceneTree, frames: int) -> void:
	for _i: int in range(frames):
		await arbol.physics_frame


static func _descargar(arbol: SceneTree, escena: Node) -> void:
	escena.queue_free()
	arbol.paused = false
	await arbol.process_frame


static func _dialogo_abierto(escena: Principal) -> bool:
	return (escena.get_node("Dialogo") as Dialogo).visible


static func _texto_del_dialogo(escena: Principal) -> String:
	var texto: Label = escena.get_node("Dialogo/Centro/Panel/Contenido/Desplazable/Texto")
	return texto.text if _dialogo_abierto(escena) else ""


static func _texto_del_hud(escena: Principal) -> String:
	var etiqueta: Label = escena.get_node("Hud/Lineas/Cartas")
	return etiqueta.text


static func _guia_visible(escena: Principal) -> bool:
	return (escena.get_node("Hud/Guia") as Control).visible


static func _panel_del_candado(escena: Principal) -> PanelDelCandado:
	return escena.get_node("PanelDelCandado")


static func _menu_de_pausa(escena: Principal) -> MenuDePausa:
	return escena.get_node("MenuDePausa")
