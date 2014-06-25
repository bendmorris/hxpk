package hxpk;

import haxe.Json;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;

using Lambda;
using StringTools;


class TexturePackerFileProcessor extends FileProcessor {
	static var digitSuffix:EReg = ~/(.*?)(\\d+)$/;

	var defaultSettings:Settings;
	var dirToSettings:Map<String, Settings> = new Map();
	var json:Dynamic;
	var packFileName:String;
	var root:String;
	var ignoreDirs:Array<String> = new Array();

	public function new (defaultSettings:Settings = null, packFileName:String = "pack.atlas") {
		if (defaultSettings == null) defaultSettings = new Settings();

		this.defaultSettings = defaultSettings;

		if (packFileName.indexOf('.') == -1 || packFileName.toLowerCase().endsWith(".png")
			|| packFileName.toLowerCase().endsWith(".jpg")) {
			packFileName += ".atlas";
		}
		this.packFileName = packFileName;

		setFlattenOutput(true);
		addInputSuffix([".png", ".jpg"]);
	}

	public function processString (inputFile:String, outputRoot:String):Array<Entry> {
		root = FileSystem.fullPath(inputFile);

		// Collect pack.json setting files.
		var settingsFiles:Array<String> = new Array();
		var settingsProcessor:FileProcessor = new FileProcessor();
		settingsProcessor.processFile = function (inputFile:Entry) {
			settingsFiles.push(inputFile.inputFile);
		};
		//settingsProcessor.processDir = processDir;
		settingsProcessor.addInputRegex(["pack\\.json"]);
		settingsProcessor.process(inputFile, null);
		// Sort parent first.
		settingsFiles.sort(function (file1:String, file2:String) { 
			return file1.length - file2.length;
		});
		for (settingsFile in settingsFiles) {
			// Find first parent with settings, or use defaults.
			var settings:Settings = null;
			var parent:String = Utils.getParentFile(settingsFile);
			while (true) {
				if (parent == root || parent == '') break;
				parent = Utils.getParentFile(parent);
				settings = dirToSettings.get(parent);
				if (settings != null) {
					settings = Settings.clone(settings);
					break;
				}
			}
			if (settings == null) settings = Settings.clone(defaultSettings);
			// Merge settings from current directory.
			merge(settings, settingsFile);
			dirToSettings.set(Utils.getParentFile(settingsFile), settings);
		}

		// Do actual processing.
		return super.process(inputFile, outputRoot);
	}

	private function merge (settings:Settings, settingsFile:String):Void {
		//try {
			// TODO
			var settingsContent:String = File.getContent(settingsFile);
			var data = Json.parse(settingsContent);
			for (field in Reflect.fields(data)) {
				Reflect.setField(settings, field, Reflect.field(data, field));
			}
		//} catch (e:Dynamic) {
		//	throw "Error reading settings file " + settingsFile + ": " + e;
		//}
	}

	override public function process (file:Dynamic, outputRoot:String):Array<Entry> {
		if (Std.is(file, String)) {
			return processString(file, outputRoot);
		}
		
		var files:Array<String> = cast file;
		
		// Delete pack file and images.
		if (FileSystem.exists(outputRoot)) {
			// Load root settings to get scale.
			var settingsFile:String = Path.join([root, "pack.json"]);
			var rootSettings:Settings = defaultSettings;
			if (FileSystem.exists(settingsFile)) {
				rootSettings = Settings.clone(rootSettings);
				merge(rootSettings, settingsFile);
			}

			for (i in 0 ... rootSettings.scale.length) {
				var deleteProcessor:FileProcessor = new FileProcessor();
				deleteProcessor.processFile = function (inputFile:Entry) {
					FileSystem.deleteFile(inputFile.inputFile);
				};
				deleteProcessor.setRecursive(false);

				var packFile:String = rootSettings.scaledPackFileName(packFileName, i);

				var prefix:String = Path.withoutExtension(Path.withoutDirectory(packFile));
				deleteProcessor.addInputRegex(["(?i)" + prefix + "\\d*\\.(png|jpg)"]);
				deleteProcessor.addInputRegex(["(?i)" + prefix + "\\.atlas"]);

				var dir:String = Utils.getParentFile(packFile);
				if (dir == null)
					deleteProcessor.process(outputRoot, null);
				else if (FileSystem.exists(Path.join([outputRoot, dir]))) //
					deleteProcessor.process(outputRoot + "/" + dir, null);
			}
		}
		return super.process(files, outputRoot);
	}

	override public function processDir (inputDir:Entry, files:Array<Entry>):Void {
		if (ignoreDirs.has(inputDir.inputFile)) return;

		// Find first parent with settings, or use defaults.
		var settings:Settings = null;
		var parent:String = inputDir.inputFile;
		while (parent != "") {
			settings = dirToSettings.get(parent);
			if (settings != null) break;
			if (parent == root) break;
			parent = Utils.getParentFile(parent);
		}
		if (settings == null) settings = defaultSettings;

		if (settings.combineSubdirectories) {
			// Collect all files under subdirectories and ignore subdirectories so they won't be packed twice.
			var processor:FileProcessor = FileProcessor.clone(this);
			processor.processDir = function (entryDir:Entry, files:Array<Entry>) {
				ignoreDirs.push(entryDir.inputFile);
			};

			processor.processFile = function (entry:Entry) {
				addProcessedFile(entry);
			};
			
			files = processor.process(inputDir.inputFile, null);
		}

		if (files.length == 0) return;

		// Sort by name using numeric suffix, then alpha.
		files.sort(function (entry1:Entry, entry2:Entry) {
			var full1:String = Path.withoutExtension(Path.withoutDirectory(entry1.inputFile));

			var full2:String = Path.withoutExtension(Path.withoutDirectory(entry2.inputFile));

			var name1:String = full1, name2:String = full2;
			var num1:Int = 0, num2:Int = 0;

			if (digitSuffix.match(full1)) {
				try {
					num1 = Std.parseInt(digitSuffix.matched(2));
					name1 = digitSuffix.matched(1);
				} catch (_:Dynamic) {
				}
			}
			if (digitSuffix.match(full2)) {
				try {
					num2 = Std.parseInt(digitSuffix.matched(2));
					name2 = digitSuffix.matched(1);
				} catch (_:Dynamic) {
				}
			}
			var compare:Int = Utils.stringCompare(name1, name2);
			if (compare != 0 || num1 == num2) return compare;
			return num1 - num2;
		});

		// Pack.
		Utils.print(inputDir.inputFile);
		var packer:TexturePacker = new TexturePacker(root, settings);
		for (file in files)
			packer.addImageFile(file.inputFile);
		packer.pack(inputDir.outputDir, packFileName);
	}
}
