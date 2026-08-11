/*
Author: Jeroen Notenbomer
    Adds items of passed container directly to JNA.
    Usually called on "To Cargo" button inside the JNA interface.

Arguments:
    <OBJECT> Container to add contents directly to JNA.

Scope: Server, Global Arguments, Global Effect
Environment: Any
Public: Yes

Example:
    private _object = missionNamespace getVariable ["jna_object",objNull];
    [_object, _object] remoteExecCall ["jn_fnc_arsenal_cargoToArsenal",2];
*/

#include "..\defineCommon.inc"
#include "..\script_component.hpp"

if (!isServer) exitWith {};

// Snapshot, clear, and canonical commit are one critical section.  Refuse the
// scheduled remoteExec variant because it can yield between those operations;
// the supported caller uses remoteExecCall and therefore runs unscheduled.
if (canSuspend) exitWith {
    diag_log "A4A_Arsenal: rejected scheduled cargoToArsenal call; use remoteExecCall";
};

params [["_object",objNull,[objNull]], ["_arsenalObj",objNull,[objNull]]];

private _networkRequest = isRemoteExecuted;
private _senderOwner = if (_networkRequest) then {remoteExecutedOwner} else {-1};
private _requestPlayer = objNull;
if (_networkRequest) then {
    {
        if (
            isPlayer _x
            && {!(_x isKindOf "VirtualMan_F")}
            && {!(_x isKindOf "HeadlessClient_F")}
            && {!((getPlayerUID _x) isEqualTo "")}
            && {(owner _x) isEqualTo _senderOwner}
        ) exitWith {_requestPlayer = _x};
    } forEach allPlayers;
} else {
    if (hasInterface && {!isDedicated} && {!isNull player} && {isPlayer player} && {local player}) then {
        _requestPlayer = player;
        _senderOwner = clientOwner;
    };
};

private _sessions = localNamespace getVariable ["A4A_Arsenal_ServerSessions", createHashMap];
private _session = _sessions getOrDefault [str _senderOwner, []];
private _boundObject = _session param [0, objNull, [objNull]];
private _arsenalID = _session param [1, "", [""]];
private _boundUID = _session param [3, "", [""]];
private _serverObjects = localNamespace getVariable ["A4A_Arsenal_ServerObjects", []];
if (
    isNull _requestPlayer
    || {count _session < 4}
    || {isNull _object}
    || {!(_object isEqualTo _boundObject)}
    || {!isNull _arsenalObj && {!(_arsenalObj isEqualTo _boundObject)}}
    || {!(_boundObject in _serverObjects)}
    || {_arsenalID isEqualTo ""}
    || {!(_boundUID isEqualTo getPlayerUID _requestPlayer)}
    || {!alive _requestPlayer}
    || {_requestPlayer distance _boundObject > 15}
) exitWith {
    diag_log format ["A4A_Arsenal: rejected cargoToArsenal from owner %1; sender/session/object binding failed", _senderOwner];
};

if (isNil { // Run in unschedule scope.
    if (_object getVariable ["A4A_JNA_cargoToArsenal_busy",false]) then {
        nil;  // will lead to exit.
    } else {
        _object setVariable ["A4A_JNA_cargoToArsenal_busy",true];
        0;  // not nil, will allow script to continue.
    };
}) exitWith {};  //  // Silent exit, likely due to spamming

// Grab contents before being cleared.
private _array = _object call jn_fnc_arsenal_cargoToArray;
private _defaultData = [[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[]];
private _serverData = localNamespace getVariable ["A4A_Arsenal_ServerData", createHashMap];
private _targetData = +(_serverData getOrDefault [_arsenalID, _defaultData]);
if (count _array != 27 || {count _targetData != 27}) exitWith {
    _object setVariable ["A4A_JNA_cargoToArsenal_busy",false];
    diag_log format ["A4A_Arsenal: cargoToArsenal aborted for '%1'; invalid source/canonical shape", _arsenalID];
};

// Normalize a server-observed physical cargo snapshot into canonical deltas.
private _deltas = [];
private _sourceValid = true;
{
    {
        private _item = _x select 0;
        private _amount = _x select 1;
        if (
            _item isEqualType ""
            && {!(_item isEqualTo "")}
            && {_amount isEqualType 0}
            && {finite _amount}
            && {_amount > 0}
            && {_amount isEqualTo floor _amount}
        ) then {
            // TFAR fix
            private _radioName = getText(configfile >> "CfgWeapons" >> _item >> "tf_parent");
            if !(_radioName isEqualTo "") then { _item = _radioName };

            // Weapon Stack fix (only for actual weapons with muzzles)
            if (isArray (configfile >> "CfgWeapons" >> _item >> "muzzles")) then {
                private _weaponname = getText(configfile >> "CfgWeapons" >> _item >> "baseWeapon");
                if !(_weaponname isEqualTo "") then { _item = _weaponname };
            };

            // RHS Sight Stack fix
            private _sightname = getText(configfile >> "CfgWeapons" >> _item >> "rhs_optic_base");
            if !(_sightname isEqualTo "") then { _item = _sightname };

            // ACRE fix
            private _radioName2 = getText(configfile >> "CfgVehicles" >> _item >> "acre_baseClass");
            if !(_radioName2 isEqualTo "") then { _item = _radioName2 };

            // Derive the destination only after all server-side class
            // canonicalization. Never trust the source bucket as authority.
            private _targetIndex = [_item, false] call jn_fnc_arsenal_itemType;
            if (_targetIndex == IDC_RSCDISPLAYARSENAL_TAB_CARGOMAG) then { _targetIndex = IDC_RSCDISPLAYARSENAL_TAB_CARGOMAGALL };
            if (_targetIndex < 0 || {_targetIndex >= 27}) then {
                _sourceValid = false;
            } else {
                _targetData set [_targetIndex, [_targetData select _targetIndex, [_item, _amount]] call jn_fnc_arsenal_addToArray];
                _deltas pushBack [_targetIndex, _item, _amount];
            };
        } else {
            _sourceValid = false;
        };
        if (!_sourceValid) exitWith {};
    } forEach _x;
    if (!_sourceValid) exitWith {};
} forEach _array;

if (!_sourceValid) exitWith {
    _object setVariable ["A4A_JNA_cargoToArsenal_busy",false];
    diag_log format ["A4A_Arsenal: cargoToArsenal aborted for '%1'; invalid or unclassified source row", _arsenalID];
};

// The destructive clear must never create a profile that the next startup
// rejects. Validate the complete post-merge candidate before clear or commit.
private _candidateValid = true;
private _candidateEntryCount = 0;
private _candidateClasses = createHashMap;
{
    if !(_x isEqualType []) exitWith {_candidateValid = false};
    _candidateEntryCount = _candidateEntryCount + count _x;
    if (_candidateEntryCount > 10000) exitWith {_candidateValid = false};
    {
        if !(_x isEqualType [] && {count _x == 2}) exitWith {_candidateValid = false};
        private _entryClass = _x select 0;
        private _entryAmount = _x select 1;
        if !(
            _entryClass isEqualType ""
            && {!(_entryClass isEqualTo "")}
            && {count _entryClass <= 256}
            && {_entryAmount isEqualType 0}
            && {finite _entryAmount}
            && {_entryAmount isEqualTo floor _entryAmount}
            && {_entryAmount == -1 || {_entryAmount > 0 && {_entryAmount <= 100000000}}}
        ) exitWith {_candidateValid = false};
        private _entryKey = toLower _entryClass;
        if (_candidateClasses getOrDefault [_entryKey, false]) exitWith {_candidateValid = false};
        _candidateClasses set [_entryKey, true];
    } forEach _x;
    if (!_candidateValid) exitWith {};
} forEach _targetData;
if !(_candidateValid) exitWith {
    _object setVariable ["A4A_JNA_cargoToArsenal_busy",false];
    diag_log format ["A4A_Arsenal: cargoToArsenal aborted for '%1'; post-merge candidate violates persistence bounds", _arsenalID];
};

// Destructive clear happens only after authorization and successful snapshot validation.
clearMagazineCargoGlobal _object;
clearItemCargoGlobal _object;
clearWeaponCargoGlobal _object;
clearBackpackCargoGlobal _object;

_serverData set [_arsenalID, _targetData];
localNamespace setVariable ["A4A_Arsenal_ServerData", _serverData];
private _serverRevisions = localNamespace getVariable ["A4A_Arsenal_ServerRevisions", createHashMap];
_serverRevisions set [_arsenalID, (_serverRevisions getOrDefault [_arsenalID, 0]) + 1];
localNamespace setVariable ["A4A_Arsenal_ServerRevisions", _serverRevisions];
// Compact deltas below replace a full public 27-bucket broadcast.
server setVariable [format ["jna_dataList_%1", _arsenalID], _targetData];
profileNamespace setVariable [format ["A4A_ArsenalData_%1", _arsenalID], _targetData];
localNamespace setVariable ["A4A_Arsenal_ProfileSaveAuthorized", true];
[] call A4A_fnc_arsenal_scheduleProfileSave;
localNamespace setVariable ["A4A_Arsenal_ProfileSaveAuthorized", false];

private _hostSession = _sessions getOrDefault [str clientOwner, []];
if (!isDedicated && {hasInterface} && {!isNil "jna_dataList"} && {count _hostSession >= 2} && {(_hostSession select 1) isEqualTo _arsenalID}) then {
    {
        _x params ["_index", "_item", "_amount"];
        jna_dataList set [_index, [jna_dataList select _index, [_item, _amount]] call jn_fnc_arsenal_addToArray];
        // Reuse the dispatcher client/UI continuation without reapplying the
        // canonical delta.  The private capability is required because the
        // nested call retains the original remote-execution context.
        private _previousDispatcherAuth = localNamespace getVariable ["A4A_Arsenal_ServerDispatcherAuthorized", false];
        localNamespace setVariable ["A4A_Arsenal_ServerDispatcherAuthorized", true];
        ["UpdateItemAdd", [_index, _item, _amount, false, "CargoToArsenal", _boundUID, _arsenalID]] call jn_fnc_arsenal;
        localNamespace setVariable ["A4A_Arsenal_ServerDispatcherAuthorized", _previousDispatcherAuth];
    } forEach _deltas;
};

private _remoteTargets = [];
{
    private _viewerOwner = parseNumber _x;
    private _viewerSession = _sessions getOrDefault [_x, []];
    if (_viewerOwner > 2 && {count _viewerSession >= 4} && {(_viewerSession select 1) isEqualTo _arsenalID}) then {
        private _viewerUID = _viewerSession select 3;
        if (allPlayers findIf {
            isPlayer _x
            && {(owner _x) isEqualTo _viewerOwner}
            && {(getPlayerUID _x) isEqualTo _viewerUID}
        } >= 0) then {
            _remoteTargets pushBackUnique _viewerOwner;
        };
    };
} forEach (keys _sessions);
if !(_remoteTargets isEqualTo []) then {
    {
        _x params ["_index", "_item", "_amount"];
        ["UpdateItemAdd", [_index, _item, _amount, true, "CargoToArsenal", _boundUID, _arsenalID]] remoteExecCall ["jn_fnc_arsenal", _remoteTargets];
    } forEach _deltas;
};

if (!isNull _object) then {
    _object setVariable ["A4A_JNA_cargoToArsenal_busy",false];
};
diag_log format ["A4A_Arsenal: cargoToArsenal accepted for owner %1, arsenal '%2', %3 deltas", _senderOwner, _arsenalID, count _deltas];
