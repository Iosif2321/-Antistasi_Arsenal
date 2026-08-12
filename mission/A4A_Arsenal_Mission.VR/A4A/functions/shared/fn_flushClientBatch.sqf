params [["_batchId", "", [""]]];
if (!hasInterface || {isRemoteExecuted} || {_batchId isEqualTo ""}) exitWith {};

uiSleep 0;
private _pending = localNamespace getVariable ["A4A_ClientPendingTransactions", createHashMap];
private _batchKeys = (keys _pending) select {
    private _transaction = _pending get _x;
    _transaction isEqualType createHashMap &&
    {(_transaction getOrDefault ["batchId", ""]) isEqualTo _batchId} &&
    {(_transaction getOrDefault ["state", ""]) isEqualTo "queued"}
};
if (count _batchKeys isEqualTo 0) exitWith {};

private _provisionalLoadout = getUnitLoadout player;
private _first = _pending get (_batchKeys select 0);
private _baseline = _first getOrDefault ["baseline", []];
if (_baseline isEqualType [] && {count _baseline > 0}) then {
    player setUnitLoadout _baseline;
};

private _batchCount = count _batchKeys;
{
    private _transactionId = _x;
    private _transaction = _pending get _transactionId;
    _transaction set ["state", "requested"];
    _transaction set ["provisionalLoadout", _provisionalLoadout];
    _transaction set ["batchCount", _batchCount];
    _pending set [_transactionId, _transaction];
} forEach _batchKeys;
localNamespace setVariable ["A4A_ClientPendingTransactions", _pending];

{
    private _transactionId = _x;
    private _transaction = _pending get _transactionId;
    private _payload = [
        _transaction get "object",
        _transaction get "requestNonce",
        _transaction get "generation",
        _transaction get "expectedRevision",
        _transactionId,
        _transaction get "index",
        _transaction get "item",
        _transaction get "amount"
    ];
    if ((_transaction get "kind") isEqualTo "withdraw") then {
        _payload remoteExecCall ["A4A_fnc_requestWithdraw", 2];
    } else {
        _payload remoteExecCall ["A4A_fnc_requestReturn", 2];
    };
} forEach _batchKeys;

uiSleep 12;
_pending = localNamespace getVariable ["A4A_ClientPendingTransactions", createHashMap];
private _remaining = (keys _pending) select {
    private _transaction = _pending get _x;
    _transaction isEqualType createHashMap && {(_transaction getOrDefault ["batchId", ""]) isEqualTo _batchId}
};
if (count _remaining > 0) then {
    private _cancelled = localNamespace getVariable ["A4A_ClientCancelledBatches", createHashMap];
    _cancelled set [_batchId, true];
    localNamespace setVariable ["A4A_ClientCancelledBatches", _cancelled];
    if (_baseline isEqualType [] && {count _baseline > 0}) then { player setUnitLoadout _baseline };
    {
        private _transaction = _pending get _x;
        if ((_transaction getOrDefault ["state", ""]) in ["granted", "completing"]) then {
            private _completePayload = [
                _transaction get "object",
                _transaction get "requestNonce",
                _transaction get "generation",
                _x,
                false
            ];
            if ((_transaction get "kind") isEqualTo "withdraw") then {
                _completePayload remoteExecCall ["A4A_fnc_completeWithdraw", 2];
            } else {
                _completePayload remoteExecCall ["A4A_fnc_completeReturn", 2];
            };
        };
    } forEach _remaining;
    localNamespace setVariable ["A4A_ClientTransactionBusy", ""];
    localNamespace setVariable ["A4A_ClientOperationBatch", ""];
    private _display = uiNamespace getVariable ["arsenalDisplay", displayNull];
    if (!isNull _display) then { _display closeDisplay 2 };
    systemChat "A4A transaction batch timed out; provisional loadout restored.";
};
