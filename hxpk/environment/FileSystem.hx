package hxpk.environment;

import haxe.io.Output;
import sys.FileSystem;
import sys.io.File;


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
}