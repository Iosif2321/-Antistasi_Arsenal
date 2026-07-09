/*
 * fn_assignZeus.sqf
 * Server-side: creates a curator (Zeus) module and assigns it to the player.
 */

if (!isServer) exitWith {};
params [["_player", objNull, [objNull]]];

if (isNull _player) exitWith {
    diag_log "A4A_Arsenal: assignZeus abort - player is null";
};

diag_log format ["A4A_Arsenal: assignZeus request for %1 (UID: %2)", name _player, getPlayerUID _player];

// Clean up orphaned curators for this player's UID
private _uid = getPlayerUID _player;
{
    private _owner = getAssignedCuratorUnit _x;
    if (isNull _owner || {getPlayerUID _owner == _uid}) then {
        unassignCurator _x;
        deleteVehicle _x;
        diag_log format ["A4A_Arsenal: cleaned up orphaned curator %1", _x];
    };
} forEach (allCurators select {
    private _owner = getAssignedCuratorUnit _x;
    isNull _owner || {getPlayerUID _owner == _uid}
});

// Already has a working curator assigned?
if (!isNull getAssignedCuratorLogic _player) exitWith {
    _player setVariable ["A4A_Arsenal_HasZeus", true, true];
    "Zeus already assigned." remoteExecCall ["systemChat", _player];
    diag_log format ["A4A_Arsenal: %1 already has Zeus", name _player];
};

// Create curator logic
private _grp = createGroup sideLogic;
private _curator = _grp createUnit ["ModuleCurator_F", [0,0,0], [], 0, "NONE"];
if (isNull _curator) exitWith {
    "Failed to create Zeus module." remoteExecCall ["systemChat", _player];
    diag_log "A4A_Arsenal: assignZeus failed - could not create ModuleCurator_F";
};

_curator setVariable ["Addons", 3, true];
_curator setVariable ["owner", getPlayerUID _player, true];
_curator setVariable ["BIS_fnc_initModules_disableAutoActivation", false, true];

_player assignCurator _curator;
diag_log format ["A4A_Arsenal: assignCurator issued for %1 -> %2", name _player, _curator];

// Wait for assignment to propagate in a spawned scheduled environment to prevent "Suspension not allowed" error
[_player, _curator] spawn {
    params ["_player", "_curator"];
    
    private _timeout = diag_tickTime + 12;
    waitUntil {
        !isNull getAssignedCuratorLogic _player || diag_tickTime > _timeout
    };

    // Dedicated servers can report getAssignedCuratorLogic with delay; double-check via allCurators owner binding.
    private _assignedLogic = getAssignedCuratorLogic _player;
    private _assignedViaOwner = allCurators findIf {getAssignedCuratorUnit _x isEqualTo _player} > -1;
    if (isNull _assignedLogic && {!_assignedViaOwner}) exitWith {
        deleteVehicle _curator;
        "Zeus assignment failed (timeout)." remoteExecCall ["systemChat", _player];
        diag_log format ["A4A_Arsenal: assignCurator timed out for %1 (logic=%2, ownerBinding=%3)", name _player, _assignedLogic, _assignedViaOwner];
    };

    // Broadcast Zeus flag for client-side UI
    _player setVariable ["A4A_Arsenal_HasZeus", true, true];

    private _msg = format ["Zeus assigned to %1", name _player];
    _msg remoteExecCall ["systemChat", _player];
    diag_log format ["A4A_Arsenal: %1", _msg];

    // Add editable objects after delay
    sleep 1;
    if (!isNull _curator) then {
        private _objs = entities [[], [], true, false];
        _curator addCuratorEditableObjects [_objs, true];
        diag_log format ["A4A_Arsenal: Curator editable objects added (%1).", count _objs];
    };
};
