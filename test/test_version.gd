extends RefCounted

## The version is one fact stored in three places and no code derives it.
##
## `Changelog.VERSION`, `version/name` in the debug APK preset, and `version/name`
## in the Play AAB preset. Godot will not read a constant out of a script at
## export time, so they are typed by hand and they drift. When they do, the title
## screen says one version and the phone's app info says another, and "did my
## build land" - the question the build stamp exists to answer - gets two
## different answers depending on where you look.
##
## The AAB preset's copy is the dangerous one, because nobody sees it until a
## store upload.


func _presets() -> PackedStringArray:
	var f := FileAccess.open("res://export_presets.cfg", FileAccess.READ)
	if f == null:
		return PackedStringArray()
	var out := PackedStringArray()
	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line.begins_with("version/name="):
			out.append(line.split("=", true, 1)[1].strip_edges().trim_prefix("\"").trim_suffix("\""))
	return out


func test_every_copy_of_the_version_agrees(t: TestHarness) -> void:
	var found := _presets()
	t.gt(float(found.size()), 1.0,
		"fewer than two export presets carry a version/name - the file moved or the key changed")
	for v in found:
		t.eq(v, Changelog.VERSION,
			"an export preset says %s while Changelog.VERSION says %s" % [v, Changelog.VERSION])


func test_the_changelog_leads_with_the_current_version(t: TestHarness) -> void:
	t.gt(float(Changelog.RELEASES.size()), 0.0, "the changelog has at least one release")
	t.eq(Changelog.RELEASES[0]["version"], Changelog.VERSION,
		"the newest changelog entry is not the version being built")
	for r in Changelog.RELEASES:
		t.gt(float(String(r["notes"][0]).length()), 8.0,
			"release %s has a note written in the player's terms" % r["version"])
