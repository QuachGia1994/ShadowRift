extends RefCounted
class_name StageCatalog

const STAGES := [
	{
		"name": "RIFT APPROACH",
		"width": 2400.0,
		"spawn": Vector2(180.0, 406.0),
		"platforms": [
			[Vector2(640.0, 350.0), Vector2(224.0, 18.0)],
			[Vector2(1100.0, 292.0), Vector2(192.0, 18.0)],
			[Vector2(1640.0, 342.0), Vector2(224.0, 18.0)],
		],
		"hazards": [Vector2(900.0, 419.0), Vector2(1490.0, 419.0)],
		"enemies": [
			{"kind": "warden", "position": Vector2(720.0, 412.0)},
			{"kind": "wraith", "position": Vector2(1260.0, 400.0)},
			{"kind": "warden", "position": Vector2(1780.0, 412.0)},
		],
		"boss": false,
	},
	{
		"name": "BROKEN KEEP",
		"width": 2400.0,
		"spawn": Vector2(180.0, 406.0),
		"platforms": [
			[Vector2(520.0, 360.0), Vector2(192.0, 18.0)],
			[Vector2(900.0, 300.0), Vector2(192.0, 18.0)],
			[Vector2(1320.0, 348.0), Vector2(224.0, 18.0)],
			[Vector2(1750.0, 286.0), Vector2(192.0, 18.0)],
		],
		"hazards": [Vector2(710.0, 419.0), Vector2(1140.0, 419.0), Vector2(1570.0, 419.0)],
		"enemies": [
			{"kind": "wraith", "position": Vector2(610.0, 400.0)},
			{"kind": "warden", "position": Vector2(1030.0, 412.0)},
			{"kind": "wraith", "position": Vector2(1460.0, 400.0)},
			{"kind": "warden", "position": Vector2(1880.0, 412.0)},
		],
		"boss": false,
	},
	{
		"name": "RIFT THRONE",
		"width": 2400.0,
		"spawn": Vector2(180.0, 406.0),
		"platforms": [
			[Vector2(690.0, 348.0), Vector2(224.0, 18.0)],
			[Vector2(1240.0, 300.0), Vector2(192.0, 18.0)],
		],
		"hazards": [Vector2(940.0, 419.0), Vector2(1490.0, 419.0)],
		"enemies": [
			{"kind": "warden", "position": Vector2(700.0, 412.0)},
			{"kind": "wraith", "position": Vector2(1280.0, 400.0)},
		],
		"boss": true,
		"boss_position": Vector2(1900.0, 398.0),
	},
]

static func count() -> int:
	return STAGES.size()

static func get_stage(index: int) -> Dictionary:
	return STAGES[clampi(index, 0, STAGES.size() - 1)].duplicate(true)
