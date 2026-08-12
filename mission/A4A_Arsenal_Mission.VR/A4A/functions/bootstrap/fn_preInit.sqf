/*
    Initializes only small local/private containers. Heavy config enumeration is
    deliberately deferred until the UI needs it.
*/
if (isServer) then {
    isNil {
        if !(localNamespace getVariable ["A4A_ServerStateInitialized", false]) then {
            localNamespace setVariable ["A4A_ServerRegistry", createHashMap];
            localNamespace setVariable ["A4A_ServerIdRegistry", createHashMap];
            localNamespace setVariable ["A4A_ServerData", createHashMap];
            localNamespace setVariable ["A4A_ServerRevisions", createHashMap];
            localNamespace setVariable ["A4A_ServerReady", createHashMap];
            localNamespace setVariable ["A4A_ServerSessions", createHashMap];
            localNamespace setVariable ["A4A_ServerSessionGenerations", createHashMap];
            localNamespace setVariable ["A4A_ServerTransactions", createHashMap];
            localNamespace setVariable ["A4A_ServerCargoLocks", createHashMap];
            localNamespace setVariable ["A4A_ServerSaveGeneration", createHashMap];
            localNamespace setVariable ["A4A_ServerSaveRateLimit", createHashMap];
            localNamespace setVariable ["A4A_ServerItemTypeCache", createHashMap];

            private _settings = call compile preprocessFileLineNumbers "A4A\config\settings.sqf";
            if !(_settings isEqualType createHashMap) then {
                _settings = createHashMapFromArray [
                    ["uiStyle", "Legacy"],
                    ["unlockThreshold", 25],
                    ["interactionDistance", 5],
                    ["sessionLifetime", 30],
                    ["transactionLifetime", 10],
                    ["maxEntries", 10000],
                    ["maxAmount", 100000000],
                    ["editorSteamIDs", []],
                    ["editAccessMode", 0]
                ];
            };
            localNamespace setVariable ["A4A_ServerSettings", _settings];
            localNamespace setVariable ["A4A_ServerStateInitialized", true];
        };
    };
};

if (hasInterface) then {
    isNil {
        if !(localNamespace getVariable ["A4A_ClientStateInitialized", false]) then {
            localNamespace setVariable ["A4A_ClientSession", []];
            localNamespace setVariable ["A4A_ClientPendingRequests", createHashMap];
            localNamespace setVariable ["A4A_ClientPendingTransactions", createHashMap];
            localNamespace setVariable ["A4A_ClientActionIds", createHashMap];
            localNamespace setVariable ["A4A_ClientItemTypeCache", createHashMap];
            localNamespace setVariable ["A4A_ClientStateInitialized", true];
        };
    };
};
