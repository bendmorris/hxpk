package hxpk;

import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
import sys.io.FileOutput;
import flash.display.BitmapData;
import flash.geom.Point;
import flash.geom.Rectangle;


class TexturePacker {
	private var settings:Settings;
	private var packer:Packer;
	private var imageProcessor:ImageProcessor;
	private var inputImages:Array<InputImage> = new Array();
	private var rootDir:String;

	/** @param rootDir Used to strip the root directory prefix from image file names, can be null. */
	public function new (rootDir:String, settings:Settings) {
		this.rootDir = rootDir;
		this.settings = settings;

		if (settings.pot) {
			if (settings.maxWidth != Utils.nextPowerOfTwo(settings.maxWidth))
				throw "If pot is true, maxWidth must be a power of two: " + settings.maxWidth;
			if (settings.maxHeight != Utils.nextPowerOfTwo(settings.maxHeight))
				throw "If pot is true, maxHeight must be a power of two: " + settings.maxHeight;
		}

		// TODO
		//if (settings.grid)
			packer = new GridPacker(settings);
		//else
			//packer = new MaxRectsPacker(settings);
		imageProcessor = new ImageProcessor(rootDir, settings);
	}

	public function addImageFile (file:String):Void {
		var inputImage:InputImage = new InputImage();
		inputImage.file = file;
		inputImages.push(inputImage);
	}

	public function addImageBitmapData (image:BitmapData, name:String):Void {
		var inputImage:InputImage = new InputImage();
		inputImage.image = image;
		inputImage.name = name;
		inputImages.push(inputImage);
	}

	public function pack (outputDir:String, packFileName:String):Void {
		FileSystem.createDirectory(outputDir);

		for (i in 0 ... settings.scale.length) {
			imageProcessor.setScale(settings.scale[i]);
			for (inputImage in inputImages) {
				if (inputImage.file != null)
					imageProcessor.addImageFile(inputImage.file);
				else
					imageProcessor.addImageBitmapData(inputImage.image, inputImage.name);
			}

			var pages:Array<Page> = packer.pack(imageProcessor.getImages());

			var scaledPackFileName:String = settings.scaledPackFileName(packFileName, i);
			var packFile:String = Path.join([outputDir, scaledPackFileName]);
			var packDir:String = outputDir;
			FileSystem.createDirectory(packDir);

			trace('writing images');
			writeImages(packFile, pages);
			try {
				trace('writing packfile');
				writePackFile(packFile, pages);
			} catch (e:Dynamic) {
				throw "Error writing pack file: " + e;
			}
			trace('done');
			imageProcessor.clear();
		}
	}

	private function writeImages (packFile:String, pages:Array<Page>):Void {
		var packDir:String = Path.directory(packFile);
		var imageName:String = Path.withoutDirectory(packFile);
		var dotIndex:Int = imageName.indexOf('.');
		if (dotIndex != -1) imageName = imageName.substr(0, dotIndex);

		var fileIndex:Int = 0;
		for (page in pages) {
			var width:Int = page.width, height:Int = page.height;
			var paddingX:Int = settings.paddingX;
			var paddingY:Int = settings.paddingY;
			if (settings.duplicatePadding) {
				paddingX = Std.int(paddingX / 2);
				paddingY = Std.int(paddingY / 2);
			}
			width -= settings.paddingX;
			height -= settings.paddingY;
			if (settings.edgePadding) {
				page.x = paddingX;
				page.y = paddingY;
				width += paddingX * 2;
				height += paddingY * 2;
			}
			if (settings.pot) {
				width = Utils.nextPowerOfTwo(width);
				height = Utils.nextPowerOfTwo(height);
			}
			width = Std.int(Math.max(settings.minWidth, width));
			height = Std.int(Math.max(settings.minHeight, height));

			var outputFile:String;
			while (true) {
				outputFile = Path.join([packDir, imageName + (fileIndex++ == 0 ? "" : ("" + fileIndex)) + "." + settings.outputFormat]);
				if (!FileSystem.exists(outputFile)) break;
			}
			FileSystem.createDirectory(packDir);
			page.imageName = Path.withoutDirectory(outputFile);

			var canvas:BitmapData = new BitmapData(width, height, true, 0);

			trace("Writing " + width + "x" + height + ": " + outputFile);

			for (rect in page.outputRects) {
				var image:BitmapData = rect.getImage(imageProcessor);
				var iw:Int = image.width;
				var ih:Int = image.height;
				var rectX:Int = page.x + rect.x, rectY:Int = page.y + page.height - rect.y - rect.height;
				if (settings.duplicatePadding) {
					var amountX:Int = Std.int(settings.paddingX / 2);
					var amountY:Int = Std.int(settings.paddingY / 2);
					if (rect.rotated) {
						// Copy corner pixels to fill corners of the padding.
						for (i in 1 ... amountX+1) {
							for (j in 1 ... amountY+1) {
								plot(canvas, rectX - j, rectY + iw - 1 + i, image.getPixel32(0, 0));
								plot(canvas, rectX + ih - 1 + j, rectY + iw - 1 + i, image.getPixel32(0, ih - 1));
								plot(canvas, rectX - j, rectY - i, image.getPixel32(iw - 1, 0));
								plot(canvas, rectX + ih - 1 + j, rectY - i, image.getPixel32(iw - 1, ih - 1));
							}
						}
						// Copy edge pixels into padding.
						for (i in 1 ... amountY+1) {
							for (j in 0 ... iw) {
								plot(canvas, rectX - i, rectY + iw - 1 - j, image.getPixel32(j, 0));
								plot(canvas, rectX + ih - 1 + i, rectY + iw - 1 - j, image.getPixel32(j, ih - 1));
							}
						}
						for (i in 1 ... amountX+1) {
							for (j in 0 ... ih) {
								plot(canvas, rectX + j, rectY - i, image.getPixel32(iw - 1, j));
								plot(canvas, rectX + j, rectY + iw - 1 + i, image.getPixel32(0, j));
							}
						}
					} else {
						// Copy corner pixels to fill corners of the padding.
						for (i  in 1 ... amountX+1) {
							for (j in 1 ... amountY+1) {
								plot(canvas, rectX - i, rectY - j, image.getPixel32(0, 0));
								plot(canvas, rectX - i, rectY + ih - 1 + j, image.getPixel32(0, ih - 1));
								plot(canvas, rectX + iw - 1 + i, rectY - j, image.getPixel32(iw - 1, 0));
								plot(canvas, rectX + iw - 1 + i, rectY + ih - 1 + j, image.getPixel32(iw - 1, ih - 1));
							}
						}
						// Copy edge pixels into padding.
						for (i in 1 ... amountY+1) {
							copy(image, 0, 0, iw, 1, canvas, rectX, rectY - i, rect.rotated);
							copy(image, 0, ih - 1, iw, 1, canvas, rectX, rectY + ih - 1 + i, rect.rotated);
						}
						for (i in 1 ... amountX+1) {
							copy(image, 0, 0, 1, ih, canvas, rectX - i, rectY, rect.rotated);
							copy(image, iw - 1, 0, 1, ih, canvas, rectX + iw - 1 + i, rectY, rect.rotated);
						}
					}
				}
				copy(image, 0, 0, iw, ih, canvas, rectX, rectY, rect.rotated);
				if (settings.debug) {
					canvas.fillRect(new Rectangle(rectX, rectY, rect.width - settings.paddingX - 1, rect.height - settings.paddingY - 1), Color.magenta);
				}
			}

			if (settings.bleed && !settings.premultiplyAlpha && !(settings.outputFormat.toLowerCase() == "jpg")) {
				canvas = new ColorBleedEffect().processImage(canvas, 2);
			}

			if (settings.debug) {
				canvas.fillRect(new Rectangle(0, 0, width - 1, height - 1), Color.magenta);
			}

			var error:String = null;
			try {
				var newImage:BitmapData = new BitmapData(canvas.width, canvas.height, true, 0);
				newImage.copyPixels(canvas, canvas.rect, new Point());
				canvas = newImage;
				var imageData = canvas.encode(settings.outputFormat, settings.outputFormat.toLowerCase() == "jpg" ? settings.jpegQuality : 1);
				var fo:FileOutput = sys.io.File.write(outputFile, true);
				fo.writeString(imageData.toString());
			} catch (e:Dynamic) {
				error = "Error writing file " + outputFile + ": " + e;
			}

			if (error != null) throw error;
		}
	}

	static inline function plot (dst:BitmapData, x:Int, y:Int, argb:Int):Void {
		if (0 <= x && x < dst.width && 0 <= y && y < dst.height) dst.setPixel32(x, y, argb);
	}

	static inline function copy (src:BitmapData, x:Int, y:Int, w:Int, h:Int, dst:BitmapData, dx:Int, dy:Int, rotated:Bool):Void {
		if (rotated) {
			// TODO: do it faster with BitmapData.draw
			for (i in 0 ... w)
				for (j in 0 ... h)
					plot(dst, dx + j, dy + w - i - 1, src.getPixel32(x + i, y + j));
		} else {
			dst.copyPixels(src, new Rectangle(x, y, w, h), new Point(dx, dy));
		}
	}

	private function writePackFile (packFile:String, pages:Array<Page>):Void {
		if (FileSystem.exists(packFile)) {
			// Make sure there aren't duplicate names.
			// TODO
			/*TextureAtlasData textureAtlasData = new TextureAtlasData(new FileHandle(packFile), new FileHandle(packFile), false);
			for (Page page : pages) {
				for (Rect rect : page.outputRects) {
					String rectName = Rect.getAtlasName(rect.name, settings.flattenPaths);
					for (Region region : textureAtlasData.getRegions()) {
						if (region.name.equals(rectName)) {
							throw new GdxRuntimeException("A region with the name \"" + rectName + "\" has already been packed: "
								+ rect.name);
						}
					}
				}
			}*/
		}

		var writer:FileOutput = File.write(packFile, true);
		for (page in pages) {
			writer.writeString("\n" + page.imageName + "\n");
			writer.writeString("size: " + page.width + "," + page.height + "\n");
			writer.writeString("format: " + settings.format + "\n");
			writer.writeString("filter: " + settings.filterMin + "," + settings.filterMag + "\n");
			writer.writeString("repeat: " + getRepeatValue() + "\n");

			for (rect in page.outputRects) {
				writeRect(writer, page, rect, rect.name);
				for (alias in rect.aliases.keys()) {
					var aliasRect:Rect = rect.clone();
					alias.apply(aliasRect);
					writeRect(writer, page, aliasRect, alias.name);
				}
			}
		}
		writer.close();
	}

	private function writeRect (writer:FileOutput, page:Page, rect:Rect, name:String):Void {
		writer.writeString(Rect.getAtlasName(name, settings.flattenPaths) + "\n");
		writer.writeString("  rotate: " + rect.rotated + "\n");
		writer.writeString("  xy: " + (page.x + rect.x) + ", " + (page.y + page.height - rect.height - rect.y) + "\n");

		writer.writeString("  size: " + rect.regionWidth + ", " + rect.regionHeight + "\n");
		if (rect.splits != null) {
			writer.writeString("  split: " //
				+ rect.splits[0] + ", " + rect.splits[1] + ", " + rect.splits[2] + ", " + rect.splits[3] + "\n");
		}
		if (rect.pads != null) {
			if (rect.splits == null) writer.writeString("  split: 0, 0, 0, 0\n");
			writer.writeString("  pad: " + rect.pads[0] + ", " + rect.pads[1] + ", " + rect.pads[2] + ", " + rect.pads[3] + "\n");
		}
		writer.writeString("  orig: " + rect.originalWidth + ", " + rect.originalHeight + "\n");
		writer.writeString("  offset: " + rect.offsetX + ", " + (rect.originalHeight - rect.regionHeight - rect.offsetY) + "\n");
		writer.writeString("  index: " + rect.index + "\n");
	}

	private function getRepeatValue ():String {
		if (settings.wrapX == TextureWrap.Repeat && settings.wrapY == TextureWrap.Repeat) return "xy";
		if (settings.wrapX == TextureWrap.Repeat && settings.wrapY == TextureWrap.ClampToEdge) return "x";
		if (settings.wrapX == TextureWrap.ClampToEdge && settings.wrapY == TextureWrap.Repeat) return "y";
		return "none";
	}

	/** @param input Directory containing individual images to be packed.
	 * @param output Directory where the pack file and page images will be written.
	 * @param packFileName The name of the pack file. Also used to name the page images. */
	static public function process (input:String, output:String, packFileName:String, ?settings:Settings=null):Void {
		// default settings
		if (settings == null) settings = new Settings(); 
		
		//try {
			var processor:TexturePackerFileProcessor = new TexturePackerFileProcessor(settings, packFileName);
			// Sort input files by name to avoid platform-dependent atlas output changes.
			processor.setComparator(function (file1:String, file2:String) {
				return Utils.stringCompare(file1, file2);
			});
			processor.process(input, output);
		//} catch (e:Dynamic) {
		//	throw "Error packing files: " + e;
		//}
	}

	/** @return true if the output file does not yet exist or its last modification date is before the last modification date of the
	 * input file */
	static public function isModified (input:String, output:String, packFileName:String):Bool {
		var outputFile:String = output;
		outputFile = Path.join([outputFile, packFileName]);
		if (!FileSystem.exists(outputFile)) return true;

		var inputFile:String = input;
		if (!FileSystem.exists(inputFile)) throw "Input file does not exist: " + inputFile;
		var inputFileLastModified = FileSystem.stat(inputFile).mtime.getTime();
		var outputFileLastModified = FileSystem.stat(outputFile).mtime.getTime();
		return inputFileLastModified > outputFileLastModified;
	}

	static public function processIfModified (input:String, output:String, packFileName:String, ?settings:Settings=null):Void {
		if (isModified(input, output, packFileName)) process(input, output, packFileName, settings);
	}

	static public function main ():Void {
		var args:Array<String> = Sys.args();
		var cwd = args.splice(args.length-1, 1)[0];
		Sys.setCwd(cwd);
		var input:String = null, output:String = null, packFileName:String = "pack.atlas";

		if (args.length > 0) {
			input = args[0];
			if (args.length > 1) output = args[1];
			if (args.length > 2) packFileName = args[2];
		} else {
			trace("Usage: inputDir [outputDir] [packFileName]");
			return;
		}

		if (output == null) {
			var inputDir = Path.removeTrailingSlashes(FileSystem.fullPath(input));
			output = inputDir + "-packed";
			FileSystem.createDirectory(output);
			trace(output);
		}

		process(input, output, packFileName);
	}
}
