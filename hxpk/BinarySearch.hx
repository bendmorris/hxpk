package hxpk;


class BinarySearch {
	var min:Int = 0;
	var max:Int = 0;
	var fuzziness:Int = 0;
	var low:Int = 0;
	var high:Int = 0;
	var current:Int = 0;
	var pot:Bool = false;

	public function new (min:Int, max:Int, fuzziness:Int, pot:Bool) {
		this.pot = pot;
		this.fuzziness = pot ? 0 : fuzziness;
		this.min = pot ? Std.int(Math.log(Utils.nextPowerOfTwo(min)) / Math.log(2)) : min;
		this.max = pot ? Std.int(Math.log(Utils.nextPowerOfTwo(max)) / Math.log(2)) : max;
	}

	public function reset ():Int {
		low = min;
		high = max;
		current = (low + high) >>> 1;
		return pot ? Std.int(Math.pow(2, current)) : current;
	}

	public function next (result:Bool):Int {
		if (low >= high) return -1;
		if (result)
			low = current + 1;
		else
			high = current - 1;
		current = (low + high) >>> 1;
		if (Math.abs(low - high) < fuzziness) return -1;
		return pot ? Std.int(Math.pow(2, current)) : current;
	}
}
