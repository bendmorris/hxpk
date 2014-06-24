package hxpk;


/** Maximal rectangles bin packing algorithm. Adapted from this C++ public domain source:
 * http://clb.demon.fi/projects/even-more-rectangle-bin-packing */
 @:allow(hxpk.MaxRectsPacker)
class MaxRects {
	var settings:Settings;

	var binWidth:Int = 0;
	var binHeight:Int = 0;
	var usedRectangles:Array<Rect> = new Array();
	var freeRectangles:Array<Rect> = new Array();

	public function new (?settings:Settings=null) {
		this.settings = settings;
	}

	public function init (width:Int, height:Int):Void {
		binWidth = width;
		binHeight = height;

		usedRectangles.splice(0, usedRectangles.length);
		freeRectangles.splice(0, freeRectangles.length);
		var n:Rect = new Rect();
		n.x = 0;
		n.y = 0;
		n.width = width;
		n.height = height;
		freeRectangles.push(n);
	}

	/** Packs a single image. Order is defined externally. */
	public function insert (rect:Rect, method:FreeRectChoiceHeuristic):Rect {
		var newNode:Rect = scoreRect(rect, method);
		if (newNode.height == 0) return null;

		var numRectanglesToProcess:Int = freeRectangles.length;
		var i:Int = 0;
		while (i < numRectanglesToProcess) {
			if (splitFreeNode(freeRectangles[i], newNode)) {
				Utils.removeIndex(freeRectangles, i);
				--i;
				--numRectanglesToProcess;
			}
			++i;
		}

		pruneFreeList();

		var bestNode:Rect = new Rect();
		bestNode.set(rect);
		bestNode.score1 = newNode.score1;
		bestNode.score2 = newNode.score2;
		bestNode.x = newNode.x;
		bestNode.y = newNode.y;
		bestNode.width = newNode.width;
		bestNode.height = newNode.height;
		bestNode.rotated = newNode.rotated;

		usedRectangles.push(bestNode);
		return bestNode;
	}

	/** For each rectangle, packs each one then chooses the best and packs that. Slow! */
	public function pack (rects:Array<Rect>, method:FreeRectChoiceHeuristic):Page {
		rects = rects.copy();
		while (rects.length > 0) {
			var bestRectIndex:Int = -1;
			var bestNode:Rect = new Rect();
			bestNode.score1 = Utils.MAX_INT;
			bestNode.score2 = Utils.MAX_INT;

			// Find the next rectangle that packs best.
			for (i in 0 ... rects.length) {
				var newNode:Rect = scoreRect(rects[i], method);
				if (newNode.score1 < bestNode.score1 || (newNode.score1 == bestNode.score1 && newNode.score2 < bestNode.score2)) {
					bestNode.set(rects[i]);
					bestNode.score1 = newNode.score1;
					bestNode.score2 = newNode.score2;
					bestNode.x = newNode.x;
					bestNode.y = newNode.y;
					bestNode.width = newNode.width;
					bestNode.height = newNode.height;
					bestNode.rotated = newNode.rotated;
					bestRectIndex = i;
				}
			}

			if (bestRectIndex == -1) break;

			placeRect(bestNode);
			Utils.removeIndex(rects, bestRectIndex);
		}

		var result:Page = getResult();
		result.remainingRects = rects;
		return result;
	}

	public function getResult ():Page {
		var w:Int = 0, h:Int = 0;
		for (i in 0 ... usedRectangles.length) {
			var rect:Rect = usedRectangles[i];
			w = Std.int(Math.max(w, rect.x + rect.width));
			h = Std.int(Math.max(h, rect.y + rect.height));
		}
		var result:Page = new Page();
		result.outputRects = usedRectangles.copy();
		result.occupancy = getOccupancy();
		result.width = w;
		result.height = h;
		return result;
	}

	private function placeRect (node:Rect):Void {
		var numRectanglesToProcess:Int = freeRectangles.length;
		var i:Int = 0;
		while (i < numRectanglesToProcess) {
			if (splitFreeNode(freeRectangles[i], node)) {
				Utils.removeIndex(freeRectangles, i);
				--i;
				--numRectanglesToProcess;
			}
			i++;
		}

		pruneFreeList();

		usedRectangles.push(node);
	}

	private function scoreRect (rect:Rect, method:FreeRectChoiceHeuristic):Rect {
		var width:Int = rect.width;
		var height:Int = rect.height;
		var rotatedWidth:Int = height - settings.paddingY + settings.paddingX;
		var rotatedHeight:Int = width - settings.paddingX + settings.paddingY;
		var rotate:Bool = rect.canRotate && settings.rotation;

		var newNode:Rect = null;
		switch (method) {
			case BestShortSideFit:
				newNode = findPositionForNewNodeBestShortSideFit(width, height, rotatedWidth, rotatedHeight, rotate);
			case BottomLeftRule:
				newNode = findPositionForNewNodeBottomLeft(width, height, rotatedWidth, rotatedHeight, rotate);
			case ContactPointRule:
				newNode = findPositionForNewNodeContactPoint(width, height, rotatedWidth, rotatedHeight, rotate);
				newNode.score1 = -newNode.score1; // Reverse since we are minimizing, but for contact point score bigger is better.
			case BestLongSideFit:
				newNode = findPositionForNewNodeBestLongSideFit(width, height, rotatedWidth, rotatedHeight, rotate);
			case BestAreaFit:
				newNode = findPositionForNewNodeBestAreaFit(width, height, rotatedWidth, rotatedHeight, rotate);
		}

		// Cannot fit the current rectangle.
		if (newNode.height == 0) {
			newNode.score1 = Utils.MAX_INT;
			newNode.score2 = Utils.MAX_INT;
		}

		return newNode;
	}

	// / Computes the ratio of used surface area.
	private function getOccupancy ():Float {
		var usedSurfaceArea:Int = 0;
		for (i in 0 ... usedRectangles.length)
			usedSurfaceArea += usedRectangles[i].width * usedRectangles[i].height;
		return usedSurfaceArea / (binWidth * binHeight);
	}

	private function findPositionForNewNodeBottomLeft (width:Int, height:Int, rotatedWidth:Int, rotatedHeight:Int, rotate:Bool):Rect {
		var bestNode:Rect = new Rect();

		bestNode.score1 = Utils.MAX_INT; // best y, score2 is best x

		for (i in 0 ... freeRectangles.length) {
			// Try to place the rectangle in upright (non-rotated) orientation.
			if (freeRectangles[i].width >= width && freeRectangles[i].height >= height) {
				var topSideY:Int = freeRectangles[i].y + height;
				if (topSideY < bestNode.score1 || (topSideY == bestNode.score1 && freeRectangles[i].x < bestNode.score2)) {
					bestNode.x = freeRectangles[i].x;
					bestNode.y = freeRectangles[i].y;
					bestNode.width = width;
					bestNode.height = height;
					bestNode.score1 = topSideY;
					bestNode.score2 = freeRectangles[i].x;
					bestNode.rotated = false;
				}
			}
			if (rotate && freeRectangles[i].width >= rotatedWidth && freeRectangles[i].height >= rotatedHeight) {
				var topSideY:Int = freeRectangles[i].y + rotatedHeight;
				if (topSideY < bestNode.score1 || (topSideY == bestNode.score1 && freeRectangles[i].x < bestNode.score2)) {
					bestNode.x = freeRectangles[i].x;
					bestNode.y = freeRectangles[i].y;
					bestNode.width = rotatedWidth;
					bestNode.height = rotatedHeight;
					bestNode.score1 = topSideY;
					bestNode.score2 = freeRectangles[i].x;
					bestNode.rotated = true;
				}
			}
		}
		return bestNode;
	}

	private function findPositionForNewNodeBestShortSideFit (width:Int, height:Int, rotatedWidth:Int, rotatedHeight:Int, rotate:Bool):Rect {
		var bestNode:Rect = new Rect();
		bestNode.score1 = Utils.MAX_INT;

		for (i in 0 ... freeRectangles.length) {
			// Try to place the rectangle in upright (non-rotated) orientation.
			if (freeRectangles[i].width >= width && freeRectangles[i].height >= height) {
				var leftoverHoriz:Int = Std.int(Math.abs(freeRectangles[i].width - width));
				var leftoverVert:Int = Std.int(Math.abs(freeRectangles[i].height - height));
				var shortSideFit:Int = Std.int(Math.min(leftoverHoriz, leftoverVert));
				var longSideFit:Int = Std.int(Math.max(leftoverHoriz, leftoverVert));

				if (shortSideFit < bestNode.score1 || (shortSideFit == bestNode.score1 && longSideFit < bestNode.score2)) {
					bestNode.x = freeRectangles[i].x;
					bestNode.y = freeRectangles[i].y;
					bestNode.width = width;
					bestNode.height = height;
					bestNode.score1 = shortSideFit;
					bestNode.score2 = longSideFit;
					bestNode.rotated = false;
				}
			}

			if (rotate && freeRectangles[i].width >= rotatedWidth && freeRectangles[i].height >= rotatedHeight) {
				var flippedLeftoverHoriz:Int = Std.int(Math.abs(freeRectangles[i].width - rotatedWidth));
				var flippedLeftoverVert:Int = Std.int(Math.abs(freeRectangles[i].height - rotatedHeight));
				var flippedShortSideFit:Int = Std.int(Math.min(flippedLeftoverHoriz, flippedLeftoverVert));
				var flippedLongSideFit:Int = Std.int(Math.max(flippedLeftoverHoriz, flippedLeftoverVert));

				if (flippedShortSideFit < bestNode.score1
					|| (flippedShortSideFit == bestNode.score1 && flippedLongSideFit < bestNode.score2)) {
					bestNode.x = freeRectangles[i].x;
					bestNode.y = freeRectangles[i].y;
					bestNode.width = rotatedWidth;
					bestNode.height = rotatedHeight;
					bestNode.score1 = flippedShortSideFit;
					bestNode.score2 = flippedLongSideFit;
					bestNode.rotated = true;
				}
			}
		}

		return bestNode;
	}

	private function findPositionForNewNodeBestLongSideFit (width:Int, height:Int, rotatedWidth:Int, rotatedHeight:Int, rotate:Bool):Rect {
		var bestNode:Rect = new Rect();

		bestNode.score2 = Utils.MAX_INT;

		for (i in 0 ... freeRectangles.length) {
			// Try to place the rectangle in upright (non-rotated) orientation.
			if (freeRectangles[i].width >= width && freeRectangles[i].height >= height) {
				var leftoverHoriz:Int = Std.int(Math.abs(freeRectangles[i].width - width));
				var leftoverVert:Int = Std.int(Math.abs(freeRectangles[i].height - height));
				var shortSideFit:Int = Std.int(Math.min(leftoverHoriz, leftoverVert));
				var longSideFit:Int = Std.int(Math.max(leftoverHoriz, leftoverVert));

				if (longSideFit < bestNode.score2 || (longSideFit == bestNode.score2 && shortSideFit < bestNode.score1)) {
					bestNode.x = freeRectangles[i].x;
					bestNode.y = freeRectangles[i].y;
					bestNode.width = width;
					bestNode.height = height;
					bestNode.score1 = shortSideFit;
					bestNode.score2 = longSideFit;
					bestNode.rotated = false;
				}
			}

			if (rotate && freeRectangles[i].width >= rotatedWidth && freeRectangles[i].height >= rotatedHeight) {
				var leftoverHoriz:Int = Std.int(Math.abs(freeRectangles[i].width - rotatedWidth));
				var leftoverVert:Int = Std.int(Math.abs(freeRectangles[i].height - rotatedHeight));
				var shortSideFit:Int = Std.int(Math.min(leftoverHoriz, leftoverVert));
				var longSideFit:Int = Std.int(Math.max(leftoverHoriz, leftoverVert));

				if (longSideFit < bestNode.score2 || (longSideFit == bestNode.score2 && shortSideFit < bestNode.score1)) {
					bestNode.x = freeRectangles[i].x;
					bestNode.y = freeRectangles[i].y;
					bestNode.width = rotatedWidth;
					bestNode.height = rotatedHeight;
					bestNode.score1 = shortSideFit;
					bestNode.score2 = longSideFit;
					bestNode.rotated = true;
				}
			}
		}
		return bestNode;
	}

	private function findPositionForNewNodeBestAreaFit (width:Int, height:Int, rotatedWidth:Int, rotatedHeight:Int, rotate:Bool):Rect {
		var bestNode:Rect = new Rect();

		bestNode.score1 = Utils.MAX_INT; // best area fit, score2 is best short side fit

		for (i in 0 ... freeRectangles.length) {
			var areaFit:Int = freeRectangles[i].width * freeRectangles[i].height - width * height;

			// Try to place the rectangle in upright (non-rotated) orientation.
			if (freeRectangles[i].width >= width && freeRectangles[i].height >= height) {
				var leftoverHoriz:Int = Std.int(Math.abs(freeRectangles[i].width - width));
				var leftoverVert:Int = Std.int(Math.abs(freeRectangles[i].height - height));
				var shortSideFit:Int = Std.int(Math.min(leftoverHoriz, leftoverVert));

				if (areaFit < bestNode.score1 || (areaFit == bestNode.score1 && shortSideFit < bestNode.score2)) {
					bestNode.x = freeRectangles[i].x;
					bestNode.y = freeRectangles[i].y;
					bestNode.width = width;
					bestNode.height = height;
					bestNode.score2 = shortSideFit;
					bestNode.score1 = areaFit;
					bestNode.rotated = false;
				}
			}

			if (rotate && freeRectangles[i].width >= rotatedWidth && freeRectangles[i].height >= rotatedHeight) {
				var leftoverHoriz:Int = Std.int(Math.abs(freeRectangles[i].width - rotatedWidth));
				var leftoverVert:Int = Std.int(Math.abs(freeRectangles[i].height - rotatedHeight));
				var shortSideFit:Int = Std.int(Math.min(leftoverHoriz, leftoverVert));

				if (areaFit < bestNode.score1 || (areaFit == bestNode.score1 && shortSideFit < bestNode.score2)) {
					bestNode.x = freeRectangles[i].x;
					bestNode.y = freeRectangles[i].y;
					bestNode.width = rotatedWidth;
					bestNode.height = rotatedHeight;
					bestNode.score2 = shortSideFit;
					bestNode.score1 = areaFit;
					bestNode.rotated = true;
				}
			}
		}
		return bestNode;
	}

	// / Returns 0 if the two intervals i1 and i2 are disjoint, or the length of their overlap otherwise.
	private function commonIntervalLength (i1start:Int, i1end:Int, i2start:Int, i2end:Int):Int {
		if (i1end < i2start || i2end < i1start) return 0;
		return Std.int(Math.min(i1end, i2end) - Math.max(i1start, i2start));
	}

	private function contactPointScoreNode (x:Int, y:Int, width:Int, height:Int):Int {
		var score:Int = 0;

		if (x == 0 || x + width == binWidth) score += height;
		if (y == 0 || y + height == binHeight) score += width;

		for (i in 0 ... usedRectangles.length) {
			if (usedRectangles[i].x == x + width || usedRectangles[i].x + usedRectangles[i].width == x)
				score += commonIntervalLength(usedRectangles[i].y, usedRectangles[i].y + usedRectangles[i].height, y,
					y + height);
			if (usedRectangles[i].y == y + height || usedRectangles[i].y + usedRectangles[i].height == y)
				score += commonIntervalLength(usedRectangles[i].x, usedRectangles[i].x + usedRectangles[i].width, x, x
					+ width);
		}
		return score;
	}

	private function findPositionForNewNodeContactPoint (width:Int, height:Int, rotatedWidth:Int, rotatedHeight:Int, rotate:Bool):Rect {
		var bestNode:Rect = new Rect();

		bestNode.score1 = -1; // best contact score

		for (i in 0 ... freeRectangles.length) {
			// Try to place the rectangle in upright (non-rotated) orientation.
			if (freeRectangles[i].width >= width && freeRectangles[i].height >= height) {
				var score:Int = contactPointScoreNode(freeRectangles[i].x, freeRectangles[i].y, width, height);
				if (score > bestNode.score1) {
					bestNode.x = freeRectangles[i].x;
					bestNode.y = freeRectangles[i].y;
					bestNode.width = width;
					bestNode.height = height;
					bestNode.score1 = score;
					bestNode.rotated = false;
				}
			}
			if (rotate && freeRectangles[i].width >= rotatedWidth && freeRectangles[i].height >= rotatedHeight) {
				// This was width,height -- bug fixed?
				var score:Int = contactPointScoreNode(freeRectangles[i].x, freeRectangles[i].y, rotatedWidth, rotatedHeight);
				if (score > bestNode.score1) {
					bestNode.x = freeRectangles[i].x;
					bestNode.y = freeRectangles[i].y;
					bestNode.width = rotatedWidth;
					bestNode.height = rotatedHeight;
					bestNode.score1 = score;
					bestNode.rotated = true;
				}
			}
		}
		return bestNode;
	}

	private function splitFreeNode (freeNode:Rect, usedNode:Rect):Bool {
		// Test with SAT if the rectangles even intersect.
		if (usedNode.x >= freeNode.x + freeNode.width || usedNode.x + usedNode.width <= freeNode.x
			|| usedNode.y >= freeNode.y + freeNode.height || usedNode.y + usedNode.height <= freeNode.y) return false;

		if (usedNode.x < freeNode.x + freeNode.width && usedNode.x + usedNode.width > freeNode.x) {
			// New node at the top side of the used node.
			if (usedNode.y > freeNode.y && usedNode.y < freeNode.y + freeNode.height) {
				var newNode:Rect = Rect.clone(freeNode);
				newNode.height = usedNode.y - newNode.y;
				freeRectangles.push(newNode);
			}

			// New node at the bottom side of the used node.
			if (usedNode.y + usedNode.height < freeNode.y + freeNode.height) {
				var newNode:Rect = Rect.clone(freeNode);
				newNode.y = usedNode.y + usedNode.height;
				newNode.height = freeNode.y + freeNode.height - (usedNode.y + usedNode.height);
				freeRectangles.push(newNode);
			}
		}

		if (usedNode.y < freeNode.y + freeNode.height && usedNode.y + usedNode.height > freeNode.y) {
			// New node at the left side of the used node.
			if (usedNode.x > freeNode.x && usedNode.x < freeNode.x + freeNode.width) {
				var newNode:Rect = Rect.clone(freeNode);
				newNode.width = usedNode.x - newNode.x;
				freeRectangles.push(newNode);
			}

			// New node at the right side of the used node.
			if (usedNode.x + usedNode.width < freeNode.x + freeNode.width) {
				var newNode:Rect = Rect.clone(freeNode);
				newNode.x = usedNode.x + usedNode.width;
				newNode.width = freeNode.x + freeNode.width - (usedNode.x + usedNode.width);
				freeRectangles.push(newNode);
			}
		}

		return true;
	}

	private function pruneFreeList ():Void {
		/*
		 * /// Would be nice to do something like this, to avoid a Theta(n^2) loop through each pair. /// But unfortunately it
		 * doesn't quite cut it, since we also want to detect containment. /// Perhaps there's another way to do this faster than
		 * Theta(n^2).
		 * 
		 * if (freeRectangles.length > 0) clb::sort::QuickSort(&freeRectangles[0], freeRectangles.length, NodeSortCmp);
		 * 
		 * for(int i = 0; i < freeRectangles.length-1; i++) if (freeRectangles[i].x == freeRectangles[i+1].x && freeRectangles[i].y
		 * == freeRectangles[i+1].y && freeRectangles[i].width == freeRectangles[i+1].width && freeRectangles[i].height ==
		 * freeRectangles[i+1].height) { freeRectangles.erase(freeRectangles.begin() + i); --i; }
		 */

		// / Go through each pair and remove any rectangle that is redundant.
		var i:Int = 0;
		while (i < freeRectangles.length) {
			var j:Int = i + 1;
			while (j < freeRectangles.length) {
				if (isContainedIn(freeRectangles[i], freeRectangles[j])) {
					Utils.removeIndex(freeRectangles, i);
					--i;
					break;
				}
				if (isContainedIn(freeRectangles[j], freeRectangles[i])) {
					Utils.removeIndex(freeRectangles, j);
					--j;
				}
				++j;
			}
			++i;
		}
	}

	private function isContainedIn (a:Rect, b:Rect):Bool {
		return a.x >= b.x && a.y >= b.y && a.x + a.width <= b.x + b.width && a.y + a.height <= b.y + b.height;
	}
}
