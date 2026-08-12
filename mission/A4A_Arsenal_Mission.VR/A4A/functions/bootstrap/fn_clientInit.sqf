if (!hasInterface || isRemoteExecuted) exitWith {};

private _runClientInit = false;
isNil {
    if !(localNamespace getVariable ["A4A_ClientInitDone", false]) then {
        localNamespace setVariable ["A4A_ClientInitDone", true];
        _runClientInit = true;
    };
};
if (!_runClientInit) exitWith {};

[] spawn {
    waitUntil { !isNull player && {time >= 0} };

    private _rows = call compile preprocessFileLineNumbers "A4A\config\arsenals.sqf";
    if !(_rows isEqualType []) exitWith {
        diag_log "[A4A Mission] Client arsenal configuration is not an array";
    };

    {
        if (_x isEqualType [] && {count _x isEqualTo 3}) then {
            _x params ["_variableName", "_arsenalId", "_threshold"];
            if (_variableName isEqualType "" && {_variableName isNotEqualTo ""}) then {
                private _object = missionNamespace getVariable [_variableName, objNull];
                if (!isNull _object) then {
                    if (!isNil "A4A_fnc_openAction") then {
                        [_object, _arsenalId] call A4A_fnc_openAction;
                    };
                    if (!isNil "A4A_fnc_addCargoActions") then {
                        [_object, _arsenalId] call A4A_fnc_addCargoActions;
                    };
                };
            };
        };
    } forEach _rows;

    if (!isNil "A4A_fnc_initCbaSettings") then {
        [] call A4A_fnc_initCbaSettings;
    };
};

