package hxpk;


/** Packs pages of images using the maximal rectangles bin packing algorithm by Jukka Jylänki. A brute force binary search is used
 * to pack into the smallest bin possible.*/
class MaxRectsPacker implements Packer {
	var rectComparator:Comparator<Rect>;
	var methods:Array<FreeRectChoiceHeuristic> = [
		BestShortSideFit,
		BestLongSideFit,
		BestAreaFit,
		BottomLeftRule,
		ContactPointRule,
	];
	var maxRects:MaxRects = new MaxRects();
	var settings(default, set):Settings;
	function set_settings(settings:Settings) {
		return maxRects.settings = this.settings = settings;
	}

	public function new (settings:Settings) {
		this.settings = settings;
		if (settings.minWidth > settings.maxWidth) throw "Page min width cannot be higher than max width.";
		if (settings.minHeight > settings.maxHeight)
			throw "Page min height cannot be higher than max height.";
		rectComparator = function(o1:Rect, o2:Rect) {
			return Utils.stringCompare(Rect.getAtlasName(o1.name, this.settings.flattenPaths), Rect.getAtlasName(o2.name, this.settings.flattenPaths));
		};
	}

	public function pack (inputRects:Array<Rect>):Array<Page> {
		for (i in 0 ... inputRects.length) {
			var rect:Rect = inputRects[i];
			rect.width += settings.paddingX;
			rect.height += settings.paddingY;
		}

		if (!settings.fast) {
			if (settings.rotation) {
				// Sort by longest side if rotation is enabled.
				inputRects.sort(function (o1:Rect, o2:Rect) {
					var n1:Int = o1.width > o1.height ? o1.width : o1.height;
					var n2:Int = o2.width > o2.height ? o2.width : o2.height;
					return n2 - n1;
				});
			} else {
				// Sort only by width (largest to smallest) if rotation is disabled.
				inputRects.sort(function (o1:Rect, o2:Rect) {
					return o2.width - o1.width;
				});
			}
		}

		var pages:Array<Page> = new Array();
		while (inputRects.length > 0) {
			var result:Page = packPage(inputRects);
			pages.push(result);
			inputRects = result.remainingRects;
		}
		return pages;
	}

	private function packPage (inputRects:Array<Rect>):Page {
		var edgePaddingX:Int = 0, edgePaddingY = 0;
		if (!settings.duplicatePadding) { // if duplicatePadding, edges get only half padding.
			edgePaddingX = settings.paddingX;
			edgePaddingY = settings.paddingY;
		}
		// Find min size.
		var minWidth:Int = Utils.MAX_INT;
		var minHeight:Int = Utils.MAX_INT;
		for (i in 0 ... inputRects.length) {
			var rect:Rect = inputRects[i];
			minWidth = Std.int(Math.min(minWidth, rect.width));
			minHeight = Std.int(Math.min(minHeight, rect.height));
			if (settings.rotation) {
				if ((rect.width > settings.maxWidth || rect.height > settings.maxHeight)
					&& (rect.width > settings.maxHeight || rect.height > settings.maxWidth)) {
					throw "Image does not fit with max page size " + settings.maxWidth + "x" + settings.maxHeight
						+ " and padding " + settings.paddingX + "," + settings.paddingY + ": " + rect;
				}
			} else {
				if (rect.width > settings.maxWidth) {
					throw "Image does not fit with max page width " + settings.maxWidth + " and paddingX "
						+ settings.paddingX + ": " + rect;
				}
				if (rect.height > settings.maxHeight && (!settings.rotation || rect.width > settings.maxHeight)) {
					throw "Image does not fit in max page height " + settings.maxHeight + " and paddingY "
						+ settings.paddingY + ": " + rect;
				}
			}
		}
		minWidth = Std.int(Math.max(minWidth, settings.minWidth));
		minHeight = Std.int(Math.max(minHeight, settings.minHeight));

		Utils.print("Packing");

		// Find the minimal page size that fits all rects.
		var bestResult:Page = null;
		if (settings.square) {
			var minSize:Int = Std.int(Math.max(minWidth, minHeight));
			var maxSize:Int = Std.int(Math.min(settings.maxWidth, settings.maxHeight));
			var sizeSearch:BinarySearch = new BinarySearch(minSize, maxSize, settings.fast ? 25 : 15, settings.pot);
			var size:Int = sizeSearch.reset(), i = 0;
			while (size != -1) {
				var result:Page = packAtSize(true, size - edgePaddingX, size - edgePaddingY, inputRects);
				//if (++i % 70 == 0) System.out.println();
				//System.out.print(".");
				bestResult = getBest(bestResult, result);
				size = sizeSearch.next(result == null);
			}
			//System.out.println();
			// Rects don't fit on one page. Fill a whole page and return.
			if (bestResult == null) bestResult = packAtSize(false, maxSize - edgePaddingX, maxSize - edgePaddingY, inputRects);
			bestResult.outputRects.sort(rectComparator);
			bestResult.width = Std.int(Math.max(bestResult.width, bestResult.height));
			bestResult.height = Std.int(Math.max(bestResult.width, bestResult.height));
			return bestResult;
		} else {
			var widthSearch:BinarySearch = new BinarySearch(minWidth, settings.maxWidth, settings.fast ? 25 : 15, settings.pot);
			var heightSearch:BinarySearch = new BinarySearch(minHeight, settings.maxHeight, settings.fast ? 25 : 15, settings.pot);
			var width:Int = widthSearch.reset(), i = 0;
			var height:Int = settings.square ? width : heightSearch.reset();
			while (true) {
				var bestWidthResult:Page = null;
				while (width != -1) {
					var result:Page = packAtSize(true, width - edgePaddingX, height - edgePaddingY, inputRects);
					//if (++i % 70 == 0) System.out.println();
					//System.out.print(".");
					bestWidthResult = getBest(bestWidthResult, result);
					width = widthSearch.next(result == null);
					if (settings.square) height = width;
				}
				bestResult = getBest(bestResult, bestWidthResult);
				if (settings.square) break;
				height = heightSearch.next(bestWidthResult == null);
				if (height == -1) break;
				width = widthSearch.reset();
			}
			//System.out.println();
			// Rects don't fit on one page. Fill a whole page and return.
			if (bestResult == null)
				bestResult = packAtSize(false, settings.maxWidth - edgePaddingX, settings.maxHeight - edgePaddingY, inputRects);
			bestResult.outputRects.sort(rectComparator);
			return bestResult;
		}
	}

	/** @param fully If true, the only results that pack all rects will be considered. If false, all results are considered, not all
	 *           rects may be packed. */
	private function packAtSize (fully:Bool, width:Int, height:Int, inputRects:Array<Rect>):Page {
		var bestResult:Page = null;
		for (i in 0 ... methods.length) {
			maxRects.init(width, height);
			var result:Page;
			if (!settings.fast) {
				result = maxRects.pack(inputRects, methods[i]);
			} else {
				var remaining:Array<Rect> = new Array();
				var ii:Int = 0;
				while (ii < inputRects.length) {
					var rect:Rect = inputRects[ii];
					if (maxRects.insert(rect, methods[i]) == null) {
						while (ii < inputRects.length)
							remaining.push(inputRects[ii++]);
					}
					++ii;
				}
				result = maxRects.getResult();
				result.remainingRects = remaining;
			}
			if (fully && result.remainingRects.length > 0) continue;
			if (result.outputRects.length == 0) continue;
			bestResult = getBest(bestResult, result);
		}
		return bestResult;
	}

	private function getBest (result1:Page, result2:Page):Page {
		if (result1 == null) return result2;
		if (result2 == null) return result1;
		return result1.occupancy > result2.occupancy ? result1 : result2;
	}

}
