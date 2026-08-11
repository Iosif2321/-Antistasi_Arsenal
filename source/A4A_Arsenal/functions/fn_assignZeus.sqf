/*
 * fn_assignZeus.sqf
 * Server-side: creates a curator (Zeus) module and assigns it to the player.
 */

if (!isServer) exitWith {};
if (isRemoteExecuted && {canSuspend}) exitWith {
    diag_log format ["A4A_Arsenal: rejected scheduled Zeus request from owner %1", remoteExecutedOwner];
};
params [["_player", objNull, [objNull]]];

if (
    isNull _player
    || {!isPlayer _player}
    || {_player isKindOf "VirtualMan_F"}
    || {_player isKindOf "HeadlessClient_F"}
    || {(getPlayerUID _player) isEqualTo ""}
) exitWith {
    diag_log "A4A_Arsenal: assignZeus abort - player is null";
};

private _localHostRequest = !isRemoteExecuted && {hasInterface} && {!isDedicated} && {local _player};
if (!isRemoteExecuted && {!_localHostRequest}) exitWith {
    diag_log "A4A_Arsenal: assignZeus rejected non-network invocation";
};
private _senderOwner = if (isRemoteExecuted) then {remoteExecutedOwner} else {owner _player};
if (_senderOwner != owner _player) exitWith {
    diag_log format ["A4A_Arsenal: assignZeus rejected sender/object mismatch (sender=%1, playerOwner=%2)", _senderOwner, owner _player];
};

private _uid = getPlayerUID _player;
private _parseSteamIDs = {
    params ["_raw"];
    if (_raw isEqualType "") exitWith {
        _raw splitString ",; " select {!(_x isEqualTo "")}
    };
    if (_raw isEqualType []) exitWith {
        _raw select {_x isEqualType "" && {!(_x isEqualTo "")}}
    };
    []
};
private _allowedSteamIDs = [localNamespace getVariable ["A4A_Arsenal_ServerEditorSteamIDs", []]] call _parseSteamIDs;
if !(_uid in _allowedSteamIDs) exitWith {
    diag_log format ["A4A_Arsenal: assignZeus denied for sender %1 (UID: %2 is not allowlisted)", _senderOwner, _uid];
    if (_localHostRequest) then {systemChat "Zeus access denied."} else {["ServerNotify", ["Zeus access denied."]] remoteExecCall ["jn_fnc_arsenal", _senderOwner]};
};

private _serverArsenalObjects = localNamespace getVariable ["A4A_Arsenal_ServerObjects", []];
if ((_serverArsenalObjects findIf {!isNull _x && {_player distance _x <= 50}}) < 0) exitWith {
    diag_log format ["A4A_Arsenal: assignZeus denied for %1; no initialized arsenal within 50 m", name _player];
    if (_localHostRequest) then {systemChat "Zeus access denied: no arsenal nearby."} else {["ServerNotify", ["Zeus access denied: no arsenal nearby."]] remoteExecCall ["jn_fnc_arsenal", _senderOwner]};
};

diag_log format ["A4A_Arsenal: sender-bound assignZeus request for %1 (UID: %2)", name _player, _uid];

// A repeated request must not delete the currently assigned addon curator.
// Dedicated clients can have a stale local cache, so the server is authoritative.
if (!isNull getAssignedCuratorLogic _player) exitWith {
    _player setVariable ["A4A_Arsenal_HasZeus", true, true];
    if (_localHostRequest) then {systemChat "Zeus already assigned."} else {["ServerNotify", ["Zeus already assigned."]] remoteExecCall ["jn_fnc_arsenal", _senderOwner]};
    diag_log format ["A4A_Arsenal: %1 already has Zeus", name _player];
};

// Clean up only curator modules created by this addon for this player's UID.
// Never delete unrelated unassigned mission curator modules.
{
    unassignCurator _x;
    deleteVehicle _x;
    diag_log format ["A4A_Arsenal: cleaned up prior addon curator %1 for UID %2", _x, _uid];
} forEach (allCurators select {
    private _addonOwnerUID = _x getVariable ["A4A_Arsenal_OwnerUID", _x getVariable ["owner", ""]];
    _addonOwnerUID isEqualTo _uid
});

// Create curator logic
private _grp = createGroup sideLogic;
private _curator = _grp createUnit ["ModuleCurator_F", [0,0,0], [], 0, "NONE"];
if (isNull _curator) exitWith {
    if (_localHostRequest) then {systemChat "Failed to create Zeus module."} else {["ServerNotify", ["Failed to create Zeus module."]] remoteExecCall ["jn_fnc_arsenal", owner _player]};
    diag_log "A4A_Arsenal: assignZeus failed - could not create ModuleCurator_F";
};

_curator setVariable ["Addons", 3, true];
_curator setVariable ["owner", getPlayerUID _player, true];
_curator setVariable ["A4A_Arsenal_OwnerUID", _uid, true];
_curator setVariable ["BIS_fnc_initModules_disableAutoActivation", false, true];

_player assignCurator _curator;
diag_log format ["A4A_Arsenal: assignCurator issued for %1 -> %2", name _player, _curator];

// Wait for assignment to propagate in a spawned scheduled environment to prevent "Suspension not allowed" error
[_player, _curator, _localHostRequest] spawn {
    params ["_player", "_curator", "_localHostRequest"];
    
    private _timeout = diag_tickTime + 12;
    waitUntil {
        !isNull getAssignedCuratorLogic _player || diag_tickTime > _timeout
    };

    // Dedicated servers can report getAssignedCuratorLogic with delay; double-check via allCurators owner binding.
    private _assignedLogic = getAssignedCuratorLogic _player;
    private _assignedViaOwner = allCurators findIf {getAssignedCuratorUnit _x isEqualTo _player} > -1;
    if (isNull _assignedLogic && {!_assignedViaOwner}) exitWith {
        deleteVehicle _curator;
        if (_localHostRequest) then {systemChat "Zeus assignment failed (timeout)."} else {["ServerNotify", ["Zeus assignment failed (timeout)."]] remoteExecCall ["jn_fnc_arsenal", owner _player]};
        diag_log format ["A4A_Arsenal: assignCurator timed out for %1 (logic=%2, ownerBinding=%3)", name _player, _assignedLogic, _assignedViaOwner];
    };

    // Broadcast Zeus flag for client-side UI
    _player setVariable ["A4A_Arsenal_HasZeus", true, true];

    private _msg = format ["Zeus assigned to %1", name _player];
    if (_localHostRequest) then {systemChat _msg} else {["ServerNotify", [_msg]] remoteExecCall ["jn_fnc_arsenal", owner _player]};
    diag_log format ["A4A_Arsenal: %1", _msg];

    // Add editable objects after delay
    sleep 1;
    if (!isNull _curator) then {
        private _objs = entities [[], [], true, false];
        _curator addCuratorEditableObjects [_objs, true];
        diag_log format ["A4A_Arsenal: Curator editable objects added (%1).", count _objs];
    };
};
