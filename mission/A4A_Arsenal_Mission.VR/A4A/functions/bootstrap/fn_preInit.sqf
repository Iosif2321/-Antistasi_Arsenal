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
            localNamespace setVariable ["A4A_ClientCancelledBatches", createHashMap];
            localNamespace setVariable ["A4A_ClientScheduledBatches", createHashMap];
            localNamespace setVariable ["A4A_ClientTransactionBusy", ""];
            localNamespace setVariable ["A4A_ClientOperationBatch", ""];
            localNamespace setVariable ["A4A_ClientItemTypeCache", createHashMap];
            localNamespace setVariable ["A4A_ClientStateInitialized", true];
        };
    };
};

// Small compatibility surface retained from the standalone addon. The mission
// has no Antistasi membership backend, therefore every connected player uses
// the same quantitative rules.
A4A_hasTFAR = isClass (configFile >> "CfgPatches" >> "task_force_radio");
A4A_hasACE = isClass (configFile >> "CfgPatches" >> "ace_main");
A4A_hasACEMedical = isClass (configFile >> "CfgPatches" >> "ace_medical");
A4A_hasACEHearing = isClass (configFile >> "CfgPatches" >> "ace_hearing");
if (isNil "A4A_arsenalLimits") then { A4A_arsenalLimits = createHashMap };
if (isNil "A4A_fnc_isMember") then { A4A_fnc_isMember = { true } };
if (isNil "A4A_fnc_isMedic") then {
    A4A_fnc_isMedic = {
        params ["_unit"];
        _unit getUnitTrait "Medic" || {getNumber (configFile >> "CfgVehicles" >> typeOf _unit >> "attendant") > 0}
    };
};
if (isNil "A4A_fnc_isEngineer") then {
    A4A_fnc_isEngineer = {
        params ["_unit"];
        private _aceEngineer = _unit getVariable ["ace_isEngineer", 0];
        _unit getUnitTrait "engineer" || {
            if (_aceEngineer isEqualType true) then { _aceEngineer } else { _aceEngineer > 0 }
        }
    };
};
if (isNil "A4A_fnc_hasARadio") then {
    A4A_fnc_hasARadio = {
        assignedItems _this findIf {
            _x isEqualTo "ItemRadio" || {"tf_" in toLower _x} || {"item_radio" in toLower _x}
        } >= 0
    };
};
if (isNil "A4A_fnc_basicBackpack") then {
    A4A_fnc_basicBackpack = {
        params ["_backpack"];
        private _base = _backpack call BIS_fnc_basicBackpack;
        if (_base isEqualTo "") then { _backpack } else { _base }
    };
};
