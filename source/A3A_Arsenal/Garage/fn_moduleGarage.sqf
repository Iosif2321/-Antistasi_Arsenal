/*
    3DEN Module handler for Antistasi Garage.
    Synchronized objects become garage access points.
*/
params ["_logic", "_units", "_activated"];

if (!_activated) exitWith {};
if (!isServer) exitWith {};

private _garageID = _logic getVariable ["GarageID", "Default"];
private _syncedObjects = synchronizedObjects _logic;

if (count _syncedObjects == 0) then {
    diag_log format ["A3A_Garage: Module %1 (ID %2) has no synchronized objects!", _logic, _garageID];
    systemChat format ["A3A Garage: Module has no synced objects! ID: %1", _garageID];
};

{
    private _object = _x;
    _object setVariable ["A3A_Garage_ID", _garageID, true];

    diag_log format ["A3A_Garage: Module init object %1 with ID '%2'", _object, _garageID];

    [_object, _garageID] remoteExec ["A3A_fnc_garageInit", 0, _object];
} forEach _syncedObjects;

deleteVehicle _logic;
true
