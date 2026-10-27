class_name ObjetoEnSuperficie
extends Node3D

## Apoya un objeto sobre el planeta a partir de latitud y longitud.
##
## Ubicar a mano cajas sobre una esfera exige rotaciones difíciles de leer en
## la escena; con coordenadas geográficas cada objeto se acomoda solo y queda
## con su vertical hacia afuera. Al reemplazar el placeholder por un modelo de
## Kenney se mantiene este script en la raíz de la escena.

@export_range(-90.0, 90.0) var latitud: float = 0.0
@export_range(-180.0, 180.0) var longitud: float = 0.0
## Separación de la base del objeto respecto de la superficie, en metros.
@export var altura: float = 0.0
## Giro alrededor de la vertical del objeto, en grados.
@export_range(-180.0, 180.0) var giro: float = 0.0


func _ready() -> void:
	global_transform = GeometriaEsferica.transform_en_superficie(
		Planeta.CENTRO,
		Planeta.RADIO + altura,
		deg_to_rad(latitud),
		deg_to_rad(longitud),
		deg_to_rad(giro)
	)
