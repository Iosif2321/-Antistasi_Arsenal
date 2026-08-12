if (!isServer) exitWith {};

private _generation = (localNamespace getVariable ["A4A_ServerSaveGeneration", 0]) + 1;
localNamespace setVariable ["A4A_ServerSaveGeneration", _generation];
if (localNamespace getVariable ["A4A_ServerSaveScheduled", false]) exitWith {};
localNamespace setVariable ["A4A_ServerSaveScheduled", true];

[] spawn {
    private _finished = false;
    while {!_finished} do {
        private _flushGeneration = localNamespace getVariable ["A4A_ServerSaveGeneration", 0];
        uiSleep 0.25;

        private _transactions = localNamespace getVariable ["A4A_ServerTransactions", createHashMap];
        if (count keys _transactions isEqualTo 0) then {
            private _dataById = localNamespace getVariable ["A4A_ServerData", createHashMap];
            private _revisions = localNamespace getVariable ["A4A_ServerRevisions", createHashMap];
            {
                private _arsenalId = _x;
                private _data = _dataById get _arsenalId;
                private _revision = _revisions getOrDefault [_arsenalId, -1];
                private _validated = [_data] call A4A_fnc_validateSnapshot;
                if ((_validated select 0) && {_revision >= 0}) then {
                    profileNamespace setVariable [
                        format ["A4A_MissionArsenal_v2_%1", _arsenalId],
                        [2, _revision, parseSimpleArray str (_validated select 1)]
                    ];
                } else {
                    diag_log format ["[A4A Mission] Refused to persist invalid canonical data '%1'", _arsenalId];
                };
            } forEach keys _dataById;
            saveProfileNamespace;

            if ((localNamespace getVariable ["A4A_ServerSaveGeneration", 0]) isEqualTo _flushGeneration) then {
                localNamespace setVariable ["A4A_ServerSaveScheduled", false];
                _finished = true;
            };
        };
    };
};

