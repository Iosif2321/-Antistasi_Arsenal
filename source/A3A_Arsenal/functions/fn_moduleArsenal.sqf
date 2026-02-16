params ["_logic", "_units", "_activated"];

if (!_activated) exitWith {};

// Only run on server
if (!isServer) exitWith {};

// Get module parameters
private _arsenalID = _logic getVariable ["ArsenalID", "Base"];
private _unlockThreshold = _logic getVariable ["UnlockThreshold", 25];

// Find synchronized objects (the arsenal box)
private _syncedObjects = synchronizedObjects _logic;

// Debug log if no objects found
// Debug log if no objects found
if (count _syncedObjects == 0) then {
    _msg = format ["Antistasi Arsenal: Module %1 (ID %2) has no synchronized objects!", _logic, _arsenalID];
    diag_log text _msg;
    systemChat _msg;
};

{
    private _object = _x;
    // Debu log
    _msg = format ["Antistasi Arsenal: Initializing object: %1 with ID: %2", _object, _arsenalID];
    diag_log text _msg;
    systemChat _msg;

    // Initialize arsenal on each synchronized object
    // We pass the object, ID, and threshold
    // IMPORTANT: remoteExec to run on all clients!
    [_object, _arsenalID, _unlockThreshold] remoteExec ["A3A_fnc_arsenalInit", 0, true]; 
} forEach _syncedObjects;

// Delete the module logic object to clean up (as requested)
deleteVehicle _logic;

true;
