class_name Interactable
extends Area3D
## Marks something the player can check with the interact button.
## The parent node must implement `interact() -> void` (may be a coroutine).

signal interacted


func can_interact() -> bool:
	var p := get_parent()
	return not p.has_method("can_interact") or p.can_interact()


func interact() -> void:
	interacted.emit()
	await get_parent().interact()
