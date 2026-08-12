if (!hasInterface || isRemoteExecuted) exitWith {};

private _runClientInit = false;
isNil {
    if !(localNamespace getVariable ["A4A_ClientInitDone", false]) then {
        localNamespace setVariable ["A4A_ClientInitDone", true];
        _runClientInit = true;
    };
};
if (!_runClientInit) exitWith {};

private _defaultThreshold = 25;
private _clientSettings = call compile preprocessFileLineNumbers "A4A\config\settings.sqf";
if (_clientSettings isEqualType createHashMap) then {
    _defaultThreshold = _clientSettings getOrDefault ["unlockThreshold", 25];
};
A4A_guestItemLimit = _defaultThreshold;
jna_minItemMember = [];
jna_minItemMember resize 27;
for "_index" from 0 to 26 do { jna_minItemMember set [_index, _defaultThreshold] };
jna_minItemMember set [23, _defaultThreshold * 3];
jna_minItemMember set [24, _defaultThreshold * 3];

[missionNamespace, "arsenalOpened", {
    disableSerialization;
    private _session = localNamespace getVariable ["A4A_ClientSession", []];
    if !(_session isEqualType createHashMap) exitWith {};
    private _display = _this param [0, displayNull, [displayNull]];
    if (isNull _display) exitWith {};
    uiNamespace setVariable ["arsenalDisplay", _display];
    ["CustomInit", [_display]] call jn_fnc_arsenal;
}] call BIS_fnc_addScriptedEventHandler;

[missionNamespace, "arsenalClosed", {
    private _session = localNamespace getVariable ["A4A_ClientSession", []];
    if !(_session isEqualType createHashMap) exitWith {};
    private _object = _session getOrDefault ["object", objNull];
    private _requestNonce = _session getOrDefault ["requestNonce", ""];
    private _generation = _session getOrDefault ["generation", -1];
    localNamespace setVariable ["A4A_ClientSession", []];
    uiNamespace setVariable ["jn_type", ""];
    if (!isNull _object && {_requestNonce isNotEqualTo ""} && {_generation >= 0}) then {
        if (isServer) then {
            [_object, _requestNonce, _generation] call A4A_fnc_requestClose;
        } else {
            [_object, _requestNonce, _generation] remoteExecCall ["A4A_fnc_requestClose", 2];
        };
    };
}] call BIS_fnc_addScriptedEventHandler;

arsenalInit = true;

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
