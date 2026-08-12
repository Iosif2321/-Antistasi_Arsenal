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
    _sessions deleteAt _ownerKey;
    {
        private _transaction = _y;
        if (_transaction isEqualType [] && {count _transaction > 1} && {(_transaction select 1) isEqualTo _ownerKey}) then {
            _transactions deleteAt _x;
        };
    } forEach _transactions;
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

