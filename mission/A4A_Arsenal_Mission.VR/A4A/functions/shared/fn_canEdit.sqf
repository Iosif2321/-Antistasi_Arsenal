params [["_player", objNull, [objNull]]];
if (isNull _player || {getPlayerUID _player isEqualTo ""}) exitWith { false };

private _settings = if (isServer) then {
    localNamespace getVariable ["A4A_ServerSettings", createHashMap]
} else {
    private _clientSettings = localNamespace getVariable ["A4A_ClientSettings", []];
    if !(_clientSettings isEqualType createHashMap) then {
        _clientSettings = call compile preprocessFileLineNumbers "A4A\config\settings.sqf";
        if (_clientSettings isEqualType createHashMap) then {
            localNamespace setVariable ["A4A_ClientSettings", _clientSettings];
        };
    };
    _clientSettings
};
if !(_settings isEqualType createHashMap) exitWith { false };

private _allowed = if (isServer) then {
    _settings getOrDefault ["editorSteamIDs", []]
} else {
    private _rawAllowed = ["editorSteamIDs", _settings getOrDefault ["editorSteamIDs", []]] call A4A_fnc_getSetting;
    if (_rawAllowed isEqualType "") then {
        (_rawAllowed splitString ",; `t`r`n") select {
            _x isNotEqualTo "" && {count _x >= 8} && {count _x <= 32} && {parseNumber _x > 0}
        }
    } else {
        _rawAllowed
    }
};
if !(_allowed isEqualType []) exitWith { false };
private _uid = getPlayerUID _player;
private _uidAllowed = _allowed findIf {_x isEqualType "" && {_x isEqualTo _uid}} >= 0;
if (!_uidAllowed) exitWith { false };

private _mode = if (isServer) then {
    _settings getOrDefault ["editAccessMode", 0]
} else {
    ["editAccessMode", _settings getOrDefault ["editAccessMode", 0]] call A4A_fnc_getSetting
};
if (_mode isEqualTo 1) exitWith { !isNull getAssignedCuratorLogic _player };
_mode isEqualTo 0
