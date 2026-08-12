params [
    ["_transactionId", "", [""]],
    ["_excludedOwner", -1, [0]],
    ["_message", "Finite withdrawal reservation was refunded.", [""]]
];
if (!isServer || {_transactionId isEqualTo ""}) exitWith { [false, -1, []] };

private _committed = false;
private _arsenalId = "";
private _revision = -1;
private _data = [];
private _failureReason = "reservation was not available for refund";

/*
    Timeout, disconnect and a late client completion can all reach this helper.
    Claim, validate, mutate canonical state and retire the transaction in one
    unscheduled critical section. No scheduled caller can overwrite an
    intervening inventory/cargo mutation with a stale snapshot.
*/
isNil {
    private _transactions = localNamespace getVariable ["A4A_ServerTransactions", createHashMap];
    if (!isNil {_transactions get _transactionId}) then {
        private _transaction = _transactions get _transactionId;
        if (
            _transaction isEqualType createHashMap &&
            {(_transaction getOrDefault ["kind", ""]) isEqualTo "withdraw"} &&
            {(_transaction getOrDefault ["state", ""]) isEqualTo "reserved"} &&
            {!(_transaction getOrDefault ["unlimited", false])} &&
            {(_transaction getOrDefault ["transactionId", ""]) isEqualTo _transactionId}
        ) then {
            _transaction set ["state", "refunding"];
            _transactions set [_transactionId, _transaction];
            localNamespace setVariable ["A4A_ServerTransactions", _transactions];

            _arsenalId = _transaction getOrDefault ["arsenalId", ""];
            private _index = _transaction getOrDefault ["index", -1];
            private _item = _transaction getOrDefault ["item", ""];
            private _amount = _transaction getOrDefault ["amount", 0];
            private _dataById = localNamespace getVariable ["A4A_ServerData", createHashMap];
            private _revisions = localNamespace getVariable ["A4A_ServerRevisions", createHashMap];
            _data = _dataById getOrDefault [_arsenalId, []];
            _revision = _revisions getOrDefault [_arsenalId, -1];

            if (
                _arsenalId isNotEqualTo "" &&
                {_index >= 0 && {_index <= 26}} &&
                {_item isNotEqualTo ""} &&
                {_amount > 0} &&
                {_data isEqualType [] && {count _data isEqualTo 27}} &&
                {_revision >= 0}
            ) then {
                private _candidate = parseSimpleArray str _data;
                _candidate set [_index, [_candidate select _index, [_item, _amount]] call jn_fnc_arsenal_addToArray];
                private _validated = [_candidate] call A4A_fnc_validateSnapshot;
                if (_validated select 0) then {
                    _data = _validated select 1;
                    _revision = _revision + 1;
                    _dataById set [_arsenalId, parseSimpleArray str _data];
                    _revisions set [_arsenalId, _revision];
                    localNamespace setVariable ["A4A_ServerData", _dataById];
                    localNamespace setVariable ["A4A_ServerRevisions", _revisions];

                    private _sessions = localNamespace getVariable ["A4A_ServerSessions", createHashMap];
                    {
                        private _session = _sessions get _x;
                        if (_session isEqualType createHashMap && {(_session getOrDefault ["arsenalId", ""]) isEqualTo _arsenalId}) then {
                            _session set ["revision", _revision];
                            _session set ["saveEligibleRevision", -1];
                            _sessions set [_x, _session];
                        };
                    } forEach keys _sessions;
                    localNamespace setVariable ["A4A_ServerSessions", _sessions];

                    _transactions deleteAt _transactionId;
                    localNamespace setVariable ["A4A_ServerTransactions", _transactions];
                    _committed = true;
                } else {
                    _failureReason = _validated select 3;
                    _transaction set ["state", "reserved"];
                    _transactions set [_transactionId, _transaction];
                    localNamespace setVariable ["A4A_ServerTransactions", _transactions];
                };
            } else {
                _failureReason = "reservation or canonical state was malformed";
                _transaction set ["state", "reserved"];
                _transactions set [_transactionId, _transaction];
                localNamespace setVariable ["A4A_ServerTransactions", _transactions];
            };
        };
    };
};

if (!_committed) exitWith {
    diag_log format ["[A4A Mission] Withdrawal refund '%1' was not committed: %2", _transactionId, _failureReason];
    [false, _revision, _data]
};

[_arsenalId, _revision, _data, _excludedOwner, _message] call A4A_fnc_publishSnapshot;
[] call A4A_fnc_schedulePersistence;
[true, _revision, _data]
