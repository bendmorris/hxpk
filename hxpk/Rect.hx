package hxpk;

import haxe.io.Path;
import flash.display.BitmapData;


@:allow(hxpk.MaxRects)
class Rect {
	public var name:String;
	public var offsetX:Int = 0;
	public var offsetY:Int = 0;
	public var regionWidth:Int = 0;
	public var regionHeight:Int = 0;
	public var originalWidth:Int = 0;
	public var originalHeight:Int = 0;
	public var x:Int = 0;
	public var y:Int = 0;
	public var width:Int = 0;
	public var height:Int = 0; // Portion of page taken by this region, including padding.
	public var index:Int = 0;
	public var rotated:Bool = false;
	public var aliases:Map<Alias, Bool> = new Map();
	public var splits:Array<Int>;
	public var pads:Array<Int>;
	public var canRotate:Bool = true;

	var isPatch:Bool = false;
	var image:BitmapData;
	var file:String;
	var score1:Int = 0;
	var score2:Int = 0;

	public function new (?source:BitmapData=null, left:Int=0, top:Int=0, newWidth:Int=0, newHeight:Int=0, isPatch:Bool=false) {
		image = source;
		//BufferedImage(source.getColorModel(), source.getRaster().createWritableChild(left, top, newWidth, newHeight,
		//	0, 0, null), source.getColorModel().isAlphaPremultiplied(), null);
		offsetX = left;
		offsetY = top;
		regionWidth = newWidth;
		regionHeight = newHeight;
		originalWidth = source == null ? 0 : source.width;
		originalHeight = source == null ? 0 : source.height;
		width = newWidth;
		height = newHeight;
		this.isPatch = isPatch;
	}

	/** Clears the image for this rect, which will be loaded from the specified file by {@link #getImage(ImageProcessor)}. */
	public function unloadImage (file:String):Void {
		this.file = file;
		image = null;
	}

	public function getImage (imageProcessor:ImageProcessor):BitmapData {
		if (image != null) return image;

		var image:BitmapData;
		try {
			image = Settings.environment.loadImage(file);
		} catch (e:Dynamic) {
			throw "Error reading image " + file + ": " + e;
		}
		if (image == null) throw "Unable to read image: " + file;
		var name:String = this.name;
		if (isPatch) name += ".9";
		return imageProcessor.processImage(image, name).getImage(null);
	}

	public function set (rect:Rect):Void {
		name = rect.name;
		image = rect.image;
		offsetX = rect.offsetX;
		offsetY = rect.offsetY;
		regionWidth = rect.regionWidth;
		regionHeight = rect.regionHeight;
		originalWidth = rect.originalWidth;
		originalHeight = rect.originalHeight;
		x = rect.x;
		y = rect.y;
		width = rect.width;
		height = rect.height;
		index = rect.index;
		rotated = rect.rotated;
		aliases = rect.aliases;
		splits = rect.splits;
		pads = rect.pads;
		canRotate = rect.canRotate;
		score1 = rect.score1;
		score2 = rect.score2;
		file = rect.file;
		isPatch = rect.isPatch;
	}

	public static function clone(rect:Rect):Rect {
		return Reflect.copy(rect);
	}

	public function equals (other:Rect):Bool {
		if (other == null) return false;
		if (this == other) return true;
		if (name == null) {
			if (other.name != null) return false;
		} else if (name != other.name) return false;
		return true;
	}

	public function toString ():String {
		return name + "[" + x + "," + y + " " + width + "x" + height + "]";
	}

	static public function getAtlasName (name:String, flattenPaths:Bool):String {
		return flattenPaths ? Path.withoutDirectory(name) : name;
	}
}
