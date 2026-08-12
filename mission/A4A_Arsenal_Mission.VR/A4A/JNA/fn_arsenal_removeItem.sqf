#include "..\defineCommon.inc"

if (isRemoteExecuted) exitWith {
    diag_log format ["[A4A Mission] Rejected remote withdrawal wrapper from owner %1", remoteExecutedOwner];
    false
};

private _deltas = [];
if (_this isEqualType [] && {count _this > 0}) then {
    if ((_this select 0) isEqualType 0) then {
        _this params ["_index", "_item", ["_amount", 1]];
        _deltas pushBack [_index, _item, _amount];
    } else {
        {
            private _index = _forEachIndex;
            {
                if (_x isEqualType [] && {count _x >= 2}) then {
                    _deltas pushBack [_index, _x select 0, _x select 1];
                };
            } forEach _x;
        } forEach _this;
    };
};

private _submitted = false;
{
    _x params ["_index", "_item", "_amount"];
    if (_index isEqualTo 23) then { _index = 24 };
    if (_item isEqualType "" && {_item isNotEqualTo ""} && {_amount isEqualType 0} && {finite _amount} && {_amount > 0} && {_amount isEqualTo floor _amount}) then {
        private _session = localNamespace getVariable ["A4A_ClientSession", []];
        if !(_session isEqualType createHashMap) exitWith {
            private _baseline = localNamespace getVariable ["A4A_ClientOperationBaseline", []];
            if (_baseline isEqualType [] && {count _baseline > 0}) then { player setUnitLoadout _baseline };
            systemChat "A4A withdrawal cancelled: no active server session.";
        };

        private _object = _session getOrDefault ["object", objNull];
        private _requestNonce = _session getOrDefault ["requestNonce", ""];
        private _generation = _session getOrDefault ["generation", -1];
        private _expectedRevision = _session getOrDefault ["revision", -1];
        if (isNull _object || {_requestNonce isEqualTo ""} || {_generation < 1} || {_expectedRevision < 0}) exitWith {};

        private _transactionId = format ["W:%1:%2:%3", clientOwner, floor (diag_tickTime * 1000), floor random 1000000000];
        private _baseline = localNamespace getVariable ["A4A_ClientOperationBaseline", []];
        private _batchId = localNamespace getVariable ["A4A_ClientOperationBatch", ""];
        if (_batchId isEqualTo "") exitWith {
            if (_baseline isEqualType [] && {count _baseline > 0}) then { player setUnitLoadout _baseline };
            systemChat "A4A withdrawal cancelled: no operation batch.";
        };
        private _transaction = createHashMapFromArray [
            ["kind", "withdraw"],
            ["state", "queued"],
            ["batchId", _batchId],
            ["object", _object],
            ["requestNonce", _requestNonce],
            ["generation", _generation],
            ["expectedRevision", _expectedRevision],
            ["index", _index],
            ["item", _item],
            ["amount", _amount],
            ["baseline", _baseline],
            ["createdAt", diag_tickTime]
        ];
        private _pending = localNamespace getVariable ["A4A_ClientPendingTransactions", createHashMap];
        _pending set [_transactionId, _transaction];
        localNamespace setVariable ["A4A_ClientPendingTransactions", _pending];

        if (!isNil "jna_dataList" && {jna_dataList isEqualType []} && {count jna_dataList isEqualTo 27}) then {
            jna_dataList set [_index, [jna_dataList select _index, [_item, _amount]] call jn_fnc_arsenal_removeFromArray];
        };

        _submitted = true;
        private _scheduled = localNamespace getVariable ["A4A_ClientScheduledBatches", createHashMap];
        if (isNil {_scheduled get _batchId}) then {
            _scheduled set [_batchId, true];
            localNamespace setVariable ["A4A_ClientScheduledBatches", _scheduled];
            [_batchId] spawn A4A_fnc_flushClientBatch;
        };
    };
} forEach _deltas;

_submitted
