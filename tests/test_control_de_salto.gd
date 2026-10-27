extends SceneTree

## Tests de ControlDeSalto: salto desde el piso, sin doble salto, coyote
## time y buffer de salto (RF-04 CA1, CA2, CA4 y CA5), a 60 frames por
## segundo como el juego.
## Se corre solo con `godot --headless --script res://tests/test_control_de_salto.gd`.

const Afirmaciones := preload("res://tests/afirmaciones.gd")
const DELTA: float = 1.0 / 60.0


func _initialize() -> void:
	var fallas: PackedStringArray = correr(self)
	for falla: String in fallas:
		printerr("FALLA: ", falla)
	print("test_control_de_salto: %d fallas" % fallas.size())
	quit(1 if fallas.size() > 0 else 0)


static func correr(_arbol: SceneTree) -> PackedStringArray:
	var a: Afirmaciones = Afirmaciones.new()
	_probar_salto_desde_el_piso(a)
	_probar_sin_doble_salto(a)
	_probar_coyote_time(a)
	_probar_buffer(a)
	return a.fallas


## Avanza `frames` frames con el mismo estado y cuenta cuántos saltos hubo.
static func _avanzar(control: ControlDeSalto, frames: int, en_el_piso: bool) -> int:
	var saltos: int = 0
	for _i: int in range(frames):
		if control.actualizar(DELTA, en_el_piso, false):
			saltos += 1
	return saltos


static func _probar_salto_desde_el_piso(a: Afirmaciones) -> void:
	var control: ControlDeSalto = ControlDeSalto.new()
	_avanzar(control, 10, true)
	a.verdadero(control.actualizar(DELTA, true, true), "RF-04 CA1: Espacio en el piso no salta")
	a.verdadero(_avanzar(control, 10, true) == 0, "RF-04 CA1: un solo Espacio saltó más de una vez")


static func _probar_sin_doble_salto(a: Afirmaciones) -> void:
	var control: ControlDeSalto = ControlDeSalto.new()
	_avanzar(control, 10, true)
	control.actualizar(DELTA, true, true)
	_avanzar(control, 2, false)
	# Todavía dentro del coyote time, pero ya saltó: no cuenta.
	a.verdadero(not control.actualizar(DELTA, false, true), "RF-04 CA2: hubo un segundo salto en el aire")
	_avanzar(control, 30, false)
	a.verdadero(not control.actualizar(DELTA, false, true), "RF-04 CA2: hubo un segundo salto en el aire")


static func _probar_coyote_time(a: Afirmaciones) -> void:
	var dentro: ControlDeSalto = ControlDeSalto.new()
	_avanzar(dentro, 10, true)
	# Cae de un borde sin saltar y aprieta a los 0,1 s.
	_avanzar(dentro, 5, false)
	a.verdadero(dentro.actualizar(DELTA, false, true), "RF-04 CA4: Espacio a 0,1 s de dejar el piso no salta")

	var fuera: ControlDeSalto = ControlDeSalto.new()
	_avanzar(fuera, 10, true)
	_avanzar(fuera, 9, false)
	a.verdadero(not fuera.actualizar(DELTA, false, true), "RF-04 CA4: Espacio a 0,17 s de dejar el piso saltó")


static func _probar_buffer(a: Afirmaciones) -> void:
	var dentro: ControlDeSalto = ControlDeSalto.new()
	_avanzar(dentro, 60, false)
	# Aprieta en el aire 0,1 s antes de aterrizar y no vuelve a apretar.
	a.verdadero(not dentro.actualizar(DELTA, false, true), "Espacio en el aire saltó sin estar cerca del piso")
	_avanzar(dentro, 5, false)
	a.verdadero(dentro.actualizar(DELTA, true, false), "RF-04 CA5: Espacio 0,1 s antes de aterrizar no saltó al tocar el piso")

	var fuera: ControlDeSalto = ControlDeSalto.new()
	_avanzar(fuera, 60, false)
	fuera.actualizar(DELTA, false, true)
	_avanzar(fuera, 10, false)
	a.verdadero(_avanzar(fuera, 10, true) == 0, "RF-04 CA5: Espacio 0,18 s antes de aterrizar saltó al tocar el piso")
