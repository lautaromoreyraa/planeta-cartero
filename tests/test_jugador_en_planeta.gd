extends SceneTree

## Test de integración del personaje y la cámara: carga la escena principal,
## simula física con teclas apretadas por código y mide lo que piden los
## criterios de RF-01 a RF-05, RNF-13 y RNF-14. Corre en tiempo real (unos
## 15 s).
## Se corre solo con `godot --headless --script res://tests/test_jugador_en_planeta.gd`.

const Afirmaciones := preload("res://tests/afirmaciones.gd")
const ESCENA_PRINCIPAL: PackedScene = preload("res://scenes/principal.tscn")
const FRAMES_POR_SEGUNDO: int = 60
## Altura del techo de casa.tscn sobre la superficie, en metros.
const ALTURA_DEL_TECHO: float = 1.65


func _initialize() -> void:
	var fallas: PackedStringArray = await correr(self)
	for falla: String in fallas:
		printerr("FALLA: ", falla)
	print("test_jugador_en_planeta: %d fallas" % fallas.size())
	quit(1 if fallas.size() > 0 else 0)


static func correr(arbol: SceneTree) -> PackedStringArray:
	var a: Afirmaciones = Afirmaciones.new()
	await _probar_caida_y_alineacion(arbol, a)
	await _probar_caminata(arbol, a)
	await _probar_paso_por_el_polo_sur(arbol, a)
	await _probar_aceleracion_y_giro(arbol, a)
	await _probar_salto(arbol, a)
	await _probar_reubicacion(arbol, a)
	return a.fallas


## Instancia la escena principal; si se pasa un transform, el personaje
## arranca ahí (antes de entrar al árbol, para que la cámara lo tome de base).
static func _cargar(arbol: SceneTree, inicio: Transform3D = Transform3D()) -> Node3D:
	var escena: Node3D = ESCENA_PRINCIPAL.instantiate()
	if inicio != Transform3D():
		var jugador_inicial: Jugador = escena.get_node("Jugador")
		jugador_inicial.transform = inicio
	arbol.root.add_child(escena)
	await arbol.physics_frame
	return escena


static func _descargar(arbol: SceneTree, escena: Node3D) -> void:
	for accion: String in ["move_forward", "move_back", "move_left", "move_right", "jump"]:
		Input.action_release(accion)
	escena.queue_free()
	await arbol.process_frame


## Espera frames de física y devuelve el mayor giro de la cámara en un frame.
static func _avanzar(arbol: SceneTree, escena: Node3D, frames: int) -> float:
	var camara: Node3D = escena.get_node("CamaraSeguidora")
	var giro_maximo: float = 0.0
	for _i: int in range(frames):
		var antes: Quaternion = camara.global_basis.get_rotation_quaternion()
		await arbol.physics_frame
		giro_maximo = maxf(giro_maximo, antes.angle_to(camara.global_basis.get_rotation_quaternion()))
	return giro_maximo


static func _altura(jugador: Jugador) -> float:
	return jugador.global_position.distance_to(Planeta.CENTRO) - Planeta.RADIO


static func _verificar_giro_de_camara(a: Afirmaciones, giro: float, contexto: String) -> void:
	# Margen chico por el ruido numérico de angle_to entre cuaterniones.
	var limite: float = PI / FRAMES_POR_SEGUNDO + 0.002
	a.verdadero(giro <= limite, "%s: la cámara giró %.1f°/s, más de 180°/s" % [contexto, rad_to_deg(giro) * FRAMES_POR_SEGUNDO])


## RF-02 CA1 a CA3: cae, se apoya en menos de 3 s y queda alineado.
static func _probar_caida_y_alineacion(arbol: SceneTree, a: Afirmaciones) -> void:
	var escena: Node3D = await _cargar(arbol)
	var jugador: Jugador = escena.get_node("Jugador")
	var frames: int = 0
	while not jugador.is_on_floor() and frames < 3 * FRAMES_POR_SEGUNDO:
		await arbol.physics_frame
		frames += 1
	a.verdadero(jugador.is_on_floor(), "RF-02 CA1: el personaje no quedó apoyado en 3 s")
	await _avanzar(arbol, escena, 10)
	var arriba: Vector3 = GeometriaEsferica.arriba_en(jugador.global_position, Planeta.CENTRO)
	var inclinacion: float = rad_to_deg(jugador.global_basis.y.angle_to(arriba))
	a.verdadero(inclinacion < 5.0, "RF-02 CA2: inclinación de %.2f° respecto de la normal" % inclinacion)
	a.vectores_cerca(jugador.up_direction, arriba, 0.01, "RF-02 CA3: up_direction opuesta al centro")
	await _descargar(arbol, escena)


## RF-01 CA1 y RF-03: W lo aleja de la cámara, da la vuelta en menos de 60 s
## y al soltar frena en menos de 0,5 s.
static func _probar_caminata(arbol: SceneTree, a: Afirmaciones) -> void:
	var escena: Node3D = await _cargar(arbol)
	var jugador: Jugador = escena.get_node("Jugador")
	var camara: Camera3D = escena.get_node("CamaraSeguidora/Camara")
	await _avanzar(arbol, escena, FRAMES_POR_SEGUNDO)

	var arriba: Vector3 = GeometriaEsferica.arriba_en(jugador.global_position, Planeta.CENTRO)
	var lejos_de_camara: Vector3 = GeometriaEsferica.proyectar_en_plano(-camara.global_basis.z, arriba).normalized()
	var inicio: Vector3 = jugador.global_position
	Input.action_press("move_forward")
	var giro: float = await _avanzar(arbol, escena, 6)
	var primer_paso: Vector3 = jugador.global_position - inicio
	a.verdadero(primer_paso.normalized().dot(lejos_de_camara) > 0.9, "RF-03 CA1: W no aleja al personaje de la cámara")

	var segundos: float = 3.0
	var desde: Vector3 = jugador.global_position
	giro = maxf(giro, await _avanzar(arbol, escena, int(segundos * FRAMES_POR_SEGUNDO)))
	var angulo: float = desde.angle_to(jugador.global_position)
	var vuelta: float = TAU / (angulo / segundos) if angulo > 0.0 else INF
	a.verdadero(vuelta < 60.0, "RF-01 CA1: la vuelta completa tardaría %.1f s" % vuelta)

	Input.action_release("move_forward")
	giro = maxf(giro, await _avanzar(arbol, escena, int(0.5 * FRAMES_POR_SEGUNDO)))
	var arriba_final: Vector3 = GeometriaEsferica.arriba_en(jugador.global_position, Planeta.CENTRO)
	var horizontal: Vector3 = GeometriaEsferica.proyectar_en_plano(jugador.velocity, arriba_final)
	a.verdadero(horizontal.length() < 0.05, "RF-03 CA2: a los 0,5 s de soltar sigue a %.2f m/s" % horizontal.length())
	_verificar_giro_de_camara(a, giro, "caminata")
	await _descargar(arbol, escena)


## RF-01 CA2, RF-03 CA1 y RNF-14: cruza el polo sur caminando con W sin que
## el rumbo se invierta ni la cámara gire de golpe.
static func _probar_paso_por_el_polo_sur(arbol: SceneTree, a: Afirmaciones) -> void:
	var lugar: Transform3D = GeometriaEsferica.transform_en_superficie(
		Planeta.CENTRO, Planeta.RADIO + 0.05, deg_to_rad(-60.0), deg_to_rad(60.0), 0.0
	)
	var arriba: Vector3 = lugar.basis.y
	var hacia_el_sur: Vector3 = GeometriaEsferica.proyectar_en_plano(Vector3.DOWN, arriba)
	lugar.basis = GeometriaEsferica.base_alineada(arriba, hacia_el_sur)
	var escena: Node3D = await _cargar(arbol, lugar)
	var jugador: Jugador = escena.get_node("Jugador")
	await _avanzar(arbol, escena, 10)

	var inicio: Vector3 = jugador.global_position
	var distancia_anterior: float = 0.0
	var retrocesos: int = 0
	var mas_cerca_del_polo: float = 180.0
	var giro: float = 0.0
	Input.action_press("move_forward")
	for _i: int in range(int(2.5 * FRAMES_POR_SEGUNDO)):
		giro = maxf(giro, await _avanzar(arbol, escena, 1))
		var distancia: float = inicio.angle_to(jugador.global_position)
		if distancia < distancia_anterior - 0.0001:
			retrocesos += 1
		distancia_anterior = distancia
		mas_cerca_del_polo = minf(mas_cerca_del_polo, rad_to_deg(jugador.global_position.angle_to(Vector3.DOWN)))
	Input.action_release("move_forward")

	a.verdadero(mas_cerca_del_polo < 3.0, "RF-01 CA2: no pasó por el polo sur (quedó a %.1f°)" % mas_cerca_del_polo)
	a.verdadero(retrocesos == 0, "RF-03 CA1: al cruzar el polo retrocedió %d frames" % retrocesos)
	a.verdadero(rad_to_deg(distancia_anterior) > 55.0, "RF-03 CA1: cruzando el polo avanzó sólo %.1f°" % rad_to_deg(distancia_anterior))
	a.verdadero(jugador.is_on_floor(), "RF-01 CA2: después del polo no está apoyado")
	_verificar_giro_de_camara(a, giro, "polo sur")
	await _descargar(arbol, escena)


## RF-04: Espacio salta hacia afuera, vuelve a caer y no hay doble salto.
static func _probar_salto(arbol: SceneTree, a: Afirmaciones) -> void:
	var escena: Node3D = await _cargar(arbol)
	var jugador: Jugador = escena.get_node("Jugador")
	await _avanzar(arbol, escena, FRAMES_POR_SEGUNDO)
	var piso: float = _altura(jugador)

	Input.action_press("jump")
	await _avanzar(arbol, escena, 2)
	Input.action_release("jump")
	await _avanzar(arbol, escena, 15)
	# Segundo Espacio en el aire: no tiene que volver a impulsarlo.
	Input.action_press("jump")
	await _avanzar(arbol, escena, 2)
	Input.action_release("jump")

	var maxima: float = 0.0
	# Ya pasaron 19 frames en el aire desde el despegue.
	var frames_hasta_la_cima: int = 19
	var frames_en_el_aire: int = 19
	var subio_de_nuevo: bool = false
	var anterior: float = _altura(jugador) - piso
	var bajando: bool = false
	for _i: int in range(int(1.5 * FRAMES_POR_SEGUNDO)):
		await arbol.physics_frame
		var altura: float = _altura(jugador) - piso
		if not jugador.is_on_floor():
			frames_en_el_aire += 1
		if altura > maxima:
			maxima = altura
			frames_hasta_la_cima = frames_en_el_aire
		if bajando and altura > anterior + 0.001:
			subio_de_nuevo = true
		bajando = bajando or altura < anterior
		anterior = altura

	var esperada: float = Jugador.IMPULSO_DE_SALTO * Jugador.IMPULSO_DE_SALTO / (2.0 * Jugador.GRAVEDAD)
	a.cerca(maxima, esperada, 0.25, "RF-04 CA1: altura del salto")
	a.verdadero(maxima > ALTURA_DEL_TECHO, "RF-04 CA3: el salto (%.2f m) no alcanza los techos" % maxima)
	a.verdadero(not subio_de_nuevo, "RF-04 CA2: hubo un segundo impulso en el aire")
	var bajada: int = frames_en_el_aire - frames_hasta_la_cima
	a.verdadero(bajada < frames_hasta_la_cima, "RF-04 CA6: la bajada (%d frames) no es más rápida que la subida (%d)" % [bajada, frames_hasta_la_cima])
	a.verdadero(jugador.is_on_floor(), "RF-04 CA1: no volvió a caer al planeta")
	await _descargar(arbol, escena)


## RNF-13: lejos del planeta se lo reubica en el punto seguro.
static func _probar_reubicacion(arbol: SceneTree, a: Afirmaciones) -> void:
	var escena: Node3D = await _cargar(arbol)
	var jugador: Jugador = escena.get_node("Jugador")
	var punto_seguro: Vector3 = jugador.global_position
	await _avanzar(arbol, escena, 10)
	jugador.global_position = Vector3(0, Jugador.DISTANCIA_MAXIMA + 5.0, 0)
	await _avanzar(arbol, escena, 2)
	a.verdadero(jugador.global_position.distance_to(punto_seguro) < 0.5, "RNF-13: no se reubicó al alejarse del planeta")
	jugador.global_position = Vector3(0, 1, 0)
	await _avanzar(arbol, escena, 2)
	a.verdadero(jugador.global_position.distance_to(punto_seguro) < 0.5, "RNF-13: no se reubicó al atravesar el suelo")
	await _descargar(arbol, escena)


## Ángulo entre dos direcciones sobre el plano tangente en la posición del
## jugador, en grados.
static func _desvio(jugador: Jugador, a: Vector3, b: Vector3) -> float:
	var arriba: Vector3 = GeometriaEsferica.arriba_en(jugador.global_position, Planeta.CENTRO)
	return rad_to_deg(GeometriaEsferica.angulo_en_plano(a, b, arriba))


## RF-03 CA3 a CA5: arranque progresivo, media vuelta progresiva y el
## frente hacia donde camina.
static func _probar_aceleracion_y_giro(arbol: SceneTree, a: Afirmaciones) -> void:
	var escena: Node3D = await _cargar(arbol)
	var jugador: Jugador = escena.get_node("Jugador")
	await _avanzar(arbol, escena, FRAMES_POR_SEGUNDO)

	Input.action_press("move_forward")
	await _avanzar(arbol, escena, 1)
	var primera: float = jugador.rapidez()
	a.verdadero(primera > 0.0 and primera < Jugador.VELOCIDAD, "RF-03 CA3: en el primer frame va a %.2f m/s" % primera)
	var frames_hasta_el_maximo: int = 1
	while jugador.rapidez() < 0.95 * Jugador.VELOCIDAD and frames_hasta_el_maximo < FRAMES_POR_SEGUNDO:
		await _avanzar(arbol, escena, 1)
		frames_hasta_el_maximo += 1
	a.verdadero(frames_hasta_el_maximo <= int(0.3 * FRAMES_POR_SEGUNDO), "RF-03 CA3: tardó %d frames en llegar al 95 %% de la velocidad" % frames_hasta_el_maximo)
	await _avanzar(arbol, escena, 20)
	var desvio: float = _desvio(jugador, jugador.mirada(), jugador.velocity)
	a.verdadero(desvio < 10.0, "RF-03 CA5: caminando con W el frente se desvía %.1f°" % desvio)

	# Media vuelta: de W a S. El giro termina cuando el frente queda a menos
	# de 10° de la nueva dirección de movimiento.
	var hacia_atras: Vector3 = -jugador.mirada()
	Input.action_release("move_forward")
	Input.action_press("move_back")
	var frames_de_giro: int = 0
	while _desvio(jugador, jugador.mirada(), hacia_atras) >= 10.0 and frames_de_giro < FRAMES_POR_SEGUNDO:
		await _avanzar(arbol, escena, 1)
		frames_de_giro += 1
	a.verdadero(frames_de_giro > 1, "RF-03 CA4: la media vuelta fue instantánea")
	a.verdadero(frames_de_giro <= int(0.3 * FRAMES_POR_SEGUNDO), "RF-03 CA4: la media vuelta tardó %d frames" % frames_de_giro)
	await _avanzar(arbol, escena, 20)
	desvio = _desvio(jugador, jugador.mirada(), jugador.velocity)
	a.verdadero(desvio < 10.0, "RF-03 CA5: caminando con S el frente se desvía %.1f°" % desvio)

	var mirada: Vector3 = jugador.mirada()
	Input.action_release("move_back")
	await _avanzar(arbol, escena, 30)
	a.verdadero(_desvio(jugador, jugador.mirada(), mirada) < 1.0, "RF-03 CA5: al detenerse cambió de orientación")
	await _descargar(arbol, escena)

