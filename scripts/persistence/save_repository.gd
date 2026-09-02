extends RefCounted
class_name SaveRepository

const SCHEMA_VERSION := 2
const CHECKSUM_SALT := "shadow-rift-v1-integrity"

var save_path := "user://shadow_rift_save.json"

func save_game(payload: Dictionary) -> Dictionary:
    var validation := validate_payload(payload)
    if not validation.ok:
        return validation
    var wrapper := {"schema": SCHEMA_VERSION, "payload": payload, "checksum": checksum_for(payload)}
    var file := FileAccess.open(save_path, FileAccess.WRITE)
    if file == null:
        return {"ok": false, "error": "save_open_failed"}
    file.store_string(JSON.stringify(wrapper))
    file.close()
    return {"ok": true}

func load_game() -> Dictionary:
    if not FileAccess.file_exists(save_path):
        return {"ok": false, "error": "save_missing"}
    var file := FileAccess.open(save_path, FileAccess.READ)
    if file == null:
        return {"ok": false, "error": "save_open_failed"}
    var raw := file.get_as_text()
    file.close()
    var parsed: Variant = JSON.parse_string(raw)
    if not parsed is Dictionary:
        return {"ok": false, "error": "save_invalid_json"}
    var wrapper := parsed as Dictionary
    var schema := int(wrapper.get("schema", -1))
    if schema != SCHEMA_VERSION and schema != 1:
        return {"ok": false, "error": "save_schema_mismatch"}
    var payload := wrapper.payload as Dictionary
    var original_payload := payload.duplicate(true)
    if schema == 1:
        payload = _migrate_v1_to_v2(payload)
    var validation := validate_payload(payload)
    if not validation.ok:
        return validation
    if schema == SCHEMA_VERSION:
        if str(wrapper.get("checksum", "")) != checksum_for(payload):
            return {"ok": false, "error": "save_checksum_mismatch"}
    else:
        if str(wrapper.get("checksum", "")) != _checksum_v1(original_payload):
            return {"ok": false, "error": "save_checksum_mismatch"}
    return {"ok": true, "payload": payload}

func checksum_for(payload: Dictionary) -> String:
    var context := HashingContext.new()
    context.start(HashingContext.HASH_SHA256)
    context.update((_canonical_payload(payload) + CHECKSUM_SALT).to_utf8_buffer())
    return context.finish().hex_encode()

func _checksum_v1(payload: Dictionary) -> String:
    var ctx := HashingContext.new()
    ctx.start(HashingContext.HASH_SHA256)
    ctx.update((_canonical_payload_legacy(payload) + CHECKSUM_SALT).to_utf8_buffer())
    return ctx.finish().hex_encode()

func validate_payload(payload: Dictionary) -> Dictionary:
    var required := ["level", "experience", "experience_to_next", "gold", "mana", "health", "equipment"]
    for key in required:
        if not payload.has(key):
            return {"ok": false, "error": "save_missing_field"}
    if not payload.equipment is Dictionary:
        return {"ok": false, "error": "save_invalid_equipment"}
    var level := int(payload.level)
    var experience := int(payload.experience)
    var experience_to_next := int(payload.experience_to_next)
    var gold := int(payload.gold)
    var mana := int(payload.mana)
    var health := int(payload.health)
    if level < 1 or level > 99 or experience < 0 or experience_to_next < 1 or experience >= experience_to_next:
        return {"ok": false, "error": "save_progress_out_of_range"}
    if gold < 0 or gold > 9999999 or mana < 0 or mana > 1000 or health < 0 or health > 10000:
        return {"ok": false, "error": "save_resources_out_of_range"}
    var weapon := StringName(str(payload.equipment.get("weapon", "")))
    var armor := StringName(str(payload.equipment.get("armor", "")))
    if ItemCatalog.get_item(&"weapon", weapon).is_empty() or ItemCatalog.get_item(&"armor", armor).is_empty():
        return {"ok": false, "error": "save_unknown_item"}
    var profile := PlayerProfile.new()
    profile.set_level(level)
    if not profile.restore_equipment(payload.equipment):
        return {"ok": false, "error": "save_invalid_equipment"}
    var stats := profile.get_canonical_stats()
    if mana > int(stats.max_mana) or health > int(stats.max_health):
        return {"ok": false, "error": "save_resources_exceed_stats"}
    if payload.has("stage_index"):
        var si := int(payload.stage_index)
        if si < 0 or si > 10:
            return {"ok": false, "error": "save_stage_out_of_range"}
    if payload.has("has_checkpoint") and payload.has("checkpoint"):
        var cp = payload.checkpoint
        if not (cp is Vector2 or cp is Dictionary):
            return {"ok": false, "error": "save_checkpoint_invalid"}
    return {"ok": true}

func _migrate_v1_to_v2(payload: Dictionary) -> Dictionary:
    var migrated := payload.duplicate(true)
    if not migrated.has("stage_index"):
        migrated["stage_index"] = 0
    if not migrated.has("has_checkpoint"):
        migrated["has_checkpoint"] = false
    if not migrated.has("checkpoint"):
        migrated["checkpoint"] = Vector2(180, 406)
    return migrated

func _canonical_payload(payload: Dictionary) -> String:
    var equipment := payload.equipment as Dictionary
    var parts := [int(payload.level), int(payload.experience), int(payload.experience_to_next), int(payload.gold), int(payload.mana), int(payload.health), str(equipment.weapon), str(equipment.armor), int(payload.get("stage_index", 0)), str(bool(payload.get("has_checkpoint", false))), str(payload.get("checkpoint", Vector2.ZERO))]
    return JSON.stringify(parts)

func _canonical_payload_legacy(payload: Dictionary) -> String:
    var equipment := payload.equipment as Dictionary
    return JSON.stringify([int(payload.level), int(payload.experience), int(payload.experience_to_next), int(payload.gold), int(payload.mana), int(payload.health), str(equipment.weapon), str(equipment.armor)])
