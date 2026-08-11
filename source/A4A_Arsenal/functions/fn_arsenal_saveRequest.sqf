/*
 * Sender-bound server endpoint for the editor's full JNA snapshot.
 * The server derives identity and arsenal ID; client-supplied names/UIDs are
 * deliberately absent from the protocol.
 */

params [
    ["_arsenalObj", objNull, [objNull]],
    ["_dataList", [], [[]]],
    ["_localPlayer", objNull, [objNull]],
    ["_oneShotImport", false, [true]]
];

if (!isServer) exitWith {};

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
        ) exitWith {
            _requestPlayer = _x;
        };
    } forEach allPlayers;
} else {
    if (hasInterface && {!isNull _localPlayer} && {local _localPlayer}) then {
        _requestPlayer = _localPlayer;
        // Keep the same local/SP session key chosen by requestOpen.
        _senderOwner = clientOwner;
    };
};

private _reply = {
    params ["_message"];
    if (_networkRequest) then {
        ["ServerNotify", [_message]] remoteExecCall ["jn_fnc_arsenal", _senderOwner];
    } else {
        systemChat _message;
    };
};

if (isNull _requestPlayer) exitWith {
    diag_log format ["A4A_Arsenal: editor save rejected; no player owns client %1", _senderOwner];
};
if (canSuspend) exitWith {
    diag_log format ["A4A_Arsenal: editor save rejected for owner %1; scheduled execution is not atomic", _senderOwner];
    ["Arsenal save rejected: use the normal editor/import action."] call _reply;
};
private _serverArsenalRegistry = localNamespace getVariable ["A4A_Arsenal_ServerRegistry", []];
private _registryIndex = _serverArsenalRegistry findIf {
    count _x >= 2 && {(_x select 0) isEqualTo _arsenalObj}
};
if (
    isNull _arsenalObj
    || {_registryIndex < 0}
    || {_requestPlayer distance _arsenalObj > 10}
) exitWith {
    diag_log format ["A4A_Arsenal: editor save rejected for %1; invalid arsenal object or distance", name _requestPlayer];
    ["Arsenal save rejected: invalid target or distance."] call _reply;
};
private _readyObjects = localNamespace getVariable ["A4A_Arsenal_ServerReadyObjects", []];
if !(_arsenalObj in _readyObjects) exitWith {
    diag_log format ["A4A_Arsenal: editor save rejected for %1; canonical data is not ready", name _requestPlayer];
    ["Arsenal save rejected: server data is still loading."] call _reply;
};

if (isNil "A4A_fnc_arsenal_canEdit" || {!([_requestPlayer] call A4A_fnc_arsenal_canEdit)}) exitWith {
    diag_log format ["A4A_Arsenal: editor save denied for %1 (UID: %2)", name _requestPlayer, getPlayerUID _requestPlayer];
    ["Arsenal save denied: editor permission required."] call _reply;
};

private _sessions = localNamespace getVariable ["A4A_Arsenal_ServerSessions", createHashMap];
private _session = _sessions getOrDefault [str _senderOwner, []];
private _canonicalID = (_serverArsenalRegistry select _registryIndex) select 1;
private _validBoundSession =
    count _session >= 4
    && {(_session select 0) isEqualTo _arsenalObj}
    && {(_session select 1) isEqualTo _canonicalID}
    && {(_session select 3) isEqualTo getPlayerUID _requestPlayer};
if (!_validBoundSession && {!_oneShotImport}) exitWith {
    diag_log format ["A4A_Arsenal: editor save rejected for %1; request is outside the bound arsenal session", name _requestPlayer];
    ["Arsenal save rejected: reopen this arsenal before saving."] call _reply;
};
private _ephemeralSession = !_validBoundSession;
private _serverRevisions = localNamespace getVariable ["A4A_Arsenal_ServerRevisions", createHashMap];
private _currentRevision = _serverRevisions getOrDefault [_canonicalID, 0];
if (_ephemeralSession) then {
    // A direct import action is already bound to a registered nearby object and
    // an authorized human. Give that one request a current server baseline;
    // do not leave a viewer session behind or open an arsenal UI.
    _session = [_arsenalObj, _canonicalID, diag_tickTime, getPlayerUID _requestPlayer, _currentRevision];
};
private _expectedRevision = _session param [4, -1, [0]];
if (_expectedRevision != _currentRevision) exitWith {
    diag_log format ["A4A_Arsenal: editor save rejected for %1; stale revision expected=%2 current=%3", name _requestPlayer, _expectedRevision, _currentRevision];
    ["Arsenal changed after the editor opened. Reopen it before saving."] call _reply;
};

// Full snapshots are intentionally validated in an unscheduled server context.
// Rate-limit authorized callers so a valid but repeated large payload cannot
// monopolize consecutive frames or repeatedly invalidate every viewer.
private _saveRateLimits = localNamespace getVariable ["A4A_Arsenal_ServerSaveRateLimits", createHashMap];
private _saveRateKey = getPlayerUID _requestPlayer;
private _saveNow = diag_tickTime;
private _lastSaveAttempt = _saveRateLimits getOrDefault [_saveRateKey, -1000];
if ((_saveNow - _lastSaveAttempt) < 2) exitWith {
    diag_log format ["A4A_Arsenal: editor save rate-limited for %1", name _requestPlayer];
    ["Arsenal save rejected: wait two seconds before another full save."] call _reply;
};
_saveRateLimits set [_saveRateKey, _saveNow];
localNamespace setVariable ["A4A_Arsenal_ServerSaveRateLimits", _saveRateLimits];

if ((count _dataList) != 27) exitWith {
    diag_log format ["A4A_Arsenal: editor save rejected for %1; outer bucket count is %2, expected 27", name _requestPlayer, count _dataList];
    ["Arsenal save rejected: invalid bucket count."] call _reply;
};

private _valid = true;
private _invalidReason = "";
private _totalEntries = 0;
private _validatedData = [];
private _seenClasses = createHashMap;

{
    private _bucket = _x;
	private _bucketIndex = _forEachIndex;
    if !(_bucket isEqualType []) exitWith {
        _valid = false;
        _invalidReason = format ["bucket %1 is not an array", _bucketIndex];
    };

    private _validatedBucket = [];
    {
        private _entry = _x;
        if !(_entry isEqualType [] && {count _entry == 2}) exitWith {
            _valid = false;
            _invalidReason = "entry is not an exact [class, amount] pair";
        };

        private _className = _entry select 0;
        private _amount = _entry select 1;
        if !(
            _className isEqualType ""
            && {!(_className isEqualTo "")}
            && {count _className <= 256}
            && {_amount isEqualType 0}
            && {finite _amount}
            && {floor _amount == _amount}
            && {_amount == -1 || {_amount > 0 && {_amount <= 100000000}}}
        ) exitWith {
            _valid = false;
            _invalidReason = "entry contains an invalid class name or amount";
        };

        private _knownClass =
            isClass (configFile >> "CfgWeapons" >> _className)
            || {isClass (configFile >> "CfgMagazines" >> _className)}
            || {isClass (configFile >> "CfgVehicles" >> _className)}
            || {isClass (configFile >> "CfgGlasses" >> _className)};
        if (!_knownClass) exitWith {
            _valid = false;
            _invalidReason = format ["unknown class '%1'", _className];
        };
        private _derivedIndex = [_className, false] call jn_fnc_arsenal_itemType;
        if (_derivedIndex != _bucketIndex) exitWith {
            _valid = false;
            _invalidReason = format ["class '%1' belongs to bucket %2, not %3", _className, _derivedIndex, _bucketIndex];
        };

        private _classKey = toLower _className;
        if (_seenClasses getOrDefault [_classKey, false]) exitWith {
            _valid = false;
            _invalidReason = format ["duplicate class '%1' in full snapshot", _className];
        };

        _seenClasses set [_classKey, true];
        _validatedBucket pushBack [_className, _amount];
        _totalEntries = _totalEntries + 1;
        if (_totalEntries > 10000) exitWith {
            _valid = false;
            _invalidReason = "payload exceeds 10000 entries";
        };
    } forEach _bucket;

    if (!_valid) exitWith {};
    _validatedData pushBack _validatedBucket;
} forEach _dataList;

if (!_valid || {count _validatedData != 27}) exitWith {
    diag_log format ["A4A_Arsenal: editor save rejected for %1: %2", name _requestPlayer, _invalidReason];
    ["Arsenal save rejected: invalid data."] call _reply;
};

private _arsenalID = _canonicalID;
private _serverKey = format ["jna_dataList_%1", _arsenalID];
private _profileKey = format ["A4A_ArsenalData_%1", _arsenalID];

private _serverData = localNamespace getVariable ["A4A_Arsenal_ServerData", createHashMap];
_serverData set [_arsenalID, _validatedData];
localNamespace setVariable ["A4A_Arsenal_ServerData", _serverData];
_currentRevision = _currentRevision + 1;
_serverRevisions set [_arsenalID, _currentRevision];
localNamespace setVariable ["A4A_Arsenal_ServerRevisions", _serverRevisions];
if (!_ephemeralSession) then {
    _session set [4, _currentRevision];
    _sessions set [str _senderOwner, _session];
};
localNamespace setVariable ["A4A_Arsenal_ServerSessions", _sessions];
// Compatibility mirror only; never read as server authority.
server setVariable [_serverKey, _validatedData, true];
profileNamespace setVariable [_profileKey, _validatedData];
localNamespace setVariable ["A4A_Arsenal_ProfileSaveAuthorized", true];
[] call A4A_fnc_arsenal_scheduleProfileSave;
localNamespace setVariable ["A4A_Arsenal_ProfileSaveAuthorized", false];

// A full snapshot replacement invalidates every other viewer's baseline. Drop
// those private sessions before notifying their UI; any in-flight stale delta
// is then rejected by the server and concurrent editors cannot last-write-win.
private _invalidateMessage = format ["Arsenal '%1' was replaced by an editor. Reopen it to continue.", _arsenalID];
{
    private _viewerKey = _x;
    private _viewerSession = _sessions getOrDefault [_viewerKey, []];
    if (
        !(_viewerKey isEqualTo str _senderOwner)
        && {count _viewerSession >= 2}
        && {(_viewerSession select 1) isEqualTo _arsenalID}
    ) then {
        private _viewerOwner = parseNumber _viewerKey;
        _sessions deleteAt _viewerKey;
        if (_viewerOwner isEqualTo clientOwner && {hasInterface} && {!isDedicated}) then {
            localNamespace setVariable ["A4A_Arsenal_ServerDispatcherAuthorized", true];
            ["ServerInvalidate", [_invalidateMessage]] call jn_fnc_arsenal;
            localNamespace setVariable ["A4A_Arsenal_ServerDispatcherAuthorized", false];
        } else {
            if (_viewerOwner > 2) then {
                ["ServerInvalidate", [_invalidateMessage]] remoteExecCall ["jn_fnc_arsenal", _viewerOwner];
            };
        };
    };
} forEach (+(keys _sessions));
localNamespace setVariable ["A4A_Arsenal_ServerSessions", _sessions];

[format ["Arsenal '%1' saved.", _arsenalID]] call _reply;
diag_log format ["A4A_Arsenal: editor save accepted for %1 (UID: %2), arsenal '%3', %4 entries", name _requestPlayer, getPlayerUID _requestPlayer, _arsenalID, _totalEntries];
