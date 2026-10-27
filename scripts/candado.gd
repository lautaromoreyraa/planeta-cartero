class_name Candado
extends RefCounted

## Reglas del candado de 4 dígitos de la oficina (RF-19), sin depender de
## escenas para poder probarlas headless (RT-05).
##
## El código es un texto y no un número: así «0427» conserva el cero de
## adelante y se compara carácter por carácter.

const LARGO: int = 4
const DIGITOS: String = "0123456789"


## Verdadero si `codigo` son exactamente 4 dígitos del 0 al 9.
static func es_codigo_valido(codigo: String) -> bool:
	if codigo.length() != LARGO:
		return false
	for caracter: String in codigo:
		if not DIGITOS.contains(caracter):
			return false
	return true


## Verdadero si lo ingresado abre el candado de `codigo`.
static func es_correcto(ingresado: String, codigo: String) -> bool:
	return es_codigo_valido(ingresado) and ingresado == codigo


## Lo ingresado con `digito` al final; ignora lo que no es un dígito o si ya
## hay 4 (RF-19 CA1).
static func agregar_digito(ingresado: String, digito: String) -> String:
	if ingresado.length() >= LARGO or digito.length() != 1 or not DIGITOS.contains(digito):
		return ingresado
	return ingresado + digito


static func borrar_digito(ingresado: String) -> String:
	return ingresado.left(-1) if not ingresado.is_empty() else ingresado


## Dígito número `posicion` (de 1 a 4) del código: el que revela el recuerdo
## de la entrega correcta con ese número (RF-19 CA5).
static func digito_revelado(codigo: String, posicion: int) -> String:
	if posicion < 1 or posicion > codigo.length():
		return ""
	return codigo[posicion - 1]


## Las 4 posiciones separadas por espacios: el dígito si ya se reveló o
## `oculto` si no («0 4 _ _», RF-26 CA1).
static func codigo_parcial(codigo: String, revelados: int, oculto: String) -> String:
	var partes: PackedStringArray = PackedStringArray()
	for posicion: int in range(1, LARGO + 1):
		partes.append(digito_revelado(codigo, posicion) if posicion <= revelados else oculto)
	return " ".join(partes)
