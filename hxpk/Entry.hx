package hxpk;


class Entry {
	public var inputFile:String;
	/** May be null. */
	public var outputDir:String;
	public var outputFile:String;
	public var depth:Int = 0;

	public function new (?inputFile=null, ?outputFile=null) {
		this.inputFile = inputFile;
		this.outputFile = outputFile;
	}

	public function toString ():String {
		return inputFile;
	}
}
