package hxpk;

using StringTools;


class Settings {
	public var pot:Bool = true;
	public var paddingX:Int = 2;
	public var paddingY:Int = 2;
	public var edgePadding:Bool = true;
	public var duplicatePadding:Bool = false;
	public var rotation:Bool = true;
	public var minWidth:Int = 16;
	public var minHeight:Int = 16;
	public var maxWidth:Int = 1024;
	public var maxHeight:Int = 1024;
	public var square:Bool = false;
	public var stripWhitespaceX:Bool = false;
	public var stripWhitespaceY:Bool = false;
	public var alphaThreshold:Int = 0;
	public var filterMin:TextureFilter;
	public var filterMag:TextureFilter;
	public var wrapX:TextureWrap = TextureWrap.ClampToEdge;
	public var wrapY:TextureWrap = TextureWrap.ClampToEdge;
	public var format:Format = Format.RGBA8888;
	public var alias:Bool = false;
	public var outputFormat:String = "png";
	public var jpegQuality:Float = 0.9;
	public var ignoreBlankImages:Bool = false;
	public var fast:Bool = true;
	public var debug:Bool = false; // not used
	public var combineSubdirectories:Bool = false;
	public var flattenPaths:Bool = false;
	public var premultiplyAlpha:Bool = false;
	public var useIndexes:Bool = true;
	public var bleed:Bool = true;
	public var limitMemory:Bool = false;
	public var grid:Bool = false;
	public var scale:Array<Float>;
	public var scaleSuffix:Array<String>;

	public function new () {
		scale = [1];
		scaleSuffix = [""];
		filterMin = TextureFilter.Nearest;
		filterMag = TextureFilter.Nearest;
	}

	public static function clone (settings:Settings):Settings {
		return Reflect.copy(settings);
	}

	public function scaledPackFileName (packFileName:String, scaleIndex:Int):String {
		var extension:String = "";
		var dotIndex:Int = packFileName.lastIndexOf('.');
		if (dotIndex != -1) {
			extension = packFileName.substring(dotIndex);
			packFileName = packFileName.substring(0, dotIndex);
		}

		// Use suffix if not empty string.
		if (scaleSuffix[scaleIndex].length > 0)
			packFileName += scaleSuffix[scaleIndex];
		else {
			// Otherwise if scale != 1 or multiple scales, use subdirectory.
			var scaleValue:Float = scale[scaleIndex];
			if (scale.length != 1) {
				packFileName = (scaleValue == Std.int(scaleValue) ? ("" + Std.int(scaleValue)) : ("" + scaleValue))
					+ "/" + packFileName;
			}
		}

		packFileName += extension;
		if (packFileName.indexOf('.') == -1 || packFileName.endsWith(".png") || packFileName.endsWith(".jpg"))
			packFileName += ".atlas";
		return packFileName;
	}
}
