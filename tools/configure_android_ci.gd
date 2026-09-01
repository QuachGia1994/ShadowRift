@tool
extends SceneTree

func _initialize() -> void:
	var android_home := OS.get_environment("ANDROID_SDK_ROOT")
	var java_home := OS.get_environment("JAVA_HOME")
	if android_home.is_empty() or java_home.is_empty():
		push_error("ANDROID_SDK_ROOT and JAVA_HOME are required")
		quit(1)
		return
	var settings := EditorInterface.get_editor_settings()
	settings.set_setting("export/android/android_sdk_path", android_home)
	settings.set_setting("export/android/java_sdk_path", java_home)
	settings.save()
	print("Configured Android export paths from the CI environment")
	quit()
