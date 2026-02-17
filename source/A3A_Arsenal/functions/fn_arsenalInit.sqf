params ["_object", ["_arsenalID", "Base"], ["_unlockThreshold", 25]];

// Check if object is valid
if (isNil "_object" || isNull _object) exitWith { 
    diag_log format ["Result: Error: Antistasi Arsenal - Invalid object provided by module or script. ID: %1", _arsenalID];
};

// Ensure variables are available globally (JIP)
// Initialize JNA on the object
if (isServer) then {
    _object setVariable ["A3A_Arsenal_ID", _arsenalID, true];
    _object setVariable ["A3A_Arsenal_Threshold", _unlockThreshold, true];

    if (isNil "A3A_guestItemLimit") then { missionNamespace setVariable ["A3A_guestItemLimit", _unlockThreshold, true]; };

    [_object] remoteExec ["JN_fnc_arsenal_init", 0, _object]; // Execute everywhere (Server + Clients)
};

true;
