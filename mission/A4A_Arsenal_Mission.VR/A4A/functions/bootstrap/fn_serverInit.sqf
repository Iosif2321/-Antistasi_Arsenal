if (!isServer || isRemoteExecuted) exitWith {
    diag_log "[A4A Mission] Rejected non-local server bootstrap";
};

private _runServerInit = false;
isNil {
    if !(localNamespace getVariable ["A4A_ServerInitDone", false]) then {
        localNamespace setVariable ["A4A_ServerInitDone", true];
        _runServerInit = true;
    };
};
if (!_runServerInit) exitWith {};

if (!isNil "A4A_fnc_initCbaSettings") then {
    [] call A4A_fnc_initCbaSettings;
};
[] call A4A_fnc_registerConfiguredArsenals;

addMissionEventHandler ["HandleDisconnect", {
    params ["_unit", "_id", "_uid", "_name"];
    private _ownerKey = str (owner _unit);
    private _sessions = localNamespace getVariable ["A4A_ServerSessions", createHashMap];
    private _transactions = localNamespace getVariable ["A4A_ServerTransactions", createHashMap];
    isNil {
        private _currentSessions = localNamespace getVariable ["A4A_ServerSessions", createHashMap];
        if (!isNil {_currentSessions get _ownerKey}) then {
            private _session = _currentSessions get _ownerKey;
            if (
                _session isEqualType createHashMap &&
                {(_session getOrDefault ["playerUID", ""]) isEqualTo _uid}
            ) then {
                _currentSessions deleteAt _ownerKey;
                localNamespace setVariable ["A4A_ServerSessions", _currentSessions];
            };
        };
    };
    {
        private _transactionId = _x;
        private _currentTransactions = localNamespace getVariable ["A4A_ServerTransactions", createHashMap];
        private _transaction = _currentTransactions getOrDefault [_transactionId, createHashMap];
        if (_transaction isEqualType createHashMap && {(_transaction getOrDefault ["ownerKey", ""]) isEqualTo _ownerKey}) then {
            if (
                (_transaction getOrDefault ["kind", ""]) isEqualTo "withdraw" &&
                {!(_transaction getOrDefault ["unlimited", false])}
            ) then {
                [_transactionId, parseNumber _ownerKey, "Disconnected player's finite withdrawal reservation was refunded."] call A4A_fnc_refundWithdrawalReservation;
            } else {
                isNil {
                    private _latestTransactions = localNamespace getVariable ["A4A_ServerTransactions", createHashMap];
                    if (!isNil {_latestTransactions get _transactionId}) then {
                        private _latest = _latestTransactions get _transactionId;
                        if (
                            _latest isEqualType createHashMap &&
                            {(_latest getOrDefault ["ownerKey", ""]) isEqualTo _ownerKey}
                        ) then {
                            _latestTransactions deleteAt _transactionId;
                            localNamespace setVariable ["A4A_ServerTransactions", _latestTransactions];
                        };
                    };
                };
            };
        };
    } forEach +(keys _transactions);
    false
}];

[] spawn {
    while {true} do {
        uiSleep 1;
        if (!isNil "A4A_fnc_expireTransactions") then {
            [] call A4A_fnc_expireTransactions;
        };
    };
};
