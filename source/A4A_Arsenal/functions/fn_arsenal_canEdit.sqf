/*
 * Returns true when a player can edit arsenal data.
 * A4A_Arsenal_EditorSteamIDs is the primary CBA setting.
 * Access mode 0 requires SteamID only. Access mode 1 requires SteamID and Zeus.
 * A4A_Arsenal_EditorUIDs remains as a legacy missionNamespace fallback.
 */
params [["_unit", player, [objNull]]];

if (isNull _unit) exitWith { false };

private _parseSteamIDs = {
    params ["_raw"];

    if (_raw isEqualType "") exitWith {
        _raw splitString ",; " select { !(_x isEqualTo "") }
    };
    if (_raw isEqualType []) exitWith {
        _raw select { _x isEqualType "" && {!(_x isEqualTo "")} }
    };

    []
};

private _allowedSteamIDs = [missionNamespace getVariable ["A4A_Arsenal_EditorSteamIDs", ""]] call _parseSteamIDs;
if ((count _allowedSteamIDs) == 0) then {
    _allowedSteamIDs = [missionNamespace getVariable ["A4A_Arsenal_EditorUIDs", []]] call _parseSteamIDs;
};
if ((count _allowedSteamIDs) == 0) exitWith { false };

private _playerUID = getPlayerUID _unit;
if !(_playerUID in _allowedSteamIDs) exitWith { false };

private _accessMode = missionNamespace getVariable ["A4A_Arsenal_EditAccessMode", 1];
if !(_accessMode isEqualType 0) then { _accessMode = 1 };

private _requiresZeus = _accessMode isEqualTo 1;
if (_requiresZeus) exitWith {
    if (isNil "A4A_fnc_arsenal_isZeus") exitWith { false };
    [_unit] call A4A_fnc_arsenal_isZeus
};

true
