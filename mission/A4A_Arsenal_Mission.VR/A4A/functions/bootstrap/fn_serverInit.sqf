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

[] call A4A_fnc_registerConfiguredArsenals;

addMissionEventHandler ["HandleDisconnect", {
    params ["_unit", "_id", "_uid", "_name"];
    private _ownerKey = str (owner _unit);
    private _sessions = localNamespace getVariable ["A4A_ServerSessions", createHashMap];
    private _transactions = localNamespace getVariable ["A4A_ServerTransactions", createHashMap];
    private _dataById = localNamespace getVariable ["A4A_ServerData", createHashMap];
    _sessions deleteAt _ownerKey;
    {
        private _transactionId = _x;
        private _transaction = _transactions get _transactionId;
        if (_transaction isEqualType createHashMap && {(_transaction getOrDefault ["ownerKey", ""]) isEqualTo _ownerKey}) then {
            if (
                (_transaction getOrDefault ["kind", ""]) isEqualTo "withdraw" &&
                {!(_transaction getOrDefault ["unlimited", false])}
            ) then {
                private _arsenalId = _transaction getOrDefault ["arsenalId", ""];
                private _index = _transaction getOrDefault ["index", -1];
                private _item = _transaction getOrDefault ["item", ""];
                private _amount = _transaction getOrDefault ["amount", 0];
                private _data = _dataById getOrDefault [_arsenalId, []];
                if (_data isEqualType [] && {count _data isEqualTo 27} && {_index >= 0} && {_index <= 26}) then {
                    _data set [_index, [_data select _index, [_item, _amount]] call jn_fnc_arsenal_addToArray];
                    _dataById set [_arsenalId, _data];
                };
            };
            _transactions deleteAt _transactionId;
        };
    } forEach +(keys _transactions);
    localNamespace setVariable ["A4A_ServerSessions", _sessions];
    localNamespace setVariable ["A4A_ServerTransactions", _transactions];
    localNamespace setVariable ["A4A_ServerData", _dataById];
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
