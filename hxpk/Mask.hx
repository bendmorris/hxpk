package hxpk;

import haxe.ds.Vector;


@:allow(hxpk.ColorBleedEffect)
@:allow(hxpk.MaskIterator)
class Mask {
	var data:Vector<Int>;
	var pending:Vector<Int>;
	var changing:Vector<Int>;
	var pendingSize:Int = 0;
	var changingSize:Int = 0;

	function new (rgb:Array<Int>) {
		data = new Vector(rgb.length);
		pending = new Vector(rgb.length);
		changing = new Vector(rgb.length);
		var color:ARGBColor = new ARGBColor();
		for (i in 0 ... rgb.length) {
			color.argb = rgb[i];
			if (color.alpha() == 0) {
				data[i] = ColorBleedEffect.TO_PROCESS;
				pending[pendingSize] = i;
				pendingSize++;
			} else
				data[i] = ColorBleedEffect.REALDATA;
		}
	}

	function getMask (index:Int):Int {
		return data[index];
	}

	function removeIndex (index:Int):Int {
		if (index >= pendingSize) throw "Index out of bounds: " + index;
		var value:Int = pending[index];
		pendingSize--;
		pending[index] = pending[pendingSize];
		return value;
	}
}
