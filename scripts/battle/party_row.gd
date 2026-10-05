class_name PartyRow
extends HBoxContainer
## One hero's line in the battle status panel.

const GOLD := Color(1.0, 0.84, 0.45)
const TEXT := Color(0.95, 0.93, 0.88)
const KO := Color(1, 0.4, 0.4)


func show_battler(b: Battler, is_active: bool) -> void:
	%Cursor.text = "▶" if is_active else ""
	%NameLabel.text = b.display_name
	%NameLabel.add_theme_color_override("font_color", GOLD if is_active else (KO if not b.alive() else TEXT))
	%HPLabel.text = "HP %d/%d" % [b.hp, b.max_hp()]
	%HPBar.max_value = b.max_hp()
	%HPBar.value = b.hp
	%HPBar.color = Color(0.4, 0.95, 0.5) if b.hp > b.max_hp() / 4 else Color(1.0, 0.6, 0.2)
	%MPLabel.text = "MP %d/%d" % [b.mp, b.max_mp()]
	%MPBar.max_value = b.max_mp()
	%MPBar.value = b.mp
	var tags: Array[String] = []
	if not b.alive():
		tags.append("KO")
	else:
		if b.provoke > 0:
			tags.append("Taunt")
		for k in b.buffs:
			tags.append(("%s↑" if b.buffs[k].mult > 1.0 else "%s↓") % k.to_upper())
	%StatusLabel.text = " ".join(tags)
