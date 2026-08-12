params [
    ["_object", objNull, [objNull]],
    ["_requestNonce", "", [""]],
    ["_generation", -1, [0]],
    ["_expectedRevision", -1, [0]],
    ["_transactionId", "", [""]],
    ["_index", -1, [0]],
    ["_item", "", [""]],
    ["_amount", 0, [0]]
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
private _settings = localNamespace getVariable ["A4A_ServerSettings", createHashMap];
private _data = _dataById getOrDefault [_arsenalId, []];
private _revision = _revisions getOrDefault [_arsenalId, -1];
private _maxAmount = _settings getOrDefault ["maxAmount", 100000000];

private _sendResult = {
    params ["_success", "_rollback", "_message"];
    private _snapshot = if (_data isEqualType [] && {count _data isEqualTo 27}) then { parseSimpleArray str _data } else { [] };
    private _payload = [_transactionId, "withdraw", _success, _generation, _revision, _snapshot, _rollback, _message];
    if (_localHostCall) then { _payload call A4A_fnc_receiveTransactionResult } else { _payload remoteExecCall ["A4A_fnc_receiveTransactionResult", _senderOwner] };
};

private _derivedIndex = [_item, false] call A4A_fnc_itemTypeCached;
if (
    !(_data isEqualType [] && {count _data isEqualTo 27}) ||
    {_revision < 0} ||
    {_expectedRevision isNotEqualTo _revision} ||
    {_transactionId isEqualTo ""} ||
    {count _transactionId > 160} ||
    {_item isEqualTo ""} ||
    {count _item > 256} ||
    {!finite _amount} ||
    {_amount isNotEqualTo floor _amount} ||
    {_amount <= 0} ||
    {_amount > _maxAmount} ||
    {_index < 0 || {_index > 26}} ||
    {_derivedIndex isNotEqualTo _index}
) exitWith { [false, true, "Withdrawal rejected: stale or invalid request."] call _sendResult };

private _transactions = localNamespace getVariable ["A4A_ServerTransactions", createHashMap];
if (!isNil {_transactions get _transactionId}) exitWith {
    private _existing = _transactions get _transactionId;
    if (
        _existing isEqualType createHashMap &&
        {(_existing getOrDefault ["ownerKey", ""]) isEqualTo _ownerKey} &&
        {(_existing getOrDefault ["kind", ""]) isEqualTo "withdraw"}
    ) then {
        private _payload = [_transactionId, "withdraw", _generation, _revision, _index, _item, _amount];
        if (_localHostCall) then { _payload call A4A_fnc_receiveGrant } else { _payload remoteExecCall ["A4A_fnc_receiveGrant", _senderOwner] };
    };
};

private _available = [_data select _index, _item] call jn_fnc_arsenal_itemCount;
if (_available isNotEqualTo -1 && {_available < _amount}) exitWith {
    [false, true, "Withdrawal rejected: stock changed before reservation."] call _sendResult;
};

private _unlimited = _available isEqualTo -1;
if (!_unlimited) then {
    _data set [_index, [_data select _index, [_item, _amount]] call jn_fnc_arsenal_removeFromArray];
    _dataById set [_arsenalId, _data];
    localNamespace setVariable ["A4A_ServerData", _dataById];
};

private _lifetime = _settings getOrDefault ["transactionLifetime", 10];
private _transaction = createHashMapFromArray [
    ["transactionId", _transactionId],
    ["kind", "withdraw"],
    ["state", "reserved"],
    ["ownerKey", _ownerKey],
    ["owner", _senderOwner],
    ["object", _object],
    ["requestNonce", _requestNonce],
    ["generation", _generation],
    ["arsenalId", _arsenalId],
    ["index", _index],
    ["item", _item],
    ["amount", _amount],
    ["unlimited", _unlimited],
    ["baseRevision", _revision],
    ["expiresAt", diag_tickTime + _lifetime]
];
_transactions set [_transactionId, _transaction];
localNamespace setVariable ["A4A_ServerTransactions", _transactions];

private _grant = [_transactionId, "withdraw", _generation, _revision, _index, _item, _amount];
if (_localHostCall) then { _grant call A4A_fnc_receiveGrant } else { _grant remoteExecCall ["A4A_fnc_receiveGrant", _senderOwner] };
