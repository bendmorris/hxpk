package hxpk;


class MaskIterator {
	var mask:Mask;
	var index:Int;

	public function new(mask:Mask) {
		this.mask = mask;
	}

	public function hasNext ():Bool {
		return index < mask.pendingSize;
	}

	public function next ():Int {
		if (index >= mask.pendingSize) throw "No such element: "  + index;
		return mask.pending[index++];
	}

	public function markAsInProgress ():Void {
		index--;
		mask.changing[mask.changingSize] = mask.removeIndex(index);
		mask.changingSize++;
	}

	public function reset ():Void {
		index = 0;
		for (i in 0 ... mask.changingSize) {
			var index:Int = mask.changing[i];
			mask.data[index] = ColorBleedEffect.REALDATA;
		}
		mask.changingSize = 0;
	}
}
