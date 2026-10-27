extends Node3D

## Escena principal del juego: arma el config, el inventario y el HUD y los
## conecta por señales con las cartas y el detector del jugador (RNF-20).
##
## En el hito 1 Esc cierra el juego directamente; el comportamiento definitivo
## (pausa o salida) se decide en el hito 3 (RF-07).

@onready var _hud: Hud = $Hud
@onready var _detector: DetectorDeInteraccion = $Jugador/DetectorDeInteraccion
@onready var _cartas: Node3D = $Cartas

var _inventario: InventarioDeCartas = InventarioDeCartas.new()


func _ready() -> void:
	var config: Configuracion = Configuracion.desde_archivo(Configuracion.RUTA)
	_hud.configurar(config)
	for aviso: String in config.avisos:
		push_warning(aviso)

	_inventario.cantidad_cambiada.connect(_hud.mostrar_cartas)
	_detector.objetivo_cambiado.connect(_hud.mostrar_objetivo)
	for nodo: Node in _cartas.get_children():
		var carta: Carta = nodo as Carta
		if carta != null:
			carta.recogida.connect(_al_recoger_carta)
	_hud.mostrar_cartas(_inventario.cantidad())


func _unhandled_input(evento: InputEvent) -> void:
	if evento.is_action_pressed("pause"):
		get_tree().quit()


func _al_recoger_carta(carta: Carta) -> void:
	if _inventario.recoger(carta.id):
		carta.retirar()
