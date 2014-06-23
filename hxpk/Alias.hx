package hxpk;

class Alias {
	public var name:String;
	public var index:Int;
	public var splits:Array<Int>;
	public var pads:Array<Int>;
	public var offsetX:Int;
	public var offsetY:Int;
	public var originalWidth:Int;
	public var originalHeight:Int;

	public function new (rect:Rect) {
		name = rect.name;
		index = rect.index;
		splits = rect.splits;
		pads = rect.pads;
		offsetX = rect.offsetX;
		offsetY = rect.offsetY;
		originalWidth = rect.originalWidth;
		originalHeight = rect.originalHeight;
	}

	public function apply (rect:Rect):Void {
		rect.name = name;
		rect.index = index;
		rect.splits = splits;
		rect.pads = pads;
		rect.offsetX = offsetX;
		rect.offsetY = offsetY;
		rect.originalWidth = originalWidth;
		rect.originalHeight = originalHeight;
	}
}
