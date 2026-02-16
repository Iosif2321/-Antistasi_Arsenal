params ["_object", ["_arsenalID", "Base"], ["_unlockThreshold", 25]];

// Check if object is valid
if (isNil "_object" || isNull _object) exitWith { 
    diag_log format ["Result: Error: Antistasi Arsenal - Invalid object provided by module or script. ID: %1", _arsenalID];
};

// Ensure variables are available globally (JIP)
_object setVariable ["A3A_Arsenal_ID", _arsenalID, true];
_object setVariable ["A3A_Arsenal_Threshold", _unlockThreshold, true];

// Initialize Stubs (to prevent errors with missing A3A functions)
[] call A3A_fnc_a3a_stub;

// Initialize JNA (Jeroen Arsenal)
// JNA requires initialization on both server and client (for actions)

// We need to set some global variables expected by JNA if they don't exist
if (isNil "A3A_guestItemLimit") then { missionNamespace setVariable ["A3A_guestItemLimit", _unlockThreshold, true]; };

// Initialize JNA on the object
[_object] remoteExec ["JN_fnc_arsenal_init", 0, _object]; // Execute everywhere (Server + Clients)

true;
