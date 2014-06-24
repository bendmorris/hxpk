package hxpk;


enum FreeRectChoiceHeuristic {
	// BSSF: Positions the rectangle against the short side of a free rectangle into which it fits the best.
	BestShortSideFit;
	// BLSF: Positions the rectangle against the long side of a free rectangle into which it fits the best.
	BestLongSideFit;
	// BAF: Positions the rectangle into the smallest free rect into which it fits.
	BestAreaFit;
	// BL: Does the Tetris placement.
	BottomLeftRule;
	// CP: Choosest the placement where the rectangle touches other rects as much as possible.
	ContactPointRule;
}
