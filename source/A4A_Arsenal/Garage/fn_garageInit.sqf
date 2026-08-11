/*
    Initialize garage on an object.
    Call: [_object, _garageID] call A4A_fnc_garageInit;
    Or via 3DEN module: automatically called for synced objects.
*/
params [
    ["_object", objNull, [objNull]],
    ["_garageID", "Default", [""]]
];

// Initialization may be distributed only by the server/module path.
if (isRemoteExecuted && {remoteExecutedOwner != 2}) exitWith {
    diag_log format ["A4A_Garage: rejected client-authored garageInit from owner %1", remoteExecutedOwner];
};

if (isNull _object) exitWith {
    diag_log "A4A_Garage: Error - null object in garageInit";
};

// Don't re-init
if (_object getVariable ["A4A_Garage_Initialized", false]) exitWith {};
_object setVariable ["A4A_Garage_Initialized", true];

// Set ID on object (don't overwrite if already set by module)
private _existingID = _object getVariable ["A4A_Garage_ID", ""];
if (_existingID isEqualTo "") then {
    _object setVariable ["A4A_Garage_ID", _garageID, true];
} else {
    _garageID = _existingID;
};

diag_log format ["A4A_Garage: Init object %1 with ID '%2'", _object, _garageID];

// Server: init garage data
if (isServer) then {
    // Ensure server logic exists
    if (isNil "server") then {
        server = (createGroup sideLogic) createUnit ["Logic", [0,0,0], [], 0, "NONE"];
        publicVariable "server";
    };
    private _registry = localNamespace getVariable ["A4A_Garage_ServerRegistry", []];
    private _registryIndex = _registry findIf {(_x select 0) isEqualTo _object};
    if (_registryIndex < 0) then {
        _registry pushBack [_object, _garageID];
    } else {
        _registry set [_registryIndex, [_object, _garageID]];
    };
    localNamespace setVariable ["A4A_Garage_ServerRegistry", _registry];
    // This call inherits the server-originated remote context. The dispatcher
    // admits only owner-2 initServer as the narrowly trusted bootstrap mode.
    ["initServer", [_garageID]] call A4A_fnc_garage;
};

// Client: add actions
if (hasInterface) then {
    // Open garage action
    _object addAction [
        "<t color='#80d0ff'>Garage</t>",
        {
            params ["_target"];
            missionNamespace setVariable ["A4A_GRG_object", _target];
            ["open"] call A4A_fnc_garage;
        },
        [],
        6,
        true,
        false,
        "",
        "alive _target && {_target distance _this < 5} && {vehicle player == player}"
    ];

    systemChat format ["Garage '%1' ready on %2", _garageID, typeOf _object];
};
