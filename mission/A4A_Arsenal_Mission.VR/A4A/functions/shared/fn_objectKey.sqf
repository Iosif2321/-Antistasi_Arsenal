/*
    Return a stable mission-lifetime object key. Multiplayer authority requires
    a real network ID; singleplayer may legitimately expose only 0:0, so the
    local object string is used there on the shared server/interface process.
*/
params [["_object", objNull, [objNull]]];
if (isNull _object) exitWith { "" };

private _key = netId _object;
if (_key isNotEqualTo "" && {_key isNotEqualTo "0:0"}) exitWith { _key };
if (isMultiplayer) exitWith { "" };

format ["sp:%1", str _object]
