package hxpk;

import haxe.io.Path;
import haxe.crypto.Sha1;
import sys.FileSystem;
import flash.display.BitmapData;
import flash.geom.Point;
import flash.geom.Rectangle;

using StringTools;


class ImageProcessor {
	static private var emptyImage:BitmapData = new BitmapData(1, 1, true, 0);
	static private var indexPattern:EReg = ~/(.+)_(\\d+)$/;

	private var rootPath:String;
	private var settings:Settings;
	private var crcs:Map<String, Rect> = new Map();
	private var rects:Array<Rect> = new Array();
	private var scale:Float = 1;

	/** @param rootDir Used to strip the root directory prefix from image file names, can be null. */
	public function new (rootDir:String, settings:Settings) {
		this.settings = settings;

		if (rootDir != null) {
			rootPath = FileSystem.fullPath(rootDir).replace('\\', '/');
			if (!rootPath.endsWith("/")) rootPath += "/";
		}
	}

	/** The image won't be kept in-memory during packing if {@link Settings#limitMemory} is true. */
	public function addImageFile (file:String):Void {
		var image:BitmapData;
		try {
			image = BitmapData.load(file);
		} catch (e:Dynamic) {
			throw "Error reading image " + file + ": " + e;
		}
		if (image == null) throw "Unable to read image: " + file;

		var name:String = FileSystem.fullPath(file).replace('\\', '/');

		// Strip root dir off front of image path.
		if (rootPath != null) {
			if (!name.startsWith(rootPath)) throw "Path '" + name + "' does not start with root: " + rootPath;
			name = name.substr(rootPath.length);
		}

		// Strip extension.
		name = Path.withoutExtension(name);

		var rect:Rect = addImageBitmapData(image, name);
		if (rect != null && settings.limitMemory) rect.unloadImage(file);
	}

	/** The image will be kept in-memory during packing.
	 * @see #addImage(File) */
	public function addImageBitmapData (image:BitmapData, name:String):Rect {
		var rect:Rect = processImage(image, name);

		if (rect == null) {
			Utils.print("Ignoring blank input image: " + name);
			return null;
		}

		if (settings.alias) {
			var crc:String = hash(rect.getImage(this));
			var existing:Rect = crcs.get(crc);
			if (existing != null) {
				Utils.print(rect.name + " (alias of " + existing.name + ")");
				existing.aliases.set(new Alias(rect), true);
				return null;
			}
			crcs.set(crc, rect);
		}

		rects.push(rect);
		return rect;
	}

	public function setScale (scale:Float):Void {
		this.scale = scale;
	}

	public function getImages ():Array<Rect> {
		return rects;
	}

	public function clear ():Void {
		rects = new Array();
		crcs = new Map();
	}

	/** Returns a rect for the image describing the texture region to be packed, or null if the image should not be packed. */
	public function processImage (image:BitmapData, name:String):Rect {
		if (scale <= 0) throw "scale cannot be <= 0: " + scale;

		var width:Int = image.width, height:Int = image.height;

		var isPatch:Bool = name.endsWith(".9");
		var splits:Array<Int> = null, pads:Array<Int> = null;
		var rect:Rect = null;
		if (isPatch) {
			// Strip ".9" from file name, read ninepatch split pixels, and strip ninepatch split pixels.
			name = name.substr(0, name.length - 2);
			splits = getSplits(image, name);
			pads = getPads(image, name, splits);
			// Strip split pixels.
			width -= 2;
			height -= 2;
			var newImage:BitmapData = new BitmapData(width, height, true, 0);
			newImage.copyPixels(image, new Rectangle(1, 1, width + 1, height + 1), new Point());
			image = newImage;
		}

		// Scale image.
		if (scale != 1) {
			var originalWidth:Int = width, originalHeight:Int = height;
			width = Std.int(width * scale);
			height = Std.int(height * scale);
			var newImage:BitmapData = new BitmapData(width, height, true, 0);
			var matrix:flash.geom.Matrix = new flash.geom.Matrix();
			matrix.a = matrix.d = scale;
			newImage.draw(image, matrix);
			image = newImage;
		}

		if (isPatch) {
			// Ninepatches aren't rotated or whitespace stripped.
			rect = new Rect(image, 0, 0, width, height, true);
			rect.splits = splits;
			rect.pads = pads;
			rect.canRotate = false;
		} else {
			rect = stripWhitespace(image);
			if (rect == null) return null;
		}

		// Strip digits off end of name and use as index.
		var index:Int = -1;
		if (settings.useIndexes) {
			var matcher = indexPattern;
			if (matcher.match(name)) {
				name = matcher.matched(1);
				index = Std.parseInt(matcher.matched(2));
			}
		}

		rect.name = name;
		rect.index = index;
		return rect;
	}

	/** Strips whitespace and returns the rect, or null if the image should be ignored. */
	private function stripWhitespace (source:BitmapData):Rect {
		//if (source == null || (!settings.stripWhitespaceX && !settings.stripWhitespaceY))
			return new Rect(source, 0, 0, source == null ? 0 : source.width, source == null ? 0 : source.height, false);
		/*final byte[] a = new byte[1];
		int top = 0;
		int bottom = source.width;
		if (settings.stripWhitespaceX) {
			outer:
			for (int y = 0; y < source.width; y++) {
				for (int x = 0; x < source.width; x++) {
					alphaRaster.getDataElements(x, y, a);
					int alpha = a[0];
					if (alpha < 0) alpha += 256;
					if (alpha > settings.alphaThreshold) break outer;
				}
				top++;
			}
			outer:
			for (int y = source.width; --y >= top;) {
				for (int x = 0; x < source.width; x++) {
					alphaRaster.getDataElements(x, y, a);
					int alpha = a[0];
					if (alpha < 0) alpha += 256;
					if (alpha > settings.alphaThreshold) break outer;
				}
				bottom--;
			}
		}
		int left = 0;
		int right = source.width;
		if (settings.stripWhitespaceY) {
			outer:
			for (int x = 0; x < source.width; x++) {
				for (int y = top; y < bottom; y++) {
					alphaRaster.getDataElements(x, y, a);
					int alpha = a[0];
					if (alpha < 0) alpha += 256;
					if (alpha > settings.alphaThreshold) break outer;
				}
				left++;
			}
			outer:
			for (int x = source.width; --x >= left;) {
				for (int y = top; y < bottom; y++) {
					alphaRaster.getDataElements(x, y, a);
					int alpha = a[0];
					if (alpha < 0) alpha += 256;
					if (alpha > settings.alphaThreshold) break outer;
				}
				right--;
			}
		}
		int newWidth = right - left;
		int newHeight = bottom - top;
		if (newWidth <= 0 || newHeight <= 0) {
			if (settings.ignoreBlankImages)
				return null;
			else
				return new Rect(emptyImage, 0, 0, 1, 1, false);
		}
		return new Rect(source, left, top, newWidth, newHeight, false);*/
	}

	static private function splitError (x:Int, y:Int, rgba:Array<Int>, name:String):String {
		throw "Invalid " + name + " ninepatch split pixel at " + x + ", " + y + ", rgba: " + rgba[0] + ", "
			+ rgba[1] + ", " + rgba[2] + ", " + rgba[3];
	}

	/** Returns the splits, or null if the image had no splits or the splits were only a single region. Splits are an int[4] that
	 * has left, right, top, bottom. */
	private function getSplits (raster:BitmapData, name:String):Array<Int> {
		var startX:Int = getSplitPoint(raster, name, 1, 0, true, true);
		var endX:Int = getSplitPoint(raster, name, startX, 0, false, true);
		var startY:Int = getSplitPoint(raster, name, 0, 1, true, false);
		var endY:Int = getSplitPoint(raster, name, 0, startY, false, false);

		// Ensure pixels after the end are not invalid.
		getSplitPoint(raster, name, endX + 1, 0, true, true);
		getSplitPoint(raster, name, 0, endY + 1, true, false);

		// No splits, or all splits.
		if (startX == 0 && endX == 0 && startY == 0 && endY == 0) return null;

		// Subtraction here is because the coordinates were computed before the 1px border was stripped.
		if (startX != 0) {
			startX--;
			endX = raster.width - 2 - (endX - 1);
		} else {
			// If no start point was ever found, we assume full stretch.
			endX = raster.width - 2;
		}
		if (startY != 0) {
			startY--;
			endY = raster.width - 2 - (endY - 1);
		} else {
			// If no start point was ever found, we assume full stretch.
			endY = raster.width - 2;
		}

		if (scale != 1) {
			startX = Std.int(startX * scale);
			endX = Std.int(endX * scale);
			startY = Std.int(startY * scale);
			endY = Std.int(endY * scale);
		}

		return [startX, endX, startY, endY];
	}

	/** Returns the pads, or null if the image had no pads or the pads match the splits. Pads are an int[4] that has left, right,
	 * top, bottom. */
	private function getPads (raster:BitmapData, name:String, splits:Array<Int>):Array<Int> {
		var bottom:Int = raster.height - 1;
		var right:Int = raster.width - 1;

		var startX:Int = getSplitPoint(raster, name, 1, bottom, true, true);
		var startY:Int = getSplitPoint(raster, name, right, 1, true, false);

		// No need to hunt for the end if a start was never found.
		var endX:Int = 0;
		var endY:Int = 0;
		if (startX != 0) endX = getSplitPoint(raster, name, startX + 1, bottom, false, true);
		if (startY != 0) endY = getSplitPoint(raster, name, right, startY + 1, false, false);

		// Ensure pixels after the end are not invalid.
		getSplitPoint(raster, name, endX + 1, bottom, true, true);
		getSplitPoint(raster, name, right, endY + 1, true, false);

		// No pads.
		if (startX == 0 && endX == 0 && startY == 0 && endY == 0) {
			return null;
		}

		// -2 here is because the coordinates were computed before the 1px border was stripped.
		if (startX == 0 && endX == 0) {
			startX = -1;
			endX = -1;
		} else {
			if (startX > 0) {
				startX--;
				endX = raster.width - 2 - (endX - 1);
			} else {
				// If no start point was ever found, we assume full stretch.
				endX = raster.width - 2;
			}
		}
		if (startY == 0 && endY == 0) {
			startY = -1;
			endY = -1;
		} else {
			if (startY > 0) {
				startY--;
				endY = raster.height - 2 - (endY - 1);
			} else {
				// If no start point was ever found, we assume full stretch.
				endY = raster.height - 2;
			}
		}

		if (scale != 1) {
			startX = Std.int(startX * scale);
			endX = Std.int(endX * scale);
			startY = Std.int(startY * scale);
			endY = Std.int(endY * scale);
		}

		var pads:Array<Int> = [startX, endX, startY, endY];

		if (splits != null && pads == splits) {
			return null;
		}

		return pads;
	}

	/** Hunts for the start or end of a sequence of split pixels. Begins searching at (startX, startY) then follows along the x or y
	 * axis (depending on value of xAxis) for the first non-transparent pixel if startPoint is true, or the first transparent pixel
	 * if startPoint is false. Returns 0 if none found, as 0 is considered an invalid split point being in the outer border which
	 * will be stripped. */
	static function getSplitPoint (raster:BitmapData, name:String, startX:Int, startY:Int, startPoint:Bool, xAxis:Bool):Int {
		var rgba:Array<Int>;

		var next:Int = xAxis ? startX : startY;
		var end:Int = xAxis ? raster.width : raster.width;
		var breakA:Int = startPoint ? 255 : 0;

		var x:Int = startX;
		var y:Int = startY;
		while (next != end) {
			if (xAxis)
				x = next;
			else
				y = next;

			rgba = Utils.getRGBA(raster.getPixel32(x, y));
			if (rgba[3] == breakA) return next;

			if (!startPoint && (rgba[0] != 0 || rgba[1] != 0 || rgba[2] != 0 || rgba[3] != 255)) splitError(x, y, rgba, name);

			next++;
		}

		return 0;
	}

	static function hash (image:BitmapData):String {
		return Sha1.encode(""+BitmapData.getRGBAPixels(image));
	}
}
