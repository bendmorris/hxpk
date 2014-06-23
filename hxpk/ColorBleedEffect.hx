package hxpk;

import flash.display.BitmapData;
import flash.geom.Rectangle;


class ColorBleedEffect {
	public static var TO_PROCESS:Int = 0;
	public static var IN_PROCESS:Int = 1;
	public static var REALDATA:Int = 2;
	static var offsets:Array<Array<Int>> = [[-1, -1], [0, -1], [1, -1], [-1, 0], [1, 0], [-1, 1], [0, 1], [1, 1]];

	var color:ARGBColor = new ARGBColor();

	public function processImage (image:BitmapData, maxIterations:Int):BitmapData {
		var width:Int = image.width;
		var height:Int = image.height;

		var processedImage:BitmapData = new BitmapData(width, height, true, 0);
		var rgb:Array<Int> = image.getVector(new Rectangle(0, 0, width, height));
		var mask:Mask = new Mask(rgb);

		var iterations:Int = 0;
		var lastPending:Int = -1;
		while (mask.pendingSize > 0 && mask.pendingSize != lastPending && iterations < maxIterations) {
			lastPending = mask.pendingSize;
			executeIteration(rgb, mask, width, height);
			iterations++;
		}

		processedImage.setVector(new Rectangle(0, 0, width, height), rgb);
		return processedImage;
	}

	private function executeIteration (rgb:Array<Int>, mask:Mask, width:Int, height:Int) {
		var iterator:MaskIterator = new MaskIterator(mask);
		for (pixelIndex in iterator) {
			var x:Int = pixelIndex % width;
			var y:Int = Std.int(pixelIndex / width);
			var r:Int = 0, g:Int = 0, b:Int = 0;
			var count:Int = 0;

			for (i in 0 ... offsets.length) {
				var offset:Array<Int> = offsets[i];
				var column:Int = x + offset[0];
				var row:Int = y + offset[1];

				if (column < 0 || column >= width || row < 0 || row >= height) continue;

				var currentPixelIndex:Int = getPixelIndex(width, column, row);
				if (mask.getMask(currentPixelIndex) == REALDATA) {
					color.argb = rgb[currentPixelIndex];
					r += color.red();
					g += color.green();
					b += color.blue();
					count++;
				}
			}

			if (count != 0) {
				color.setARGBA(0, Std.int(r / count), Std.int(g / count), Std.int(b / count));
				rgb[pixelIndex] = color.argb;
				iterator.markAsInProgress();
			}
		}

		iterator.reset();
	}

	private function getPixelIndex (width:Int, x:Int, y:Int):Int {
		return y * width + x;
	}
}
