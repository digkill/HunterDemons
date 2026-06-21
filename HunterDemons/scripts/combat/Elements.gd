class_name Elements
## Стихии и фракции демонов: цвета, слабости, сопротивления.

enum Type { PHYSICAL, FIRE, EARTH, AIR, WATER, UNDEAD, GHOST }

const NAMES := {
	Type.PHYSICAL: "Физический",
	Type.FIRE: "Огонь",
	Type.EARTH: "Земля",
	Type.AIR: "Воздух",
	Type.WATER: "Вода",
	Type.UNDEAD: "Нежить",
	Type.GHOST: "Призрак",
}

const COLORS := {
	Type.PHYSICAL: Color(0.9, 0.9, 0.9),
	Type.FIRE: Color(1.0, 0.45, 0.15),
	Type.EARTH: Color(0.62, 0.45, 0.25),
	Type.AIR: Color(0.7, 0.95, 1.0),
	Type.WATER: Color(0.25, 0.55, 1.0),
	Type.UNDEAD: Color(0.45, 0.75, 0.35),
	Type.GHOST: Color(0.8, 0.7, 1.0),
}

# Фракция демона -> стихия, от которой он получает x1.5 урона.
const WEAKNESS := {
	Type.FIRE: Type.WATER,
	Type.WATER: Type.AIR,
	Type.AIR: Type.EARTH,
	Type.EARTH: Type.FIRE,
	Type.UNDEAD: Type.FIRE,
	Type.GHOST: Type.AIR,
}

# Фракция демона -> стихия, к которой он устойчив (x0.6).
const RESIST := {
	Type.GHOST: Type.PHYSICAL,
	Type.EARTH: Type.PHYSICAL,
	Type.UNDEAD: Type.WATER,
}

static func damage_multiplier(attack: int, defender: int) -> float:
	if WEAKNESS.get(defender, -1) == attack:
		return 1.5
	if RESIST.get(defender, -1) == attack:
		return 0.6
	if attack == defender:
		return 0.5
	return 1.0
