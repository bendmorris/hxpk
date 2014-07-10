package hxpk;

import haxe.io.Path;


/** Collects files recursively, filtering by file name. Callbacks are provided to process files and the results are collected,
 * either {@link #processFile(Entry)} or {@link #processDir(Entry, ArrayList)} can be overridden, or both. The entries provided to
 * the callbacks have the original file, the output directory, and the output file. If {@link #setFlattenOutput(boolean)} is
 * false, the output will match the directory structure of the input.
 * @author Nathan Sweet */
class FileProcessor {
	//var inputFilter:FilenameFilter;
	var comparator:Comparator<String> = function (o1:String, o2:String) {
		return Utils.stringCompare(o1, o2);
	};
	var inputRegex:Array<EReg> = new Array();
	var outputSuffix:String;
	var outputFiles:Array<Entry> = new Array();
	var recursive:Bool = true;
	var flattenOutput:Bool = false;

	var entryComparator:Comparator<Entry> = function (o1:Entry, o2:Entry) {
		return Utils.stringCompare(o1.inputFile, o2.inputFile);
	};

	/** Copy constructor. */
	public static function clone (processor:FileProcessor):FileProcessor {
		var newProcessor = Type.createEmptyInstance(FileProcessor);
		//newProcessor.inputFilter = processor.inputFilter;
		newProcessor.comparator = processor.comparator;
		newProcessor.inputRegex.concat(processor.inputRegex);
		newProcessor.outputSuffix = processor.outputSuffix;
		newProcessor.recursive = processor.recursive;
		newProcessor.flattenOutput = processor.flattenOutput;
		return newProcessor;
	}

	/*public function setInputFilter (inputFilter:FilenameFilter):FileProcessor {
		this.inputFilter = inputFilter;
		return this;
	}*/

	/** Sets the comparator for {@link #processDir(Entry, ArrayList)}. By default the files are sorted by alpha. */
	public function setComparator (comparator:Comparator<String>):FileProcessor {
		this.comparator = comparator;
		return this;
	}

	/** Adds a case insensitive suffix for matching input files. */
	public function addInputSuffix (suffixes:Array<String>):FileProcessor {
		for (suffix in suffixes)
			// TODO
			// addInputRegex(["(?i).*" + Pattern.quote(suffix)]);
			addInputRegex(["(?i).*" + suffix]);
		return this;
	}

	public function addInputRegex (regexes:Array<String>) {
		for (regex in regexes)
			inputRegex.push(new EReg(regex, ''));
		return this;
	}

	/** Sets the suffix for output files, replacing the extension of the input file. */
	public function setOutputSuffix (outputSuffix:String):FileProcessor {
		this.outputSuffix = outputSuffix;
		return this;
	}

	public function setFlattenOutput (flattenOutput:Bool):FileProcessor {
		this.flattenOutput = flattenOutput;
		return this;
	}

	/** Default is true. */
	public function setRecursive (recursive:Bool):FileProcessor {
		this.recursive = recursive;
		return this;
	}

	/** Processes the specified input files.
	 * @param outputRoot May be null if there is no output from processing the files.
	 * @return the processed files added with {@link #addProcessedFile(Entry)}. */
	public function process (file:Dynamic, outputRoot:String):Array<Entry> {
		var files:Array<String>;
		if (Std.is(file, String)) {
			var inputFile:String = cast(file, String);
			if (!Settings.environment.exists(inputFile)) throw "Input file does not exist: " + inputFile;
			if (Settings.environment.isDirectory(inputFile)) {
				files = [for (f in Settings.environment.readDirectory(inputFile))
					Path.join([Settings.environment.fullPath(inputFile), f])];
			} else
				files = [inputFile];
		} else {
			files = cast file;
		}

		if (outputRoot == null) outputRoot = "";
		outputFiles.splice(0, outputFiles.length);

		var dirToEntries:Map<String, Array<Entry>> = new Map();
		_process(files, outputRoot, outputRoot, dirToEntries, 0);

		var allEntries:Array<Entry> = new Array();
		for (inputDir in dirToEntries.keys()) {
			var mapEntry:Array<Entry> = dirToEntries[inputDir];

			var dirEntries:Array<Entry> = mapEntry;
			if (comparator != null) dirEntries.sort(entryComparator);

			var newOutputDir:String = null;
			if (flattenOutput)
				newOutputDir = outputRoot;
			else if (dirEntries.length > 0)
				newOutputDir = dirEntries[0].outputDir;
			var outputName:String = Path.withoutDirectory(inputDir);
			if (outputSuffix != null) outputName = ~/(.*)\\..*/g.replace(outputName, "$1") + outputSuffix;

			var entry:Entry = new Entry();
			entry.inputFile = inputDir;
			entry.outputDir = newOutputDir;
			if (newOutputDir != null)
				entry.outputFile = newOutputDir.length == 0 ? outputName : Path.join([newOutputDir, outputName]);

			try {
				processDir(entry, dirEntries);
			} catch (e:Dynamic) {
				throw "Error processing directory " + entry.inputFile + ": " + e;
			}
			allEntries = allEntries.concat(dirEntries);
		}

		if (comparator != null) allEntries.sort(entryComparator);
		for (entry in allEntries) {
			try {
				processFile(entry);
			} catch (e:Dynamic) {
				throw "Error processing file " + entry.inputFile + ": " + e;
			}
		}

		return outputFiles;
	}

	function _process (files:Array<String>, outputRoot:String, outputDir:String, dirToEntries:Map<String, Array<Entry>>, depth:Int) {
		// Store empty entries for every directory.
		for (file in files) {
			var dir:String = Path.directory(file);
			var entries:Array<Entry> = dirToEntries.get(dir);
			if (entries == null) {
				entries = new Array();
				dirToEntries.set(dir, entries);
			}
		}

		for (file in files) {
			if (!Settings.environment.isDirectory(file)) {
				var found:Bool = false;
				for (pattern in inputRegex) {
					if (pattern.match(Path.withoutDirectory(file))) {
						found = true;
						break;
					}
				}
				if (!found) continue;

				var dir:String = Path.directory(file);
				//if (inputFilter != null && !inputFilter.accept(dir, Path.withoutDirectory(file))) continue;

				var outputName:String = Path.withoutDirectory(file);
				if (outputSuffix != null) outputName = ~/(.*)\\..*/g.replace(outputName, "$1") + outputSuffix;

				var entry:Entry = new Entry();
				entry.depth = depth;
				entry.inputFile = file;
				entry.outputDir = outputDir;

				if (flattenOutput) {
					entry.outputFile = Path.join([outputRoot, outputName]);
				} else {
					entry.outputFile = Path.join([outputDir, outputName]);
				}

				dirToEntries.get(dir).push(entry);
			}
			if (recursive && Settings.environment.isDirectory(file)) {
				var subdir:String = Settings.environment.fullPath(outputDir).length == 0 ? Path.withoutDirectory(file) : Path.join([outputDir, Path.withoutDirectory(file)]);
				var files:Array<String> = [for (f in Settings.environment.readDirectory(file)) Path.join([file, f])];
				_process(files, outputRoot, subdir, dirToEntries, depth + 1);
			}
		}
	}

	/** Called with each input file. */
	public dynamic function processFile (entry:Entry):Void {};

	/** Called for each input directory. The files will be {@link #setComparator(Comparator) sorted}. */
	public dynamic function processDir (entryDir:Entry, files:Array<Entry>):Void {}

	/** This method should be called by {@link #processFile(Entry)} or {@link #processDir(Entry, ArrayList)} if the return value of
	 * {@link #process(File, File)} or {@link #process(File[], File)} should return all the processed files. */
	public function addProcessedFile (entry:Entry):Void {
		outputFiles.push(entry);
	}

}
