package hxpk.environment;

import haxe.io.Output;
import sys.FileSystem;
import sys.io.File;
import flash.display.BitmapData;
import flash.utils.ByteArray;
import hxpk.Settings;


class FileSystem implements IPackEnvironment
{
	public function new() {}
	
	public function exists(path:String):Bool
	{
		return sys.FileSystem.exists(path);
	}

	public function isDirectory(path:String):Bool
	{
		return sys.FileSystem.isDirectory(path);
	}

	public function getModifiedTime(path:String):Float
	{
		return sys.FileSystem.stat(path).mtime.getTime();
	}

	public function fullPath(path:String):String
	{
		return sys.FileSystem.fullPath(path);
	}

	public function readDirectory(path:String):Array<String>
	{
		return sys.FileSystem.readDirectory(path);
	}

	public function getContent(path:String):String
	{
		return sys.io.File.getContent(path);
	}

	public function append(path:String):Output
	{
		return sys.io.File.append(path, true);
	}

	public function createDirectory(path:String):Void
	{
		sys.FileSystem.createDirectory(path);
	}

	public function deleteFile(path:String):Void
	{
		sys.FileSystem.deleteFile(path);
	}

	public function saveImage(image:BitmapData, outputFile:String, settings:Settings):Void
	{
		var imageData:ByteArray = image.encode(settings.outputFormat, settings.outputFormat.toLowerCase() == "jpg" ? settings.jpegQuality : 1);
		var fo:Output = sys.io.File.write(outputFile, true);
		fo.writeBytes(imageData, 0, imageData.length);
		fo.close();
	}
}