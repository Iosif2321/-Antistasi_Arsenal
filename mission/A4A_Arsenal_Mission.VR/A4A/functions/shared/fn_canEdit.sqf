params [["_player", objNull, [objNull]]];
if (isNull _player || {getPlayerUID _player isEqualTo ""}) exitWith { false };

private _settings = if (isServer) then {
    localNamespace getVariable ["A4A_ServerSettings", createHashMap]
} else {
    call compile preprocessFileLineNumbers "A4A\config\settings.sqf"
};
if !(_settings isEqualType createHashMap) exitWith { false };

private _allowed = _settings getOrDefault ["editorSteamIDs", []];
if !(_allowed isEqualType []) exitWith { false };
private _uid = getPlayerUID _player;
private _uidAllowed = _allowed findIf {_x isEqualType "" && {_x isEqualTo _uid}} >= 0;
if (!_uidAllowed) exitWith { false };

private _mode = _settings getOrDefault ["editAccessMode", 0];
if (_mode isEqualTo 1) exitWith { !isNull getAssignedCuratorLogic _player };
_mode isEqualTo 0

