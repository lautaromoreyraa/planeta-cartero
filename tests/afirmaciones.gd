extends RefCounted

## Acumula las fallas de un test sin cortar en la primera, para que una
## corrida muestre todo lo que está mal de una vez.

var fallas: PackedStringArray = PackedStringArray()


func verdadero(condicion: bool, mensaje: String) -> void:
	if not condicion:
		fallas.append(mensaje)


func cerca(obtenido: float, esperado: float, tolerancia: float, mensaje: String) -> void:
	if absf(obtenido - esperado) > tolerancia:
		fallas.append("%s (obtenido %.4f, esperado %.4f)" % [mensaje, obtenido, esperado])


func vectores_cerca(obtenido: Vector3, esperado: Vector3, tolerancia: float, mensaje: String) -> void:
	if obtenido.distance_to(esperado) > tolerancia:
		fallas.append("%s (obtenido %s, esperado %s)" % [mensaje, obtenido, esperado])
