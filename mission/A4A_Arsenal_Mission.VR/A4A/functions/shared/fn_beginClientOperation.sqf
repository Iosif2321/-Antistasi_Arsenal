if (!hasInterface || {isRemoteExecuted}) exitWith { false };
if ((localNamespace getVariable ["A4A_ClientTransactionBusy", ""]) isNotEqualTo "") exitWith { false };

private _batchId = format ["B:%1:%2:%3", clientOwner, floor (diag_tickTime * 1000), floor random 1000000000];
localNamespace setVariable ["A4A_ClientTransactionBusy", _batchId];
localNamespace setVariable ["A4A_ClientOperationBatch", _batchId];
localNamespace setVariable ["A4A_ClientOperationBaseline", getUnitLoadout player];

[_batchId] spawn {
    params ["_expectedBatch"];
    uiSleep 0.05;
    private _pending = localNamespace getVariable ["A4A_ClientPendingTransactions", createHashMap];
    private _hasBatchWork = (keys _pending) findIf {
        private _transaction = _pending get _x;
        _transaction isEqualType createHashMap && {(_transaction getOrDefault ["batchId", ""]) isEqualTo _expectedBatch}
    } >= 0;
    if (!_hasBatchWork && {(localNamespace getVariable ["A4A_ClientTransactionBusy", ""]) isEqualTo _expectedBatch}) then {
        localNamespace setVariable ["A4A_ClientTransactionBusy", ""];
        localNamespace setVariable ["A4A_ClientOperationBatch", ""];
    };
};

true
