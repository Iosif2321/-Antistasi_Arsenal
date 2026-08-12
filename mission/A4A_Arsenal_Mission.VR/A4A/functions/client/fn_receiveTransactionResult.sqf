params [
    ["_transactionId", "", [""]],
    ["_kind", "sync", [""]],
    ["_success", false, [false]],
    ["_generation", -1, [0]],
    ["_revision", -1, [0]],
    ["_snapshot", [], [[]]],
    ["_rollback", false, [false]],
    ["_message", "", [""]]
];

private _serverAuth = if (isRemoteExecuted) then { remoteExecutedOwner isEqualTo 2 } else { isServer && {hasInterface} };
if (!_serverAuth || {_generation < 1} || {_revision < 0}) exitWith {};
if !(count _snapshot isEqualTo 27 && {_snapshot findIf {!(_x isEqualType [])} < 0}) exitWith {};

private _session = localNamespace getVariable ["A4A_ClientSession", []];
if !(_session isEqualType createHashMap && {(_session getOrDefault ["generation", -1]) isEqualTo _generation}) exitWith {};
private _currentRevision = _session getOrDefault ["revision", -1];
if (_revision < _currentRevision) exitWith {};

private _pending = localNamespace getVariable ["A4A_ClientPendingTransactions", createHashMap];
private _transaction = [];
private _batchId = "";
if (_transactionId isNotEqualTo "") then {
    if (isNil {_pending get _transactionId}) exitWith {};
    _transaction = _pending get _transactionId;
    _batchId = _transaction getOrDefault ["batchId", ""];
    _pending deleteAt _transactionId;
    localNamespace setVariable ["A4A_ClientPendingTransactions", _pending];
};

jna_dataList = parseSimpleArray str _snapshot;
_session set ["revision", _revision];
localNamespace setVariable ["A4A_ClientSession", _session];

if (_rollback && {_transaction isEqualType createHashMap}) then {
    if (_batchId isNotEqualTo "") then {
        private _cancelled = localNamespace getVariable ["A4A_ClientCancelledBatches", createHashMap];
        _cancelled set [_batchId, true];
        localNamespace setVariable ["A4A_ClientCancelledBatches", _cancelled];
    };
    private _baseline = _transaction getOrDefault ["baseline", []];
    if (_baseline isEqualType [] && {count _baseline > 0}) then {
        player setUnitLoadout _baseline;
    };
    localNamespace setVariable ["A4A_ClientTransactionBusy", ""];
    localNamespace setVariable ["A4A_ClientOperationBatch", ""];
};

disableSerialization;
private _display = uiNamespace getVariable ["arsenalDisplay", displayNull];
if (!isNull _display) then {
    ["CreateListAll", [_display]] call jn_fnc_arsenal;
};
if (!isNil "A4A_fnc_arsenal_aceOnDataListUpdate") then {
    [] call A4A_fnc_arsenal_aceOnDataListUpdate;
};

if (_rollback) then {
    if (!isNull _display) then { _display closeDisplay 2 };
    if (missionNamespace getVariable ["A4A_aceStock_active", false] && {!isNil "A4A_fnc_closeAceProxy"}) then {
        [] call A4A_fnc_closeAceProxy;
    };
};
if (_message isNotEqualTo "") then { systemChat _message };

if (_batchId isNotEqualTo "") then {
    _pending = localNamespace getVariable ["A4A_ClientPendingTransactions", createHashMap];
    private _batchStillPending = (keys _pending) findIf {
        private _candidate = _pending get _x;
        _candidate isEqualType createHashMap && {(_candidate getOrDefault ["batchId", ""]) isEqualTo _batchId}
    } >= 0;
    if (!_batchStillPending) then {
        localNamespace setVariable ["A4A_ClientTransactionBusy", ""];
        localNamespace setVariable ["A4A_ClientOperationBatch", ""];
        private _scheduled = localNamespace getVariable ["A4A_ClientScheduledBatches", createHashMap];
        _scheduled deleteAt _batchId;
        localNamespace setVariable ["A4A_ClientScheduledBatches", _scheduled];
        private _cancelled = localNamespace getVariable ["A4A_ClientCancelledBatches", createHashMap];
        _cancelled deleteAt _batchId;
        localNamespace setVariable ["A4A_ClientCancelledBatches", _cancelled];
    };
};
