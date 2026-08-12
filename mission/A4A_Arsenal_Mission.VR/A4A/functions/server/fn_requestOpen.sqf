params [
    ["_object", objNull, [objNull]],
    ["_requestNonce", "", [""]]
];

if (!isServer) exitWith {};
if (isRemoteExecuted && {canSuspend}) exitWith {
    diag_log format ["[A4A Mission] Rejected scheduled open request from owner %1", remoteExecutedOwner];
};

private _localHostCall = !isRemoteExecuted && {hasInterface} && {!isNull player};
if (!isRemoteExecuted && {!_localHostCall}) exitWith {
    diag_log "[A4A Mission] Rejected non-network open request";
};

private _senderOwner = if (_localHostCall) then { clientOwner } else { remoteExecutedOwner };
private _requestPlayer = [_senderOwner, _localHostCall] call A4A_fnc_resolveRemotePlayer;
if (
    isNull _requestPlayer ||
    {isNull _object} ||
    {_requestNonce isEqualTo ""} ||
    {count _requestNonce > 128} ||
    {!alive _requestPlayer} ||
    {getPlayerUID _requestPlayer isEqualTo ""}
) exitWith {};

private _objectKey = netId _object;
private _registry = localNamespace getVariable ["A4A_ServerRegistry", createHashMap];
if (isNil {_registry get _objectKey}) exitWith {};
private _canonical = _registry get _objectKey;
if !(_canonical isEqualType [] && {count _canonical isEqualTo 3} && {(_canonical select 0) isEqualTo _object}) exitWith {};
_canonical params ["_canonicalObject", "_arsenalId", "_threshold"];

private _ready = localNamespace getVariable ["A4A_ServerReady", createHashMap];
private _settings = localNamespace getVariable ["A4A_ServerSettings", createHashMap];
private _maxDistance = _settings getOrDefault ["interactionDistance", 5];
if (!(_ready getOrDefault [_arsenalId, false]) || {_requestPlayer distance _object > _maxDistance}) exitWith {};

private _dataById = localNamespace getVariable ["A4A_ServerData", createHashMap];
private _revisions = localNamespace getVariable ["A4A_ServerRevisions", createHashMap];
if (isNil {_dataById get _arsenalId} || {isNil {_revisions get _arsenalId}}) exitWith {};
private _data = _dataById get _arsenalId;
private _revision = _revisions get _arsenalId;
if !(_data isEqualType [] && {count _data isEqualTo 27} && {_revision isEqualType 0} && {_revision >= 0}) exitWith {};

private _ownerKey = str _senderOwner;
private _generations = localNamespace getVariable ["A4A_ServerSessionGenerations", createHashMap];
private _generation = (_generations getOrDefault [_ownerKey, 0]) + 1;
_generations set [_ownerKey, _generation];
localNamespace setVariable ["A4A_ServerSessionGenerations", _generations];

private _lifetime = _settings getOrDefault ["sessionLifetime", 30];
private _session = createHashMapFromArray [
    ["object", _object],
    ["objectKey", _objectKey],
    ["arsenalId", _arsenalId],
    ["threshold", _threshold],
    ["playerUID", getPlayerUID _requestPlayer],
    ["requestNonce", _requestNonce],
    ["generation", _generation],
    ["revision", _revision],
    ["saveEligibleRevision", _revision],
    ["openedAt", diag_tickTime],
    ["expiresAt", diag_tickTime + _lifetime]
];
private _sessions = localNamespace getVariable ["A4A_ServerSessions", createHashMap];
_sessions set [_ownerKey, _session];
localNamespace setVariable ["A4A_ServerSessions", _sessions];

private _snapshot = parseSimpleArray str _data;
private _payload = [_object, _requestNonce, _generation, _revision, +_snapshot, "Auto"];
if (_localHostCall) then {
    _payload call A4A_fnc_receiveOpen;
} else {
    _payload remoteExecCall ["A4A_fnc_receiveOpen", _senderOwner];
};

