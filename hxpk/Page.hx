package hxpk;


class Page {
	public var imageName:String;
	public var outputRects:Array<Rect>;
	public var remainingRects:Array<Rect>;
	public var occupancy:Float = 0;
	public var x:Int = 0;
	public var y:Int = 0;
	public var width:Int = 0;
	public var height:Int = 0;

	public function new() {}
}
