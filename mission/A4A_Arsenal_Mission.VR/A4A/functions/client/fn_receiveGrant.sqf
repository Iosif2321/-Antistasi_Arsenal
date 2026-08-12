params [
    ["_transactionId", "", [""]],
    ["_kind", "", [""]],
    ["_generation", -1, [0]],
    ["_baseRevision", -1, [0]],
    ["_index", -1, [0]],
    ["_item", "", [""]],
    ["_amount", 0, [0]]
];

private _serverAuth = if (isRemoteExecuted) then { remoteExecutedOwner isEqualTo 2 } else { isServer && {hasInterface} };
if (!_serverAuth || {_transactionId isEqualTo ""} || {!(_kind in ["withdraw", "return"])}) exitWith {};

private _session = localNamespace getVariable ["A4A_ClientSession", []];
if !(_session isEqualType createHashMap && {(_session getOrDefault ["generation", -1]) isEqualTo _generation}) exitWith {};
private _pending = localNamespace getVariable ["A4A_ClientPendingTransactions", createHashMap];
if (isNil {_pending get _transactionId}) exitWith {};
private _transaction = _pending get _transactionId;
if !(
    _transaction isEqualType createHashMap &&
    {(_transaction getOrDefault ["kind", ""]) isEqualTo _kind} &&
    {(_transaction getOrDefault ["index", -1]) isEqualTo _index} &&
    {(_transaction getOrDefault ["item", ""]) isEqualTo _item} &&
    {(_transaction getOrDefault ["amount", 0]) isEqualTo _amount}
) exitWith {};

_transaction set ["state", "granted"];
_pending set [_transactionId, _transaction];
localNamespace setVariable ["A4A_ClientPendingTransactions", _pending];

private _batchId = _transaction getOrDefault ["batchId", ""];
private _cancelled = localNamespace getVariable ["A4A_ClientCancelledBatches", createHashMap];
private _isCancelled = _batchId isNotEqualTo "" && {!isNil {_cancelled get _batchId}};

private _sendCompletion = {
    params ["_id", "_pendingTransaction", "_completeSuccess"];
    private _payload = [
        _pendingTransaction get "object",
        _pendingTransaction get "requestNonce",
        _pendingTransaction get "generation",
        _id,
        _completeSuccess
    ];
    if ((_pendingTransaction get "kind") isEqualTo "withdraw") then {
        if (isServer) then { _payload call A4A_fnc_completeWithdraw } else { _payload remoteExecCall ["A4A_fnc_completeWithdraw", 2] };
    } else {
        if (isServer) then { _payload call A4A_fnc_completeReturn } else { _payload remoteExecCall ["A4A_fnc_completeReturn", 2] };
    };
};

if (_isCancelled) exitWith {
    _transaction set ["state", "completing"];
    _pending set [_transactionId, _transaction];
    localNamespace setVariable ["A4A_ClientPendingTransactions", _pending];
    [_transactionId, _transaction, false] call _sendCompletion;
};

private _batchKeys = (keys _pending) select {
    private _candidate = _pending get _x;
    _candidate isEqualType createHashMap && {(_candidate getOrDefault ["batchId", ""]) isEqualTo _batchId}
};
if (count _batchKeys isEqualTo 0) exitWith {};
if (_batchKeys findIf {((_pending get _x) getOrDefault ["state", ""]) isNotEqualTo "granted"} >= 0) exitWith {};

private _provisionalLoadout = _transaction getOrDefault ["provisionalLoadout", []];
if (_provisionalLoadout isEqualType [] && {count _provisionalLoadout > 0}) then {
    player setUnitLoadout _provisionalLoadout;
};

{
    private _pendingTransaction = _pending get _x;
    _pendingTransaction set ["state", "completing"];
    _pending set [_x, _pendingTransaction];
} forEach _batchKeys;
localNamespace setVariable ["A4A_ClientPendingTransactions", _pending];
{
    [_x, _pending get _x, true] call _sendCompletion;
} forEach _batchKeys;
