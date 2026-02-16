/*
 * fn_assignZeus.sqf
 * Server-side: creates a curator (Zeus) module and assigns it to the player.
 */

if (!isServer) exitWith {};
params [["_player", objNull, [objNull]]];

if (isNull _player) exitWith {
    diag_log "A3A_Arsenal: assignZeus abort - player is null";
};

diag_log format ["A3A_Arsenal: assignZeus request for %1 (UID: %2)", name _player, getPlayerUID _player];

// Already has curator assigned?
if (!isNull getAssignedCuratorLogic _player) exitWith {
    _player setVariable ["A3A_Arsenal_HasZeus", true, true];
    "Zeus already assigned." remoteExecCall ["systemChat", _player];
    diag_log format ["A3A_Arsenal: %1 already has Zeus", name _player];
};

// Create curator logic
private _grp = createGroup sideLogic;
private _curator = _grp createUnit ["ModuleCurator_F", [0,0,0], [], 0, "NONE"];
if (isNull _curator) exitWith {
    "Failed to create Zeus module." remoteExecCall ["systemChat", _player];
    diag_log "A3A_Arsenal: assignZeus failed - could not create ModuleCurator_F";
};

_curator setVariable ["Addons", 3, true];
_curator setVariable ["BIS_fnc_initModules_disableAutoActivation", false, true];

_player assignCurator _curator;

// Broadcast Zeus flag for client-side UI
_player setVariable ["A3A_Arsenal_HasZeus", true, true];

private _msg = format ["Zeus assigned to %1", name _player];
_msg remoteExecCall ["systemChat", _player];
diag_log format ["A3A_Arsenal: %1", _msg];

// Add editable objects after delay
[_curator] spawn {
    params ["_cur"];
    sleep 1;
    if (!isNull _cur) then {
        private _objs = entities [[], [], true, false];
        _cur addCuratorEditableObjects [_objs, true];
        diag_log format ["A3A_Arsenal: Curator editable objects added (%1).", count _objs];
    };
};
