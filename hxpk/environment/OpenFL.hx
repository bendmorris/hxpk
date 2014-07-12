package hxpk.environment;

import haxe.io.Output;
import haxe.io.Path;
import sys.FileSystem;
import sys.io.File;
import flash.display.BitmapData;
import flash.utils.ByteArray;
import openfl.Assets;
import hxpk.Settings;

using StringTools;


class HxpkAssetLibrary extends AssetLibrary
{
	public var bitmaps:Map<String, BitmapData>;
	public var texts:Map<String, String>;

	public function new()
	{
		super();
		bitmaps = new Map();
		texts = new Map();
	}

	public function saveImage(path:String, image:BitmapData)
	{
		bitmaps.set(path, image);
	}

	public function saveText(path:String, string:String)
	{
		texts.set(path, string);
	}

	public override function getBitmapData(id:String):BitmapData
	{
		return bitmaps.get(id);
	}

	public override function getText(id:String):String
	{
		return texts.get(id);
	}

	public override function exists(id:String, type:AssetType):Bool
	{
		switch(type)
		{
			case AssetType.IMAGE: return bitmaps.exists(id);
			case AssetType.TEXT: return texts.exists(id);
			default: return false;
		}
	}

	public override function isLocal(id:String, type:AssetType):Bool
	{
		return true;
	}

}

class OpenFLTextFile extends Output
{
	var path:String;
	var contents:String = "";
	var library:HxpkAssetLibrary;

	public function new(path:String, library:HxpkAssetLibrary)
	{
		this.path = path;
		this.library = library;
		if (Assets.exists(path, AssetType.TEXT)) contents = Assets.getText(path);
	}

	override public function writeString(string:String)
	{
		contents += string;
		library.saveText(path, contents);
	}
}

class OpenFL implements IPackEnvironment
{
	public var library:HxpkAssetLibrary;
	public var cwd:String = "";

	public function new()
	{
		library = new HxpkAssetLibrary();
		Assets.libraries.set("hxpk", library);
	}

	public function exists(path:String):Bool
	{
		return Assets.exists(path, AssetType.IMAGE) || Assets.exists(path, AssetType.TEXT) || isDirectory(path);
	}

	public function isDirectory(path:String):Bool
	{
		var files = readDirectory(path);
		return readDirectory(path).length > 0;
	}

	public function newerThan(file1:String, file2:String)
	{
		return true;
	}

	public function fullPath(path:String):String
	{
		return path;
	}

	public function readDirectory(path:String):Array<String>
	{
		return [for (img in Assets.list(AssetType.IMAGE)) if (img.startsWith(path) && img != path) Path.withoutDirectory(img)];
	}

	public function getContent(path:String):String
	{
		return Assets.getText(path);
	}

	public function append(path:String):Output
	{
		return new OpenFLTextFile(path, library);
	}

	public function createDirectory(path:String):Void
	{
	}

	public function deleteFile(path:String):Void
	{
	}

	public function loadImage(path:String):BitmapData
	{
		return Assets.getBitmapData(path);
	}

	public function saveImage(image:BitmapData, outputFile:String, settings:Settings):Void
	{
		library.saveImage(outputFile, image);
	}

	public function setCwd(path:String):Void
	{
		cwd = path;
	}
}