params [
    ["_object", objNull, [objNull]],
    ["_requestNonce", "", [""]],
    ["_generation", -1, [0]]
];

if (!isServer) exitWith {};
if (isRemoteExecuted && {canSuspend}) exitWith {};
private _localHostCall = !isRemoteExecuted && {hasInterface} && {!isNull player};
if (!isRemoteExecuted && {!_localHostCall}) exitWith {};

private _senderOwner = if (_localHostCall) then { clientOwner } else { remoteExecutedOwner };
private _requestPlayer = [_senderOwner, _localHostCall] call A4A_fnc_resolveRemotePlayer;
private _validation = [_senderOwner, _requestPlayer, _object, _requestNonce, _generation] call A4A_fnc_validateActiveSession;
if !(_validation select 0) exitWith {};

private _ownerKey = _validation select 2;
private _transactions = localNamespace getVariable ["A4A_ServerTransactions", createHashMap];
private _hasActiveTransaction = (keys _transactions) findIf {
    private _transaction = _transactions get _x;
    _transaction isEqualType createHashMap &&
    {(_transaction getOrDefault ["ownerKey", ""]) isEqualTo _ownerKey} &&
    {(_transaction getOrDefault ["generation", -1]) isEqualTo _generation}
} >= 0;
if (_hasActiveTransaction) exitWith {};

private _sessions = localNamespace getVariable ["A4A_ServerSessions", createHashMap];
_sessions deleteAt _ownerKey;
localNamespace setVariable ["A4A_ServerSessions", _sessions];

if (!isNil "A4A_fnc_schedulePersistence") then {
    [] call A4A_fnc_schedulePersistence;
};
