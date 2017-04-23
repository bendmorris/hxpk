package hxpk;

import Map;

class OrderedMap<K, V> implements IMap<K, V>
{
	var map:Map<K, V>;
	var _keys:Array<K>;
	var idx = 0;

	public function new(_map)
	{
		_keys = [];
		map = _map;
	}

	public function set(key:K, value:V)
	{
		if(_keys.indexOf(key) == -1) _keys.push(key);
		map[key] = value;
	}

	public function get(key:K):V return map.get(key);

	public function toString()
	{
		var _ret = ''; var _cnt = 0; var _len = _keys.length;
		for(k in _keys) _ret += '$k => ${map.get(k)}${(_cnt++<_len-1?", ":"")}';
		return '{$_ret}';
	}

	public function iterator() return map.iterator();
	public function remove(key) return map.remove(key) && _keys.remove(key);
	public function exists(key) return map.exists(key);
	public inline function keys() return _keys.iterator();
}
