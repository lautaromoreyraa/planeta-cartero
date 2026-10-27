extends SceneTree

## Verifica que la escena del planeta use el mismo radio y centro que las
## constantes de Planeta, de las que dependen la gravedad y la ubicación de
## los objetos. Si alguien agranda la esfera en el editor, esto lo avisa.
## Se corre solo con `godot --headless --script res://tests/test_planeta.gd`.

const Afirmaciones := preload("res://tests/afirmaciones.gd")
const ESCENA_PLANETA: PackedScene = preload("res://scenes/planeta.tscn")
const ESCENA_PRINCIPAL: PackedScene = preload("res://scenes/principal.tscn")


func _initialize() -> void:
	var fallas: PackedStringArray = correr(self)
	for falla: String in fallas:
		printerr("FALLA: ", falla)
	print("test_planeta: %d fallas" % fallas.size())
	quit(1 if fallas.size() > 0 else 0)


static func correr(_arbol: SceneTree) -> PackedStringArray:
	var a: Afirmaciones = Afirmaciones.new()
	var planeta: Planeta = ESCENA_PLANETA.instantiate()
	var colision: CollisionShape3D = planeta.get_node("Colision")
	var forma: SphereShape3D = colision.shape
	var malla: MeshInstance3D = planeta.get_node("Malla")
	var esfera: SphereMesh = malla.mesh
	a.cerca(forma.radius, Planeta.RADIO, 0.001, "el radio de la colisión coincide con Planeta.RADIO")
	a.cerca(esfera.radius, Planeta.RADIO, 0.001, "el radio de la malla coincide con Planeta.RADIO")
	a.cerca(esfera.height, Planeta.RADIO * 2.0, 0.001, "la malla es una esfera y no un elipsoide")
	planeta.free()

	var principal: Node3D = ESCENA_PRINCIPAL.instantiate()
	var en_escena: Planeta = principal.get_node("Planeta")
	a.vectores_cerca(en_escena.position, Planeta.CENTRO, 0.001, "el planeta de la escena principal está en Planeta.CENTRO")
	principal.free()

	var vuelta: float = TAU * Planeta.RADIO / Jugador.VELOCIDAD
	a.verdadero(vuelta < 60.0, "RF-01 CA1: con radio y velocidad actuales la vuelta tarda %.1f s" % vuelta)
	return a.fallas
