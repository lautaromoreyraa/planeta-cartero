class_name Planeta
extends StaticBody3D

## Planeta esférico sobre el que transcurre todo el juego (RF-01).
##
## El radio y el centro son constantes compartidas: el personaje, la cámara y
## los objetos de la superficie los necesitan, y pasarlos por referencias de
## nodo sólo agregaría cableado. La escena del planeta va siempre en el origen
## y su malla y su colisión usan este mismo radio (lo verifica un test).

const RADIO: float = 10.0
const CENTRO: Vector3 = Vector3.ZERO
