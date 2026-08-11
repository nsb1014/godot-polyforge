extends SceneTree
## PolyForge command-line front door.
##
## Build:
##   godot --path . --script res://addons/polyforge/cli/polyforge_cli.gd -- \
##     build res://models/robot.gd --param height=3.2 --out res://dist --mode both
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
	print("                    [--param NAME=NUMBER] [--sweep-param NAME]")
	print("                    [--sweep-mode single|pairwise] [--sweep-limit NUMBER] [--no-sweep]")
	print("                    [--viewer-template FILE]")
	print("                    [--no-glb] [--no-viewer] [--no-preview] [--no-readability]")
	print("                    [--no-sweep-readability] [--force]")
	print("                    [--view-set front|cardinal|octants]")
	print("                    [--sweep-view-set front|cardinal|octants]")
	print("  inspect <asset.glb>")

func _set_parameter(parsed: Dictionary, assignment: String) -> void:
	var separator := assignment.find("=")
	assert(separator > 0 and separator < assignment.length() - 1,
		"--param needs NAME=NUMBER")
	var name := assignment.left(separator)
	var raw_value := assignment.substr(separator + 1)
	assert(raw_value.is_valid_float(), "parameter %s must be numeric" % name)
	parsed.parameters[name] = raw_value.to_float()

func _parse_build(args: PackedStringArray) -> Dictionary:
	var parsed := {"recipe": "", "options": BuildPipeline.default_options(),
		"parameters": {}, "sweep": true, "sweep_parameters": PackedStringArray(),
		"sweep_mode": "pairwise", "sweep_limit": 128}
	var i := 0
	while i < args.size():
		var arg := args[i]
		match arg:
			"--param":
				i += 1
				assert(i < args.size(), "--param needs NAME=NUMBER")
				_set_parameter(parsed, args[i])
			"--sweep-param":
				i += 1
				assert(i < args.size(), "--sweep-param needs a parameter name")
				parsed.sweep_parameters.append(args[i])
			"--no-sweep":
				parsed.sweep = false
			"--sweep-mode":
				i += 1
				assert(i < args.size() and args[i] in ["single", "pairwise"],
					"--sweep-mode needs single or pairwise")
				parsed.sweep_mode = args[i]
			"--sweep-limit":
				i += 1
				assert(i < args.size() and args[i].is_valid_int() and args[i].to_int() > 0,
					"--sweep-limit needs a positive integer")
				parsed.sweep_limit = args[i].to_int()
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
			"--no-readability":
				parsed.options.measure_readability = false
			"--no-sweep-readability":
				parsed.options.measure_sweep_readability = false
			"--view-set":
				i += 1
				assert(i < args.size() and args[i] in ["front", "cardinal", "octants"],
					"--view-set needs front, cardinal, or octants")
				parsed.options.view_set = args[i]
			"--sweep-view-set":
				i += 1
				assert(i < args.size() and args[i] in ["front", "cardinal", "octants"],
					"--sweep-view-set needs front, cardinal, or octants")
				parsed.options.sweep_view_set = args[i]
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
			var spec := AssetRecipe.load_file(parsed.recipe, parsed.parameters)
			if parsed.sweep:
				parsed.options.sweep_specs = AssetRecipe.load_sweep(
					parsed.recipe, parsed.parameters, parsed.sweep_parameters,
					parsed.sweep_mode == "pairwise", parsed.sweep_limit)
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
