params ["_object", ["_arsenalID", "Base"], ["_unlockThreshold", 25]];

// Bootstrap is server-authored. Keep origin validation as defense in depth
// even though the addon's mode-1 CfgRemoteExec policy allowlists this endpoint.
if (isRemoteExecuted && {remoteExecutedOwner != 2}) exitWith {
    diag_log format ["A4A_Arsenal: rejected client-authored arsenalInit from owner %1", remoteExecutedOwner];
};

// Check if object is valid
if (isNil "_object" || isNull _object) exitWith { 
    diag_log format ["Result: Error: Antistasi Arsenal - Invalid object provided by module or script. ID: %1", _arsenalID];
};

// Ensure variables are available globally (JIP)
// Initialize JNA on the object
if (isServer) then {
    _object setVariable ["A4A_Arsenal_ID", _arsenalID, true];
    _object setVariable ["A4A_Arsenal_Threshold", _unlockThreshold, true];

    if (isNil "A4A_guestItemLimit") then { missionNamespace setVariable ["A4A_guestItemLimit", _unlockThreshold, true]; };

    // Register the canonical object/ID in a tiny unscheduled critical section.
    // The full JNA initializer remains scheduled because its Preload scans large
    // config trees and must be allowed to yield on mod-heavy clients.
    isNil {
        private _serverObjects = localNamespace getVariable ["A4A_Arsenal_ServerObjects", []];
        _serverObjects pushBackUnique _object;
        localNamespace setVariable ["A4A_Arsenal_ServerObjects", _serverObjects];

        private _serverRegistry = localNamespace getVariable ["A4A_Arsenal_ServerRegistry", []];
        private _registryIndex = _serverRegistry findIf {(_x select 0) isEqualTo _object};
        if (_registryIndex < 0) then {
            _serverRegistry pushBack [_object, _arsenalID, _unlockThreshold];
        } else {
            _serverRegistry set [_registryIndex, [_object, _arsenalID, _unlockThreshold]];
        };
        localNamespace setVariable ["A4A_Arsenal_ServerRegistry", _serverRegistry];

        if (isNil {localNamespace getVariable "A4A_Arsenal_ServerData"}) then {
            localNamespace setVariable ["A4A_Arsenal_ServerData", createHashMap];
        };
        if (isNil {localNamespace getVariable "A4A_Arsenal_ServerRevisions"}) then {
            localNamespace setVariable ["A4A_Arsenal_ServerRevisions", createHashMap];
        };
        if (isNil {localNamespace getVariable "A4A_Arsenal_ServerReadyObjects"}) then {
            localNamespace setVariable ["A4A_Arsenal_ServerReadyObjects", []];
        };
        nil
    };
    [_object] remoteExec ["JN_fnc_arsenal_init", 0, _object]; // Execute everywhere (Server + Clients, JIP)
};

true;
