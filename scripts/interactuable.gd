class_name Interactuable
extends Node3D

## Componente que vuelve interactuable con E a cualquier objeto (RF-06).
##
## Se agrega como hijo de la escena del objeto (carta y, desde el hito 3,
## buzón, cartel, puerta y carta final), ubicado donde tiene que aparecer el
## indicador. El objeto escucha `interactuado` y decide qué hacer; así ni el
## jugador ni el detector necesitan conocer qué tipo de objeto es (RNF-20).

signal interactuado

## Grupo en el que el detector del jugador busca candidatos.
const GRUPO: StringName = &"interactuables"

## Apagado, el detector lo ignora: sirve para retirar un objeto en el mismo
## frame en que se usa, antes de que se libere.
var habilitado: bool = true


func _enter_tree() -> void:
	add_to_group(GRUPO)


func interactuar() -> void:
	if habilitado:
		interactuado.emit()
