params [
    ["_object", objNull, [objNull]],
    ["_requestNonce", "", [""]],
    ["_generation", -1, [0]],
    ["_expectedRevision", -1, [0]],
    ["_candidate", [], [[]]]
];
if (!isServer || {isRemoteExecuted && {canSuspend}}) exitWith {};

private _localHostCall = !isRemoteExecuted && {hasInterface} && {!isNull player};
if (!isRemoteExecuted && {!_localHostCall}) exitWith {};
private _senderOwner = if (_localHostCall) then { clientOwner } else { remoteExecutedOwner };
private _requestPlayer = [_senderOwner, _localHostCall] call A4A_fnc_resolveRemotePlayer;
private _validation = [_senderOwner, _requestPlayer, _object, _requestNonce, _generation] call A4A_fnc_validateActiveSession;
if !(_validation select 0) exitWith {};
private _session = _validation select 1;
private _ownerKey = _validation select 2;
private _canonical = _validation select 3;
private _arsenalId = _canonical select 1;

private _dataById = localNamespace getVariable ["A4A_ServerData", createHashMap];
private _revisions = localNamespace getVariable ["A4A_ServerRevisions", createHashMap];
private _currentData = _dataById getOrDefault [_arsenalId, []];
private _currentRevision = _revisions getOrDefault [_arsenalId, -1];
private _sendResult = {
    params ["_success", "_revision", "_snapshot", "_message"];
    private _payload = ["", "editorSave", _success, _generation, _revision, parseSimpleArray str _snapshot, false, _message];
    if (_localHostCall) then { _payload call A4A_fnc_receiveTransactionResult } else { _payload remoteExecCall ["A4A_fnc_receiveTransactionResult", _senderOwner] };
};

if !([_requestPlayer] call A4A_fnc_canEdit) exitWith {
    [false, _currentRevision, _currentData, "Arsenal editor access denied by the server."] call _sendResult;
};

private _uid = getPlayerUID _requestPlayer;
private _rateLimits = localNamespace getVariable ["A4A_ServerSaveRateLimit", createHashMap];
private _lastSave = _rateLimits getOrDefault [_uid, -10];
if (diag_tickTime - _lastSave < 2) exitWith {
    [false, _currentRevision, _currentData, "Editor save rate limit: wait two seconds."] call _sendResult;
};
_rateLimits set [_uid, diag_tickTime];
localNamespace setVariable ["A4A_ServerSaveRateLimit", _rateLimits];

private _transactions = localNamespace getVariable ["A4A_ServerTransactions", createHashMap];
private _hasArsenalTransaction = (keys _transactions) findIf {
    private _transaction = _transactions get _x;
    _transaction isEqualType createHashMap && {(_transaction getOrDefault ["arsenalId", ""]) isEqualTo _arsenalId}
} >= 0;
if (
    _hasArsenalTransaction ||
    {_currentRevision < 0} ||
    {_expectedRevision isNotEqualTo _currentRevision} ||
    {(_session getOrDefault ["saveEligibleRevision", -1]) isNotEqualTo _expectedRevision}
) exitWith {
    [false, _currentRevision, _currentData, "Editor snapshot is stale. Reopen the Arsenal before saving."] call _sendResult;
};

private _validated = [_candidate] call A4A_fnc_validateSnapshot;
if !(_validated select 0) exitWith {
    [false, _currentRevision, _currentData, format ["Editor snapshot rejected: %1", _validated select 3]] call _sendResult;
};

private _normalized = _validated select 1;
private _newRevision = _currentRevision + 1;
_dataById set [_arsenalId, parseSimpleArray str _normalized];
_revisions set [_arsenalId, _newRevision];
localNamespace setVariable ["A4A_ServerData", _dataById];
localNamespace setVariable ["A4A_ServerRevisions", _revisions];

private _sessions = localNamespace getVariable ["A4A_ServerSessions", createHashMap];
_session set ["revision", _newRevision];
_session set ["saveEligibleRevision", _newRevision];
_sessions set [_ownerKey, _session];
localNamespace setVariable ["A4A_ServerSessions", _sessions];

[true, _newRevision, _normalized, format ["Arsenal '%1' saved (%2 entries).", _arsenalId, _validated select 2]] call _sendResult;
[_arsenalId, _newRevision, _normalized, _senderOwner, "Arsenal editor published a new snapshot."] call A4A_fnc_publishSnapshot;
[] call A4A_fnc_schedulePersistence;

