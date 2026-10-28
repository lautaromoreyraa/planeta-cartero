class_name Principal
extends Node3D

## Escena del juego: arma el config, el inventario, la secuencia de entrega
## y el guardado, y los conecta por señales con los objetos del planeta y
## con la interfaz (RNF-20).
##
## La pantalla de inicio la crea, le pasa el config y el estado guardado, y
## recién después la agrega al árbol. Cargada sola (como en los tests) arranca
## una partida nueva sin tutorial y sin guardar, para no pisar la partida de
## la jugadora.

## Textos por defecto si falta la clave en el config (RF-22 CA2).
const TUTORIAL_POR_DEFECTO: PackedStringArray = [
	"Mouse: mirar alrededor",
	"WASD o flechas: moverte",
	"Espacio: saltar",
	"E: interactuar",
	"Esc: pausa",
]
const PISTA_POR_DEFECTO: String = "Entregá las cartas en orden."
const FORMATO_DIGITO_POR_DEFECTO: String = "Dígito {posicion}: {digito}"
const AVISO_DE_ERROR_POR_DEFECTO: String = "Ese no era el buzón. Las cartas volvieron a tu bolso."
const SIN_CARTAS_POR_DEFECTO: String = "No tenés cartas para entregar."
const OFICINA_CERRADA_POR_DEFECTO: String = "La oficina abre cuando entregues todas las cartas."
const MENSAJE_FINAL_POR_DEFECTO: String = "¡Feliz cumpleaños!"
const INDICACION_FINAL_POR_DEFECTO: String = "Esc para la pausa"

var config: Configuracion = null
## Estado del último checkpoint al elegir «Continuar»; nulo, partida nueva.
var estado_inicial: EstadoDePartida = null
var mostrar_tutorial: bool = false
## Archivo donde se guardan los checkpoints; vacío, no se guarda.
var ruta_de_guardado: String = ""

@onready var _hud: Hud = $Hud
@onready var _jugador: Jugador = $Jugador
@onready var _control_del_cursor: ControlDelCursor = $ControlDelCursor
@onready var _detector: DetectorDeInteraccion = $Jugador/DetectorDeInteraccion
@onready var _cartas: Node3D = $Cartas
@onready var _casas: Node3D = $Casas
@onready var _cartel: Cartel = $Cartel
@onready var _oficina: Oficina = $Oficina
@onready var _dialogo: Dialogo = $Dialogo
@onready var _panel_del_candado: PanelDelCandado = $PanelDelCandado
@onready var _menu_de_pausa: MenuDePausa = $MenuDePausa

var _inventario: InventarioDeCartas = InventarioDeCartas.new()
var _secuencia: SecuenciaDeEntrega = null
var _codigo: String = ""
var _candado_abierto: bool = false


func _ready() -> void:
	if config == null:
		config = Configuracion.cargar_para_el_juego()
	_codigo = config.codigo()
	_secuencia = SecuenciaDeEntrega.new(config.orden_de_entrega())
	_hud.configurar(config)
	_dialogo.configurar(config)
	_panel_del_candado.configurar(config, _codigo)
	_menu_de_pausa.configurar(config)
	_configurar_casas()

	# Se restaura antes de conectar el inventario para que rearmar la partida
	# no cuente como checkpoints nuevos.
	if estado_inicial != null:
		_restaurar(estado_inicial)

	_inventario.carta_recogida.connect(_al_juntar_carta)
	_inventario.cantidad_cambiada.connect(_actualizar_hud.unbind(1))
	_detector.objetivo_cambiado.connect(_hud.mostrar_objetivo)
	_control_del_cursor.juego_en_curso_cambiado.connect(_hud.mostrar_guia)
	for carta: Carta in _cartas_en_el_planeta():
		carta.recogida.connect(_al_recoger_carta)
	_cartel.leido.connect(_al_leer_el_cartel)
	_oficina.puerta_usada.connect(_al_usar_la_puerta)
	_oficina.carta_final_usada.connect(_al_abrir_la_carta_final)
	_panel_del_candado.abierto.connect(_al_abrir_el_candado)

	_actualizar_hud()
	_actualizar_buzones()
	if mostrar_tutorial:
		_dialogo.mostrar("\n".join(config.tutorial(TUTORIAL_POR_DEFECTO)))


## La guía se reorienta en cada frame de física; con el juego en pausa no
## corre, igual que el mundo (RF-30).
func _physics_process(_delta: float) -> void:
	var camara: Camera3D = get_viewport().get_camera_3d()
	if camara == null:
		return
	var cartas: PackedVector3Array = PackedVector3Array()
	for carta: Carta in _cartas_en_el_planeta():
		cartas.append(carta.global_position)
	var ids: PackedStringArray = PackedStringArray()
	var buzones: PackedVector3Array = PackedVector3Array()
	for nodo: Node in _casas.get_children():
		var casa: CasaConBuzon = nodo as CasaConBuzon
		ids.append(casa.id)
		buzones.append(casa.posicion_del_buzon())
	var objetivo: Vector3 = GuiaDeObjetivo.elegir(
		_jugador.global_position, cartas, ids, buzones, _secuencia,
		_oficina.posicion_de_la_puerta(), _oficina.posicion_de_la_carta_final(), _candado_abierto
	)
	var arriba: Vector3 = GeometriaEsferica.arriba_en(_jugador.global_position, Planeta.CENTRO)
	_hud.orientar_guia(GeometriaEsferica.angulo_en_pantalla(_jugador.global_position, objetivo, arriba, camara.global_basis))


func _configurar_casas() -> void:
	var datos: Array[Dictionary] = config.casas()
	var casas: Array[Node] = _casas.get_children()
	for i: int in range(mini(datos.size(), casas.size())):
		var casa: CasaConBuzon = casas[i] as CasaConBuzon
		casa.configurar(datos[i]["id"], datos[i]["rotulo"])
		casa.buzon_usado.connect(_al_usar_un_buzon)


func _restaurar(estado: EstadoDePartida) -> void:
	for carta: Carta in _cartas_en_el_planeta():
		if estado.cartas_recogidas.has(carta.id):
			carta.retirar()
	for id: String in estado.cartas_recogidas:
		_inventario.recoger(id)
	_secuencia.restaurar(estado.entregas, estado.digitos_revelados)
	if estado.candado_abierto:
		_candado_abierto = true
		_oficina.abrir()


func _cartas_en_el_planeta() -> Array[Carta]:
	var cartas: Array[Carta] = []
	for nodo: Node in _cartas.get_children():
		var carta: Carta = nodo as Carta
		if carta != null and not carta.is_queued_for_deletion():
			cartas.append(carta)
	return cartas


## Las cartas en la mano son las juntadas menos las entregadas en la
## secuencia actual (ver `SecuenciaDeEntrega`).
func _cartas_en_mano() -> int:
	return _inventario.cantidad() - _secuencia.entregas()


func _actualizar_hud() -> void:
	_hud.mostrar_cartas(_cartas_en_mano())
	_hud.mostrar_codigo(_codigo, _secuencia.digitos_revelados())


func _actualizar_buzones() -> void:
	for nodo: Node in _casas.get_children():
		var casa: CasaConBuzon = nodo as CasaConBuzon
		casa.marcar_entregado(_secuencia.fue_entregada(casa.id))


func _al_recoger_carta(carta: Carta) -> void:
	if _inventario.recoger(carta.id):
		carta.retirar()
		_jugador.hacer_gesto(Personaje.Gesto.RECOGER)


## Recoger una carta es un checkpoint (RF-11 CA3).
func _al_juntar_carta(id: String) -> void:
	var texto: String = config.texto_al_recoger(id)
	if not texto.is_empty():
		_hud.mostrar_aviso(texto)
	_guardar()


func _al_usar_un_buzon(casa: CasaConBuzon) -> void:
	_jugador.hacer_gesto(Personaje.Gesto.INTERACTUAR)
	match _secuencia.entregar(casa.id, _cartas_en_mano()):
		SecuenciaDeEntrega.Resultado.CORRECTA:
			_mostrar_recuerdo(_secuencia.entregas())
			_guardar()
		SecuenciaDeEntrega.Resultado.ERROR:
			_dialogo.mostrar(config.texto("entrega.aviso_error", AVISO_DE_ERROR_POR_DEFECTO))
		SecuenciaDeEntrega.Resultado.SIN_CARTAS:
			_dialogo.mostrar(config.texto("entrega.sin_cartas", SIN_CARTAS_POR_DEFECTO))
	_actualizar_hud()
	_actualizar_buzones()


## El recuerdo de la entrega número `numero` lleva el dígito `numero` del
## código (RF-16, RF-19 CA5). Se muestra cada vez, aunque ya se haya visto.
func _mostrar_recuerdo(numero: int) -> void:
	var recuerdo: Dictionary = config.recuerdo(numero - 1)
	var digito: String = config.texto("entrega.formato_digito", FORMATO_DIGITO_POR_DEFECTO).format({
		"posicion": numero,
		"digito": Candado.digito_revelado(_codigo, numero),
	})
	var texto: String = recuerdo["texto"]
	_dialogo.mostrar(digito if texto.is_empty() else "%s\n\n%s" % [texto, digito], recuerdo["imagen"])


func _al_leer_el_cartel() -> void:
	_jugador.hacer_gesto(Personaje.Gesto.INTERACTUAR)
	_dialogo.mostrar(config.texto("entrega.pista", PISTA_POR_DEFECTO))


## La puerta se habilita al completar la zona 2 (RF-18).
func _al_usar_la_puerta() -> void:
	_jugador.hacer_gesto(Personaje.Gesto.INTERACTUAR)
	if _secuencia.completa():
		_panel_del_candado.abrir()
	else:
		_dialogo.mostrar(config.texto("oficina.aviso_cerrada", OFICINA_CERRADA_POR_DEFECTO))


## Abrir el candado es un checkpoint (RF-19 CA2).
func _al_abrir_el_candado() -> void:
	_candado_abierto = true
	_oficina.abrir()
	_jugador.hacer_gesto(Personaje.Gesto.FESTEJAR)
	_guardar()


## La carta final no se cierra: desde ahí sólo queda la pausa (RF-20 CA3).
func _al_abrir_la_carta_final() -> void:
	_dialogo.mostrar(
		config.texto("final.mensaje", MENSAJE_FINAL_POR_DEFECTO),
		config.imagen_final(),
		config.texto("final.indicacion", INDICACION_FINAL_POR_DEFECTO),
		false
	)


func _guardar() -> void:
	if ruta_de_guardado.is_empty():
		return
	var estado: EstadoDePartida = EstadoDePartida.new()
	estado.cartas_recogidas = _inventario.ids()
	estado.entregas = _secuencia.entregas()
	estado.digitos_revelados = _secuencia.digitos_revelados()
	estado.candado_abierto = _candado_abierto
	Guardado.escribir(ruta_de_guardado, estado)
