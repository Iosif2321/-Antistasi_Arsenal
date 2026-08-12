if (!isServer || {isRemoteExecuted}) exitWith {};

private _transactions = localNamespace getVariable ["A4A_ServerTransactions", createHashMap];
private _dataById = localNamespace getVariable ["A4A_ServerData", createHashMap];
private _revisions = localNamespace getVariable ["A4A_ServerRevisions", createHashMap];
private _now = diag_tickTime;

{
    private _transactionId = _x;
    private _transaction = _transactions get _transactionId;
    if (
        _transaction isEqualType createHashMap &&
        {_now > (_transaction getOrDefault ["expiresAt", 0])}
    ) then {
        private _kind = _transaction getOrDefault ["kind", ""];
        private _arsenalId = _transaction getOrDefault ["arsenalId", ""];
        private _index = _transaction getOrDefault ["index", -1];
        private _item = _transaction getOrDefault ["item", ""];
        private _amount = _transaction getOrDefault ["amount", 0];
        private _generation = _transaction getOrDefault ["generation", -1];
        private _targetOwner = _transaction getOrDefault ["owner", -1];
        private _data = _dataById getOrDefault [_arsenalId, []];
        private _revision = _revisions getOrDefault [_arsenalId, -1];

        if (
            _kind isEqualTo "withdraw" &&
            {!(_transaction getOrDefault ["unlimited", false])} &&
            {_data isEqualType [] && {count _data isEqualTo 27}} &&
            {_index >= 0 && {_index <= 26}}
        ) then {
            _data set [_index, [_data select _index, [_item, _amount]] call jn_fnc_arsenal_addToArray];
            _dataById set [_arsenalId, _data];
        };

        _transactions deleteAt _transactionId;
        private _snapshot = if (_data isEqualType [] && {count _data isEqualTo 27}) then { parseSimpleArray str _data } else { [] };
        private _payload = [_transactionId, _kind, false, _generation, _revision, _snapshot, true, "Arsenal transaction timed out and was rolled back."];
        if (hasInterface && {_targetOwner isEqualTo clientOwner}) then {
            _payload call A4A_fnc_receiveTransactionResult;
        } else {
            if (_targetOwner >= 2) then { _payload remoteExecCall ["A4A_fnc_receiveTransactionResult", _targetOwner] };
        };
    };
} forEach +(keys _transactions);

localNamespace setVariable ["A4A_ServerTransactions", _transactions];
localNamespace setVariable ["A4A_ServerData", _dataById];

private _sessions = localNamespace getVariable ["A4A_ServerSessions", createHashMap];
{
    private _ownerKey = _x;
    private _session = _sessions get _ownerKey;
    if (_session isEqualType createHashMap && {_now > (_session getOrDefault ["expiresAt", 0])}) then {
        _sessions deleteAt _ownerKey;
    };
} forEach +(keys _sessions);
localNamespace setVariable ["A4A_ServerSessions", _sessions];

