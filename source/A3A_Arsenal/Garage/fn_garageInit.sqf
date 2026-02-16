/*
    Initialize garage on an object.
    Call: [_object, _garageID] call A3A_fnc_garageInit;
    Or via 3DEN module: automatically called for synced objects.
*/
params [
    ["_object", objNull, [objNull]],
    ["_garageID", "Default", [""]]
];

if (isNull _object) exitWith {
    diag_log "A3A_Garage: Error - null object in garageInit";
};

// Don't re-init
if (_object getVariable ["A3A_Garage_Initialized", false]) exitWith {};
_object setVariable ["A3A_Garage_Initialized", true];

// Set ID on object (don't overwrite if already set by module)
private _existingID = _object getVariable ["A3A_Garage_ID", ""];
if (_existingID isEqualTo "") then {
    _object setVariable ["A3A_Garage_ID", _garageID, true];
} else {
    _garageID = _existingID;
};

diag_log format ["A3A_Garage: Init object %1 with ID '%2'", _object, _garageID];

// Server: init garage data
if (isServer) then {
    // Ensure server logic exists
    if (isNil "server") then {
        server = (createGroup sideLogic) createUnit ["Logic", [0,0,0], [], 0, "NONE"];
        publicVariable "server";
    };
    ["initServer", [_garageID]] call A3A_fnc_garage;
};

// Client: add actions
if (hasInterface) then {
    // Open garage action
    _object addAction [
        "<t color='#80d0ff'>Garage</t>",
        {
            params ["_target"];
            missionNamespace setVariable ["A3A_GRG_object", _target];
            ["open"] call A3A_fnc_garage;
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
