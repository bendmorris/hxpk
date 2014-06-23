package hxpk;


class GridPacker implements Packer {
	private var settings:Settings;

	public function new(settings:Settings) {
		this.settings = settings;
	}

	public function pack (inputRects:Array<Rect>):Array<Page> {
		trace("Packing");

		var cellWidth:Int = 0, cellHeight:Int = 0;
		for (i in 0 ... inputRects.length) {
			var rect:Rect = inputRects[i];
			cellWidth = Std.int(Math.max(cellWidth, rect.width));
			cellHeight = Std.int(Math.max(cellHeight, rect.height));
		}
		cellWidth += settings.paddingX;
		cellHeight += settings.paddingY;

		inputRects.reverse();

		var pages:Array<Page> = new Array();
		while (inputRects.length > 0) {
			var result:Page = packPage(inputRects, cellWidth, cellHeight);
			pages.push(result);
		}
		return pages;
	}

	private function packPage (inputRects:Array<Rect>, cellWidth:Int, cellHeight:Int):Page {
		var page:Page = new Page();
		page.outputRects = new Array();

		var maxWidth:Int = settings.maxWidth, maxHeight:Int = settings.maxHeight;
		if (settings.edgePadding) {
			maxWidth -= settings.paddingX;
			maxHeight -= settings.paddingY;
		}
		var x:Int = 0, y:Int = 0;
		var i:Int = inputRects.length - 1;
		while (i >= 0) {
			if (x + cellWidth > maxWidth) {
				y += cellHeight;
				if (y > maxHeight - cellHeight) break;
				x = 0;
			}
			var rect:Rect = inputRects[i];
			inputRects.remove(rect);
			rect.x = x;
			rect.y = y;
			rect.width += settings.paddingX;
			rect.height += settings.paddingY;
			page.outputRects.push(rect);
			x += cellWidth;
			page.width = Std.int(Math.max(page.width, x));
			page.height = Std.int(Math.max(page.height, y + cellHeight));
			i--;
		}

		// Flip so rows start at top.
		var i:Int = page.outputRects.length - 1;
		while (i >= 0) {
			var rect:Rect = page.outputRects[i];
			rect.y = page.height - rect.y - rect.height;
			i--;
		}
		return page;
	}
}
