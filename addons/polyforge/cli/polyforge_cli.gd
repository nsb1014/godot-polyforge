extends SceneTree
## PolyForge command-line front door.
##
## Build:
##   godot --path . --script res://addons/polyforge/cli/polyforge_cli.gd -- \
##     build res://models/robot.gd --out res://dist --mode both
## Inspect:
##   godot --path . --script res://addons/polyforge/cli/polyforge_cli.gd -- \
##     inspect res://dist/robot.glb

const AssetRecipe := preload("res://addons/polyforge/core/asset_recipe.gd")
const BuildPipeline := preload("res://addons/polyforge/build/build_pipeline.gd")
const GLTFExport := preload("res://addons/polyforge/exporters/gltf_export.gd")

func _initialize() -> void:
	call_deferred("_run")

func _usage() -> void:
	print("PolyForge — Godot-native procedural asset compiler")
	print("  build <recipe.gd> [--out DIR] [--mode preserve|merge|both]")
	print("                    [--viewer-template FILE]")
	print("                    [--no-glb] [--no-viewer] [--no-preview] [--force]")
	print("  inspect <asset.glb>")

func _parse_build(args: PackedStringArray) -> Dictionary:
	var parsed := {"recipe": "", "options": BuildPipeline.default_options()}
	var i := 0
	while i < args.size():
		var arg := args[i]
		match arg:
			"--out":
				i += 1
				assert(i < args.size(), "--out needs a directory")
				parsed.options.out_dir = args[i]
			"--mode":
				i += 1
				assert(i < args.size(), "--mode needs preserve, merge, or both")
				parsed.options.mode = args[i]
			"--viewer-template":
				i += 1
				assert(i < args.size(), "--viewer-template needs an HTML file")
				parsed.options.viewer_template = args[i]
			"--no-glb":
				parsed.options.write_glb = false
			"--no-viewer":
				parsed.options.write_viewer = false
			"--no-preview":
				parsed.options.write_preview = false
			"--force":
				parsed.options.force = true
			_:
				if arg.begins_with("--"):
					assert(false, "unknown PolyForge option: " + arg)
				elif parsed.recipe == "":
					parsed.recipe = arg
				else:
					assert(false, "unexpected argument: " + arg)
		i += 1
	assert(parsed.recipe != "", "build needs a recipe .gd path")
	return parsed

func _print_build_result(result: Dictionary) -> void:
	for warning in result.validation.warnings:
		printerr("WARN: " + warning)
	for failure in result.validation.failures:
		printerr("FAIL: " + failure)
	for label in result.outputs:
		print("%s: %s" % [label, result.outputs[label]])
	if not result.inspection.is_empty():
		print("round_trip: " + JSON.stringify(result.inspection))
	print("polyforge: %s" % ("ok" if result.ok else "failed"))

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty() or args[0] in ["help", "--help", "-h"]:
		_usage()
		quit(0 if not args.is_empty() else 2)
		return
	match args[0]:
		"build":
			var parsed := _parse_build(args.slice(1))
			var spec := AssetRecipe.load_file(parsed.recipe)
			var result := await BuildPipeline.run(self, spec, parsed.options)
			_print_build_result(result)
			quit(0 if result.ok else 1)
		"inspect":
			if args.size() != 2:
				_usage()
				quit(2)
				return
			var report := GLTFExport.inspect(args[1])
			print(JSON.stringify(report, "  "))
			quit(0 if report.ok else 1)
		_:
			_usage()
			quit(2)
