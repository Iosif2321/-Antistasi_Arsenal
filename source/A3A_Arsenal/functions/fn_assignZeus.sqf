/*
 * fn_assignZeus.sqf
 * Server-side: creates a curator (Zeus) module and assigns it to the player.
 *
 * Parameter:
 *   _player — OBJECT — the player requesting Zeus
 *
 * Called via remoteExecCall from the client key sequence handler.
 */

if (!isServer) exitWith { diag_log "A3A_Arsenal: assignZeus ignored (not server)"; };
params [["_player", objNull, [objNull]]];

if (isNull _player) exitWith {
    diag_log "A3A_Arsenal: assignZeus abort - player is null";
};

if (!isPlayer _player) exitWith {
    diag_log "A3A_Arsenal: assignZeus abort - object is not a player";
};

// Only allow the player to request Zeus for themselves (prevent abuse)
if (isNil "remoteExecutedOwner" || {!(remoteExecutedOwner isEqualTo (owner _player))}) exitWith {
    diag_log format ["A3A_Arsenal: assignZeus rejected - caller %1 != player owner %2", remoteExecutedOwner, owner _player];
};

// Already has curator assigned?
if (!isNull (getAssignedCuratorLogic _player)) exitWith {
    "Zeus already assigned." remoteExecCall ["systemChat", _player];
    diag_log format ["A3A_Arsenal: %1 already has Zeus", name _player];
};

// Create curator logic (vanilla - works with ZEN/ACE)
private _grp = createGroup sideLogic;
private _curator = _grp createUnit ["ModuleCurator_F", [0,0,0], [], 0, "NONE"];
if (isNull _curator) exitWith {
    "Failed to create Zeus module." remoteExecCall ["systemChat", _player];
    diag_log "A3A_Arsenal: assignZeus failed - could not create ModuleCurator_F";
};

// Allow all addons (3 = all)
_curator setVariable ["Addons", 3, true];
_curator setVariable ["BIS_fnc_initModules_disableAutoActivation", false, true];

// Assign to player
_player assignCurator _curator;
diag_log format ["A3A_Arsenal: assignCurator called for %1 (UID: %2)", name _player, getPlayerUID _player];

// Broadcast Zeus flag for client-side UI (getAssignedCuratorLogic can lag on client)
_player setVariable ["A3A_Arsenal_HasZeus", true, true];

// Notify (JIP-safe: pass target so late-joining player gets message)
private _msg = format ["Zeus assigned to %1", name _player];
[_msg] remoteExecCall ["systemChat", _player];
diag_log format ["A3A_Arsenal: %1 (UID: %2)", _msg, getPlayerUID _player];

// Add editable objects after delay (curator needs time to initialize)
[_curator] spawn {
    params ["_cur"];
    sleep 1;
    if (!isNull _cur) then {
        private _objs = entities [[], [], true, false];
        _cur addCuratorEditableObjects [_objs, true];
        diag_log format ["A3A_Arsenal: Curator editable objects added (%1).", count _objs];
    };
};
