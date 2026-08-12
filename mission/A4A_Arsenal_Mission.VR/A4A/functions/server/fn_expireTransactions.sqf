if (!isServer || {isRemoteExecuted}) exitWith {};

private _transactions = localNamespace getVariable ["A4A_ServerTransactions", createHashMap];
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
        private _generation = _transaction getOrDefault ["generation", -1];
        private _targetOwner = _transaction getOrDefault ["owner", -1];
        private _dataById = localNamespace getVariable ["A4A_ServerData", createHashMap];
        private _revisions = localNamespace getVariable ["A4A_ServerRevisions", createHashMap];
        private _data = _dataById getOrDefault [_arsenalId, []];
        private _revision = _revisions getOrDefault [_arsenalId, -1];

        private _finalized = false;
        if (
            _kind isEqualTo "withdraw" &&
            {!(_transaction getOrDefault ["unlimited", false])}
        ) then {
            private _refunded = [_transactionId, _targetOwner, "Timed-out finite withdrawal reservation was refunded."] call A4A_fnc_refundWithdrawalReservation;
            if (_refunded select 0) then {
                _revision = _refunded select 1;
                _data = _refunded select 2;
                _finalized = true;
            };
        } else {
            isNil {
                private _currentTransactions = localNamespace getVariable ["A4A_ServerTransactions", createHashMap];
                if (!isNil {_currentTransactions get _transactionId}) then {
                    private _current = _currentTransactions get _transactionId;
                    if (
                        _current isEqualType createHashMap &&
                        {_now > (_current getOrDefault ["expiresAt", 0])} &&
                        {(_current getOrDefault ["state", ""]) in ["pending", "reserved"]}
                    ) then {
                        _currentTransactions deleteAt _transactionId;
                        localNamespace setVariable ["A4A_ServerTransactions", _currentTransactions];
                        _finalized = true;
                    };
                };
            };
        };

        if (_finalized) then {
            _dataById = localNamespace getVariable ["A4A_ServerData", createHashMap];
            _revisions = localNamespace getVariable ["A4A_ServerRevisions", createHashMap];
            _data = _dataById getOrDefault [_arsenalId, []];
            _revision = _revisions getOrDefault [_arsenalId, -1];
            private _snapshot = if (_data isEqualType [] && {count _data isEqualTo 27}) then { parseSimpleArray str _data } else { [] };
            private _payload = [_transactionId, _kind, false, _generation, _revision, _snapshot, true, "Arsenal transaction timed out and was rolled back."];
            if (hasInterface && {_targetOwner isEqualTo clientOwner}) then {
                _payload call A4A_fnc_receiveTransactionResult;
            } else {
                if (_targetOwner >= 2) then { _payload remoteExecCall ["A4A_fnc_receiveTransactionResult", _targetOwner] };
            };
        };
    };
} forEach +(keys _transactions);

private _sessions = localNamespace getVariable ["A4A_ServerSessions", createHashMap];
{
    private _ownerKey = _x;
    private _session = _sessions get _ownerKey;
    if (_session isEqualType createHashMap && {_now > (_session getOrDefault ["expiresAt", 0])}) then {
        private _targetOwner = parseNumber _ownerKey;
        private _generation = _session getOrDefault ["generation", -1];
        private _expired = false;
        isNil {
            private _currentSessions = localNamespace getVariable ["A4A_ServerSessions", createHashMap];
            if (!isNil {_currentSessions get _ownerKey}) then {
                private _current = _currentSessions get _ownerKey;
                if (
                    _current isEqualType createHashMap &&
                    {(_current getOrDefault ["generation", -1]) isEqualTo _generation} &&
                    {_now > (_current getOrDefault ["expiresAt", 0])}
                ) then {
                    _currentSessions deleteAt _ownerKey;
                    localNamespace setVariable ["A4A_ServerSessions", _currentSessions];
                    _expired = true;
                };
            };
        };
        if (_expired) then {
            private _payload = [_generation, "Arsenal session expired after prolonged inactivity. Reopen it to continue."];
            if (hasInterface && {_targetOwner isEqualTo clientOwner}) then {
                _payload call A4A_fnc_receiveInvalidate;
            } else {
                if (_targetOwner >= 2) then { _payload remoteExecCall ["A4A_fnc_receiveInvalidate", _targetOwner] };
            };
        };
    };
} forEach +(keys _sessions);
