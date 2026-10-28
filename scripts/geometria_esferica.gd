class_name GeometriaEsferica
extends RefCounted

## Cálculos de orientación sobre una esfera, sin depender de escenas.
##
## Viven aparte del personaje y de la cámara para poder probarlos con tests
## headless: son la parte delicada del hito (los polos), y un error acá se ve
## como controles invertidos o una cámara que da vueltas.

## Por debajo de esto un vector se considera nulo: evita normalizar ruido.
const EPSILON: float = 0.000001


## Dirección «arriba» en un punto: opuesta al centro del planeta.
static func arriba_en(posicion: Vector3, centro: Vector3) -> Vector3:
	var desde_centro: Vector3 = posicion - centro
	if desde_centro.length_squared() < EPSILON:
		# En el centro exacto no hay arriba; cualquiera sirve para no dividir por cero.
		return Vector3.UP
	return desde_centro.normalized()


## Proyecta un vector sobre el plano perpendicular a `normal` (normal unitaria).
static func proyectar_en_plano(vector: Vector3, normal: Vector3) -> Vector3:
	return vector - normal * vector.dot(normal)


## Base con Y = `arriba` y -Z lo más parecido posible a `adelante`.
##
## Se recalcula cada frame a partir del adelante del frame anterior, así el
## rumbo se «transporta» por la superficie sin referirse a ejes globales: por
## eso no hay un punto singular en los polos.
static func base_alineada(arriba: Vector3, adelante: Vector3) -> Basis:
	var y: Vector3 = arriba.normalized()
	var frente: Vector3 = proyectar_en_plano(adelante, y)
	if frente.length_squared() < EPSILON:
		# Adelante paralelo a arriba: se elige un perpendicular cualquiera
		# para no devolver una base degenerada.
		var auxiliar: Vector3 = Vector3.RIGHT if absf(y.x) < 0.9 else Vector3.FORWARD
		frente = y.cross(auxiliar)
	frente = frente.normalized()
	var z: Vector3 = -frente
	var x: Vector3 = y.cross(z)
	return Basis(x, y, z)


## Gira `actual` hacia `objetivo` alrededor de `eje`, como mucho `angulo_maximo`
## radianes. Ambos se proyectan sobre el plano del eje antes de girar.
static func girar_hacia(actual: Vector3, objetivo: Vector3, eje: Vector3, angulo_maximo: float) -> Vector3:
	var desde: Vector3 = proyectar_en_plano(actual, eje)
	var hacia: Vector3 = proyectar_en_plano(objetivo, eje)
	if desde.length_squared() < EPSILON:
		return hacia.normalized()
	if hacia.length_squared() < EPSILON:
		return desde.normalized()
	var angulo: float = desde.signed_angle_to(hacia, eje)
	var paso: float = clampf(angulo, -angulo_maximo, angulo_maximo)
	return desde.normalized().rotated(eje.normalized(), paso)


## Ángulo sin signo entre dos direcciones medidas sobre el plano de `eje`.
static func angulo_en_plano(a: Vector3, b: Vector3, eje: Vector3) -> float:
	var pa: Vector3 = proyectar_en_plano(a, eje)
	var pb: Vector3 = proyectar_en_plano(b, eje)
	if pa.length_squared() < EPSILON or pb.length_squared() < EPSILON:
		return 0.0
	return pa.angle_to(pb)


## Gira el vector unitario `actual` hacia `objetivo` como mucho
## `angulo_maximo` radianes. Acota el giro del «arriba» de la cámara cuando
## el personaje se reubica de golpe (RNF-14).
static func girar_vector_hacia(actual: Vector3, objetivo: Vector3, angulo_maximo: float) -> Vector3:
	var angulo: float = actual.angle_to(objetivo)
	if angulo <= angulo_maximo:
		return objetivo.normalized()
	var eje: Vector3 = actual.cross(objetivo)
	if eje.length_squared() < EPSILON:
		# Opuestos: cualquier eje perpendicular sirve para empezar a girar.
		eje = actual.cross(Vector3.RIGHT if absf(actual.x) < 0.9 else Vector3.FORWARD)
	return actual.rotated(eje.normalized(), angulo_maximo).normalized()


## Rota `actual` hacia `objetivo` sin superar `angulo_maximo` radianes.
## Es el límite de velocidad de giro de la cámara (RNF-14).
static func rotar_hacia(actual: Quaternion, objetivo: Quaternion, angulo_maximo: float) -> Quaternion:
	var angulo: float = actual.angle_to(objetivo)
	if angulo <= angulo_maximo or angulo < EPSILON:
		return objetivo
	return actual.slerp(objetivo, angulo_maximo / angulo)


## Dirección de movimiento sobre la superficie para una entrada de teclado
## (x: derecha, y: atrás, como la devuelve `Input.get_vector`), relativa a la
## cámara. Largo como mucho 1.
static func direccion_relativa(entrada: Vector2, base_camara: Basis, arriba: Vector3) -> Vector3:
	var adelante: Vector3 = proyectar_en_plano(-base_camara.z, arriba)
	if adelante.length_squared() < EPSILON:
		# Cámara mirando justo hacia abajo: su eje Y apunta adonde mira la pantalla.
		adelante = proyectar_en_plano(base_camara.y, arriba)
	if adelante.length_squared() < EPSILON:
		return Vector3.ZERO
	adelante = adelante.normalized()
	var derecha: Vector3 = adelante.cross(arriba.normalized())
	var direccion: Vector3 = derecha * entrada.x - adelante * entrada.y
	return direccion.limit_length(1.0)


## Ángulo en radianes con el que una flecha de pantalla apunta desde
## `desde` hacia `hacia`, según la vista de la cámara (RF-30 CA2): 0 es hacia
## arriba de la pantalla (lo que W aleja de la cámara) y crece en sentido
## horario, como `Control.rotation`. Se mide sobre el plano tangente en
## `desde`, así un objetivo del otro lado del planeta apunta por el camino
## más corto sobre la superficie.
static func angulo_en_pantalla(desde: Vector3, hacia: Vector3, arriba: Vector3, base_camara: Basis) -> float:
	var direccion: Vector3 = proyectar_en_plano(hacia - desde, arriba)
	var adelante: Vector3 = direccion_relativa(Vector2(0.0, -1.0), base_camara, arriba)
	if direccion.length_squared() < EPSILON or adelante.length_squared() < EPSILON:
		return 0.0
	var derecha: Vector3 = adelante.cross(arriba.normalized())
	return atan2(direccion.dot(derecha), direccion.dot(adelante))


## Transform de un objeto apoyado en la superficie: origen a `distancia` del
## centro según latitud y longitud (radianes), Y hacia afuera y girado `giro`
## radianes alrededor de su vertical.
static func transform_en_superficie(centro: Vector3, distancia: float, latitud: float, longitud: float, giro: float) -> Transform3D:
	var direccion: Vector3 = Vector3(cos(latitud) * sin(longitud), sin(latitud), cos(latitud) * cos(longitud))
	var base: Basis = base_alineada(direccion, Vector3.FORWARD)
	base = Basis(direccion, giro) * base
	return Transform3D(base, centro + direccion * distancia)


## Verdadero si el punto quedó fuera de la franja segura alrededor del planeta
## (muy lejos o atravesó el suelo) y hay que reubicar al personaje (RNF-13).
static func fuera_de_rango(posicion: Vector3, centro: Vector3, distancia_minima: float, distancia_maxima: float) -> bool:
	var distancia: float = posicion.distance_to(centro)
	return distancia > distancia_maxima or distancia < distancia_minima
