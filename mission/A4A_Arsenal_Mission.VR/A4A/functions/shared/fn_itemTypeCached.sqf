params [
    ["_className", "", [""]],
    ["_useStoredFallback", false, [false]]
];
if (_className isEqualTo "" || {count _className > 256}) exitWith { -1 };

private _cacheName = if (isServer) then { "A4A_ServerItemTypeCache" } else { "A4A_ClientItemTypeCache" };
private _cache = localNamespace getVariable [_cacheName, createHashMap];
private _key = toLower _className;
if (!isNil {_cache get _key}) exitWith { _cache get _key };

private _itemType = [_className, _useStoredFallback] call jn_fnc_arsenal_itemType;
if (_itemType isEqualTo 23) then { _itemType = 24 };
_cache set [_key, _itemType];
localNamespace setVariable [_cacheName, _cache];
_itemType
