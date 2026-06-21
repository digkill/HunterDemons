class_name LevelData
## Уровни: окружение, волны демонов и сюжетные реплики.

const LEVELS := [
	{
		"name": "Неоновый квартал",
		"style": "city",
		"music": "music_city",
		"ground_color": Color(0.12, 0.11, 0.16),
		"sky_top": Color(0.04, 0.02, 0.1),
		"sky_horizon": Color(0.45, 0.1, 0.35),
		"fog_color": Color(0.28, 0.08, 0.24),
		"waves": [
			[{"element": Elements.Type.FIRE, "count": 4}],
			[{"element": Elements.Type.FIRE, "count": 4}, {"element": Elements.Type.UNDEAD, "count": 3}],
			[{"element": Elements.Type.FIRE, "count": 6}, {"element": Elements.Type.UNDEAD, "count": 5}],
		],
		"intro": [
			{"name": "Юкка", "text": "Нео-Токио спит, а демоны — нет. Третью ночь подряд "
				+ "разлом плюётся нечистью прямо в мой квартал."},
			{"name": "Юкка", "text": "Кибер-Сакура заряжена. Тэцурю, не отставай."},
			{"name": "Тэцурю", "text": "Я — дух дракона, девочка. Это ты не отставай."},
		],
		"outro": [
			{"name": "Юкка", "text": "Квартал чист. Но печать на разломе слабее, чем я думала…"},
			{"name": "Тэцурю", "text": "След скверны ведёт за город. В бамбуковую рощу."},
		],
	},
	{
		"name": "Бамбуковая роща",
		"style": "forest",
		"music": "music_forest",
		"ground_color": Color(0.1, 0.16, 0.09),
		"sky_top": Color(0.03, 0.07, 0.06),
		"sky_horizon": Color(0.3, 0.5, 0.35),
		"fog_color": Color(0.15, 0.3, 0.2),
		"waves": [
			[{"element": Elements.Type.EARTH, "count": 3}, {"element": Elements.Type.AIR, "count": 3}],
			[{"element": Elements.Type.AIR, "count": 5}, {"element": Elements.Type.UNDEAD, "count": 3}],
			[
				{"element": Elements.Type.EARTH, "count": 4},
				{"element": Elements.Type.AIR, "count": 4},
				{"element": Elements.Type.UNDEAD, "count": 4},
			],
		],
		"intro": [
			{"name": "Юкка", "text": "Раньше здесь молились духам рощи. Теперь — "
				+ "только пыль, вой ветра и шёпот под корнями."},
			{"name": "Тэцурю", "text": "Демоны земли и воздуха. Големов рви "
				+ "рывком, вихрекрылов не подпускай со спины."},
		],
		"outro": [
			{"name": "Юкка", "text": "Роща снова дышит. Но вода в реке черна, как смола."},
			{"name": "Тэцурю", "text": "Источник скверны — затопленный храм вниз "
				+ "по течению. Там ждут утопленники и призраки."},
		],
	},
	{
		"name": "Затопленный храм",
		"style": "temple",
		"music": "music_temple",
		"ground_color": Color(0.07, 0.12, 0.16),
		"sky_top": Color(0.02, 0.04, 0.09),
		"sky_horizon": Color(0.15, 0.35, 0.45),
		"fog_color": Color(0.1, 0.25, 0.32),
		"waves": [
			[{"element": Elements.Type.WATER, "count": 4}, {"element": Elements.Type.GHOST, "count": 3}],
			[{"element": Elements.Type.GHOST, "count": 5}, {"element": Elements.Type.WATER, "count": 4}],
			[
				{"element": Elements.Type.GHOST, "count": 7},
				{"element": Elements.Type.WATER, "count": 5},
				{"element": Elements.Type.UNDEAD, "count": 4},
			],
		],
		"intro": [
			{"name": "Юкка", "text": "Холодно. Вода здесь помнит всех, кто в ней остался."},
			{"name": "Тэцурю", "text": "Призраки не боятся стали — руби их вихрем "
				+ "сакуры. И береги заряд: сталь дракона им не по зубам."},
		],
		"outro": [
			{"name": "Юкка", "text": "Разлом закрыт. Пока закрыт."},
			{"name": "Тэцурю", "text": "Чувствуешь? За морем просыпаются другие "
				+ "города… Отдыхай, охотница. Продолжение следует."},
		],
	},
]
