params [
    ["_object", objNull, [objNull]],
    ["_requestNonce", "", [""]],
    ["_generation", -1, [0]],
    ["_transactionId", "", [""]],
    ["_success", false, [false]]
];
if (!isServer || {isRemoteExecuted && {canSuspend}} || {_transactionId isEqualTo ""}) exitWith {};

private _localHostCall = !isRemoteExecuted && {hasInterface} && {!isNull player};
if (!isRemoteExecuted && {!_localHostCall}) exitWith {};
private _senderOwner = if (_localHostCall) then { clientOwner } else { remoteExecutedOwner };
private _requestPlayer = [_senderOwner, _localHostCall] call A4A_fnc_resolveRemotePlayer;
private _validation = [_senderOwner, _requestPlayer, _object, _requestNonce, _generation] call A4A_fnc_validateActiveSession;
if !(_validation select 0) exitWith {};

private _transactions = localNamespace getVariable ["A4A_ServerTransactions", createHashMap];
if (isNil {_transactions get _transactionId}) exitWith {};
private _transaction = _transactions get _transactionId;
if !(
    _transaction isEqualType createHashMap &&
    {(_transaction getOrDefault ["kind", ""]) isEqualTo "withdraw"} &&
    {(_transaction getOrDefault ["state", ""]) isEqualTo "reserved"} &&
    {(_transaction getOrDefault ["owner", -1]) isEqualTo _senderOwner} &&
    {(_transaction getOrDefault ["generation", -1]) isEqualTo _generation}
) exitWith {};

private _arsenalId = _transaction get "arsenalId";
private _index = _transaction get "index";
private _item = _transaction get "item";
private _amount = _transaction get "amount";
private _unlimited = _transaction getOrDefault ["unlimited", false];
private _dataById = localNamespace getVariable ["A4A_ServerData", createHashMap];
private _revisions = localNamespace getVariable ["A4A_ServerRevisions", createHashMap];
private _data = _dataById getOrDefault [_arsenalId, []];
private _revision = _revisions getOrDefault [_arsenalId, -1];
if !(_data isEqualType [] && {count _data isEqualTo 27} && {_revision >= 0}) exitWith {};

private _rollback = !_success;
private _message = "Withdrawal committed.";
private _deleteTransaction = _success || {_unlimited};
if (_rollback) then {
    if (!_unlimited) then {
        private _refunded = [_transactionId, _senderOwner, "Finite withdrawal reservation was refunded."] call A4A_fnc_refundWithdrawalReservation;
        if (_refunded select 0) then {
            _revision = _refunded select 1;
            _data = _refunded select 2;
        } else {
            _message = "Withdrawal failed; its reservation was already finalized or remains queued for safe retry.";
        };
    };
    if (_message isEqualTo "Withdrawal committed.") then {
        _message = "Withdrawal failed and the reservation was refunded.";
    };
} else {
    _revision = _revision + 1;
    _revisions set [_arsenalId, _revision];
    localNamespace setVariable ["A4A_ServerRevisions", _revisions];

    private _sessions = localNamespace getVariable ["A4A_ServerSessions", createHashMap];
    private _ownerKey = str _senderOwner;
    if (!isNil {_sessions get _ownerKey}) then {
        private _session = _sessions get _ownerKey;
        _session set ["revision", _revision];
        _session set ["saveEligibleRevision", -1];
        _sessions set [_ownerKey, _session];
        localNamespace setVariable ["A4A_ServerSessions", _sessions];
    };
};

if (_deleteTransaction) then {
    _transactions = localNamespace getVariable ["A4A_ServerTransactions", createHashMap];
    _transactions deleteAt _transactionId;
    localNamespace setVariable ["A4A_ServerTransactions", _transactions];
};
private _snapshot = parseSimpleArray str _data;
private _payload = [_transactionId, "withdraw", _success, _generation, _revision, _snapshot, _rollback, _message];
if (_localHostCall) then { _payload call A4A_fnc_receiveTransactionResult } else { _payload remoteExecCall ["A4A_fnc_receiveTransactionResult", _senderOwner] };

if (_success) then {
    [_arsenalId, _revision, _data, _senderOwner, "Arsenal stock updated."] call A4A_fnc_publishSnapshot;
    if (!isNil "A4A_fnc_schedulePersistence") then { [] call A4A_fnc_schedulePersistence };
};
