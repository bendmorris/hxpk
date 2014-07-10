package hxpk.environment;

import haxe.io.Output;


interface IPackEnvironment
{
	public function exists(path:String):Bool;
	public function isDirectory(path:String):Bool;
	public function getModifiedTime(path:String):Float;
	public function fullPath(path:String):String;
	public function readDirectory(path:String):Array<String>;
	public function getContent(path:String):String;

	public function append(path:String):Output;

	public function createDirectory(path:String):Void;
	public function deleteFile(path:String):Void;
}