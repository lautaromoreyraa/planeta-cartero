class_name ControlDeSalto
extends RefCounted

## Decide en cada frame de física si el personaje salta, con coyote time y
## buffer de salto (RF-04 CA2, CA4 y CA5).
##
## Vive aparte del personaje para probar las ventanas de tiempo con tests
## headless deterministas: con la física real, medir 0,12 s exactos depende
## de en qué frame toca el piso.

## Segundos después de dejar el piso sin saltar en los que Espacio todavía
## salta (coyote time): perdona apretar un poco tarde al caer de un borde.
const COYOTE: float = 0.12
## Segundos antes de aterrizar en los que un Espacio apretado en el aire se
## guarda y salta al tocar el piso (buffer de salto).
const BUFFER: float = 0.12

## Segundos desde que el personaje estuvo en el piso por última vez.
var _desde_el_piso: float = INF
## Segundos desde el último Espacio que todavía no se usó.
var _desde_que_apreto: float = INF
## Verdadero desde que saltó hasta que vuelve a apoyarse: el coyote time no
## puede convertirse en un segundo salto (RF-04 CA2).
var _en_un_salto: bool = false


## Avanza `delta` segundos con el estado del frame y devuelve verdadero si
## el personaje tiene que saltar en este frame.
func actualizar(delta: float, en_el_piso: bool, apreto: bool) -> bool:
	_desde_que_apreto = 0.0 if apreto else _desde_que_apreto + delta
	if en_el_piso:
		_desde_el_piso = 0.0
		_en_un_salto = false
	else:
		_desde_el_piso += delta
	if _en_un_salto or _desde_el_piso > COYOTE or _desde_que_apreto > BUFFER:
		return false
	# El Espacio se consume para que un mismo apretón no salte dos veces.
	_en_un_salto = true
	_desde_que_apreto = INF
	return true
