package hxpk;

import haxe.io.Path;
import sys.FileSystem;


class Utils {
	public static inline var MAX_INT:Int = 2147483647;

	static public inline function getRGBA(c:Int):Array<Int> {
		var rgba:Array<Int> = [
			(c >> 24) & 0xFF,
			(c >> 16) & 0xFF,
			(c >> 8) & 0xFF,
			c & 0xFF,
		];
		return rgba;
	}

	/** Returns the next power of two. Returns the specified value if the value is already a power of two. */
	public static function nextPowerOfTwo (value:Int):Int {
		if (value == 0) return 1;
		value--;
		value |= value >> 1;
		value |= value >> 2;
		value |= value >> 4;
		value |= value >> 8;
		value |= value >> 16;
		return value + 1;
	}

	public static inline function isPowerOfTwo (value:Int):Bool {
		return value != 0 && (value & value - 1) == 0;
	}

	public static inline function stringCompare (s1:String, s2:String):Int {
		return s1 < s2 ? -1 : s2 < s1 ? 1 : 0;
	}

	public static inline function getParentFile (p:String):String {
		if (FileSystem.exists(p) && FileSystem.isDirectory(p)) {
			// TODO: return parent directory
			var dirParts = p.split('/');
			dirParts = dirParts.slice(0, dirParts.length - 1);
			return dirParts.join('/');
		}
		else return Path.directory(p);
	}

	public static inline function removeIndex<T>(array:Array<T>, n:Int):Void {
		var item = array[n];
		array.remove(item);
	}

	public static inline function print(s:String) {
#if hxpk_cli
		Sys.println(s);
#end
	}
}
