extends SceneTree

## Tests de GeometriaEsferica: la orientación sobre la esfera y, sobre todo,
## que nada se invierta al pasar por los polos (RF-02, RF-03, RNF-13, RNF-14).
## Se corre solo con `godot --headless --script res://tests/test_geometria_esferica.gd`.

const Afirmaciones := preload("res://tests/afirmaciones.gd")
const TOLERANCIA: float = 0.0001


func _initialize() -> void:
	var fallas: PackedStringArray = correr(self)
	for falla: String in fallas:
		printerr("FALLA: ", falla)
	print("test_geometria_esferica: %d fallas" % fallas.size())
	quit(1 if fallas.size() > 0 else 0)


static func correr(_arbol: SceneTree) -> PackedStringArray:
	var a: Afirmaciones = Afirmaciones.new()
	_probar_arriba(a)
	_probar_base_alineada(a)
	_probar_transporte_por_los_polos(a)
	_probar_girar_hacia(a)
	_probar_rotar_hacia(a)
	_probar_girar_vector_hacia(a)
	_probar_direccion_relativa(a)
	_probar_transform_en_superficie(a)
	_probar_fuera_de_rango(a)
	return a.fallas


static func _probar_arriba(a: Afirmaciones) -> void:
	var centro: Vector3 = Vector3(1, 2, 3)
	a.vectores_cerca(GeometriaEsferica.arriba_en(Vector3(1, 12, 3), centro), Vector3.UP, TOLERANCIA, "arriba en el polo norte")
	a.vectores_cerca(GeometriaEsferica.arriba_en(Vector3(1, -8, 3), centro), Vector3.DOWN, TOLERANCIA, "arriba en el polo sur")
	a.vectores_cerca(GeometriaEsferica.arriba_en(centro, centro), Vector3.UP, TOLERANCIA, "arriba en el centro no es nulo")


static func _probar_base_alineada(a: Afirmaciones) -> void:
	var arriba: Vector3 = Vector3(1, 1, 0).normalized()
	var base: Basis = GeometriaEsferica.base_alineada(arriba, Vector3(0, 0, -1))
	a.vectores_cerca(base.y, arriba, TOLERANCIA, "el eje Y de la base es arriba")
	a.vectores_cerca(-base.z, Vector3(0, 0, -1), TOLERANCIA, "-Z de la base es el adelante pedido")
	a.cerca(base.determinant(), 1.0, TOLERANCIA, "la base es ortonormal y sin espejar")
	a.verdadero(base.is_conformal(), "la base es conforme")

	# Adelante paralelo a arriba: no puede devolver una base degenerada.
	var degenerada: Basis = GeometriaEsferica.base_alineada(Vector3.UP, Vector3.UP)
	a.vectores_cerca(degenerada.y, Vector3.UP, TOLERANCIA, "base con adelante paralelo conserva arriba")
	a.cerca(degenerada.determinant(), 1.0, TOLERANCIA, "base con adelante paralelo es ortonormal")


## Camina por un meridiano completo pasando por los dos polos, como lo hace
## el personaje: en cada paso el adelante sale del paso anterior. El adelante
## nunca debe darse vuelta de golpe.
static func _probar_transporte_por_los_polos(a: Afirmaciones) -> void:
	var radio: float = 10.0
	var posicion: Vector3 = Vector3(0, 0, radio)
	var base: Basis = GeometriaEsferica.base_alineada(Vector3.BACK, Vector3.UP)
	var paso: float = 0.08
	var peor_continuidad: float = 1.0
	var pasos: int = int(ceil(TAU * radio / paso))
	for _i: int in range(pasos):
		var adelante: Vector3 = -base.z
		posicion = (posicion + adelante * paso).normalized() * radio
		var nueva: Basis = GeometriaEsferica.base_alineada(GeometriaEsferica.arriba_en(posicion, Vector3.ZERO), adelante)
		peor_continuidad = minf(peor_continuidad, (-nueva.z).dot(adelante))
		base = nueva
	a.verdadero(peor_continuidad > 0.99, "el adelante no se invierte al pasar por los polos (peor coseno %.4f)" % peor_continuidad)
	a.vectores_cerca(posicion.normalized(), Vector3.BACK, 0.05, "la vuelta por los polos vuelve al punto de partida")


static func _probar_girar_hacia(a: Afirmaciones) -> void:
	var girado: Vector3 = GeometriaEsferica.girar_hacia(Vector3.FORWARD, Vector3.RIGHT, Vector3.UP, deg_to_rad(30.0))
	a.cerca(rad_to_deg(Vector3.FORWARD.angle_to(girado)), 30.0, 0.01, "girar_hacia respeta el ángulo máximo")
	a.verdadero(girado.dot(Vector3.RIGHT) > 0.0, "girar_hacia gira hacia el lado del objetivo")
	var llegado: Vector3 = GeometriaEsferica.girar_hacia(Vector3.FORWARD, Vector3.RIGHT, Vector3.UP, PI)
	a.vectores_cerca(llegado, Vector3.RIGHT, TOLERANCIA, "girar_hacia llega si el ángulo alcanza")
	a.cerca(GeometriaEsferica.angulo_en_plano(Vector3.FORWARD, Vector3(1, 5, 0), Vector3.UP), PI / 2.0, TOLERANCIA, "angulo_en_plano ignora la componente vertical")


static func _probar_rotar_hacia(a: Afirmaciones) -> void:
	var desde: Quaternion = Quaternion.IDENTITY
	var hacia: Quaternion = Quaternion(Vector3.UP, PI * 0.9)
	var paso: float = PI / 60.0
	var rotado: Quaternion = GeometriaEsferica.rotar_hacia(desde, hacia, paso)
	a.cerca(desde.angle_to(rotado), paso, 0.0001, "rotar_hacia no supera 180°/s en un frame de 60 Hz")
	var cerca_del_objetivo: Quaternion = Quaternion(Vector3.UP, 0.01)
	var llegado: Quaternion = GeometriaEsferica.rotar_hacia(desde, cerca_del_objetivo, paso)
	a.verdadero(llegado.is_equal_approx(cerca_del_objetivo), "rotar_hacia llega si el ángulo alcanza")


static func _probar_girar_vector_hacia(a: Afirmaciones) -> void:
	var paso: float = PI / 60.0
	var girado: Vector3 = GeometriaEsferica.girar_vector_hacia(Vector3.UP, Vector3.RIGHT, paso)
	a.cerca(Vector3.UP.angle_to(girado), paso, TOLERANCIA, "girar_vector_hacia respeta el ángulo máximo")
	a.verdadero(girado.dot(Vector3.RIGHT) > 0.0, "girar_vector_hacia gira hacia el objetivo")
	var opuesto: Vector3 = GeometriaEsferica.girar_vector_hacia(Vector3.UP, Vector3.DOWN, paso)
	a.cerca(Vector3.UP.angle_to(opuesto), paso, TOLERANCIA, "girar_vector_hacia gira también hacia el opuesto")
	var cerca_del_objetivo: Vector3 = Vector3(0.01, 1, 0).normalized()
	a.vectores_cerca(GeometriaEsferica.girar_vector_hacia(Vector3.UP, cerca_del_objetivo, paso), cerca_del_objetivo, TOLERANCIA, "girar_vector_hacia llega si el ángulo alcanza")


static func _probar_direccion_relativa(a: Afirmaciones) -> void:
	# Cámara detrás y arriba, mirando hacia -Z con algo de inclinación.
	var camara: Basis = Basis(Vector3.RIGHT, deg_to_rad(-25.0))
	a.vectores_cerca(GeometriaEsferica.direccion_relativa(Vector2(0, -1), camara, Vector3.UP), Vector3.FORWARD, TOLERANCIA, "W aleja de la cámara")
	a.vectores_cerca(GeometriaEsferica.direccion_relativa(Vector2(0, 1), camara, Vector3.UP), Vector3.BACK, TOLERANCIA, "S acerca a la cámara")
	a.vectores_cerca(GeometriaEsferica.direccion_relativa(Vector2(1, 0), camara, Vector3.UP), Vector3.RIGHT, TOLERANCIA, "D va a la derecha")
	a.vectores_cerca(GeometriaEsferica.direccion_relativa(Vector2(-1, 0), camara, Vector3.UP), Vector3.LEFT, TOLERANCIA, "A va a la izquierda")
	var diagonal: Vector3 = GeometriaEsferica.direccion_relativa(Vector2(1, -1), camara, Vector3.UP)
	a.verdadero(diagonal.length() <= 1.0 + TOLERANCIA, "la diagonal no es más rápida")

	# En el polo sur, con la cámara alineada al personaje, W sigue siendo adelante.
	var abajo: Vector3 = Vector3.DOWN
	var base_sur: Basis = GeometriaEsferica.base_alineada(abajo, Vector3.FORWARD)
	var camara_sur: Basis = base_sur * Basis(Vector3.RIGHT, deg_to_rad(-25.0))
	a.vectores_cerca(GeometriaEsferica.direccion_relativa(Vector2(0, -1), camara_sur, abajo), -base_sur.z, TOLERANCIA, "W aleja de la cámara en el polo sur")

	# Cámara mirando justo hacia abajo: usa su eje Y y no devuelve cero.
	var cenital: Basis = Basis(Vector3.RIGHT, deg_to_rad(-90.0))
	a.verdadero(GeometriaEsferica.direccion_relativa(Vector2(0, -1), cenital, Vector3.UP).length() > 0.99, "con cámara cenital W sigue moviendo")


static func _probar_transform_en_superficie(a: Afirmaciones) -> void:
	var polo: Transform3D = GeometriaEsferica.transform_en_superficie(Vector3.ZERO, 10.0, deg_to_rad(90.0), 0.0, 0.0)
	a.vectores_cerca(polo.origin, Vector3(0, 10, 0), TOLERANCIA, "latitud 90 es el polo norte")
	a.vectores_cerca(polo.basis.y, Vector3.UP, TOLERANCIA, "en el polo norte el objeto apunta hacia afuera")
	var ecuador: Transform3D = GeometriaEsferica.transform_en_superficie(Vector3.ZERO, 10.0, 0.0, deg_to_rad(90.0), deg_to_rad(45.0))
	a.vectores_cerca(ecuador.origin, Vector3(10, 0, 0), TOLERANCIA, "longitud 90 sobre el ecuador")
	a.vectores_cerca(ecuador.basis.y, Vector3.RIGHT, TOLERANCIA, "sobre el ecuador el objeto apunta hacia afuera")
	a.cerca(ecuador.basis.determinant(), 1.0, TOLERANCIA, "el giro no deforma la base")


static func _probar_fuera_de_rango(a: Afirmaciones) -> void:
	a.verdadero(not GeometriaEsferica.fuera_de_rango(Vector3(0, 10.5, 0), Vector3.ZERO, 5.0, 25.0), "sobre la superficie está en rango")
	a.verdadero(GeometriaEsferica.fuera_de_rango(Vector3(0, 30, 0), Vector3.ZERO, 5.0, 25.0), "más lejos que la distancia máxima hay que reubicar")
	a.verdadero(GeometriaEsferica.fuera_de_rango(Vector3(0, 1, 0), Vector3.ZERO, 5.0, 25.0), "adentro del planeta hay que reubicar")
