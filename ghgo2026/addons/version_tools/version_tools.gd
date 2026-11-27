@tool
extends EditorPlugin

const VERSION := "application/config/version"
const PLAYTEST_BUILD := "application/config/playtest_build"
const ITEMS: Array[String] = [
	"Version: New Playtest Build",
	"Version: Bump Patch",
	"Version: Bump Minor",
	"Version: Bump Major",
]

func _enter_tree() -> void:
	add_tool_menu_item(ITEMS[0], _bump_playtest)
	add_tool_menu_item(ITEMS[1], _bump.bind(2))
	add_tool_menu_item(ITEMS[2], _bump.bind(1))
	add_tool_menu_item(ITEMS[3], _bump.bind(0))
	if not ProjectSettings.has_setting(PLAYTEST_BUILD):
		ProjectSettings.set_setting(PLAYTEST_BUILD, 1)
		ProjectSettings.save()

func _exit_tree() -> void:
	for item in ITEMS:
		remove_tool_menu_item(item)

func _bump(part: int) -> void:
	var numbers := str(ProjectSettings.get_setting(VERSION, "0.0.0")).split(".")
	while numbers.size() < 3:
		numbers.append("0")
	var values := [int(numbers[0]), int(numbers[1]), int(numbers[2])]
	values[part] += 1
	for i in range(part + 1, 3):
		values[i] = 0
	var version := "%d.%d.%d" % values
	ProjectSettings.set_setting(VERSION, version)
	ProjectSettings.set_setting(PLAYTEST_BUILD, 1)
	ProjectSettings.save()
	print("Version is now %s (playtest build 1)" % version)

func _bump_playtest() -> void:
	var build := int(ProjectSettings.get_setting(PLAYTEST_BUILD, 0)) + 1
	ProjectSettings.set_setting(PLAYTEST_BUILD, build)
	ProjectSettings.save()
	print("Playtest build is now %d" % build)
