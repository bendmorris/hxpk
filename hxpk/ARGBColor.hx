package hxpk;


class ARGBColor {
	public var argb:Int = 0xff000000;

	public function red ():Int {
		return (argb >> 16) & 0xFF;
	}

	public function green () {
		return (argb >> 8) & 0xFF;
	}

	public function blue () {
		return (argb >> 0) & 0xFF;
	}

	public function alpha () {
		return (argb >> 24) & 0xff;
	}

	public function setARGBA (a:Int, r:Int, g:Int, b:Int):Void {
		if (a < 0 || a > 255 || r < 0 || r > 255 || g < 0 || g > 255 || b < 0 || b > 255)
			throw "Invalid RGBA: " + r + ", " + g + "," + b + "," + a;
		argb = ((a & 0xFF) << 24) | ((r & 0xFF) << 16) | ((g & 0xFF) << 8) | ((b & 0xFF) << 0);
	}
}
