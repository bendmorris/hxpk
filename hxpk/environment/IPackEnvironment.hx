package hxpk.environment;

import haxe.io.Output;
import flash.display.BitmapData;
import hxpk.Settings;


interface IPackEnvironment
{
	public function exists(path:String):Bool;
	public function isDirectory(path:String):Bool;
	public function newerThan(file1:String, file2:String):Bool;
	public function fullPath(path:String):String;
	public function readDirectory(path:String):Array<String>;
	public function getContent(path:String):String;

	public function append(path:String):Output;

	public function createDirectory(path:String):Void;
	public function deleteFile(path:String):Void;
	public function saveImage(image:BitmapData, outputFile:String, settings:Settings):Void;
}