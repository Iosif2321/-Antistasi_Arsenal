params [
    ["_expectedGeneration", -1, [0]],
    ["_notifyServer", true, [false]]
];
if (!hasInterface || {isRemoteExecuted}) exitWith { false };

private _state = localNamespace getVariable ["A4A_ClientAceProxyState", []];
if !(_state isEqualType createHashMap) exitWith { false };
private _generation = _state getOrDefault ["generation", -1];
if (_expectedGeneration >= 0 && {_generation isNotEqualTo _expectedGeneration}) exitWith { false };

private _originalObject = _state getOrDefault ["originalObject", objNull];
private _proxy = _state getOrDefault ["proxy", objNull];
private _requestNonce = _state getOrDefault ["requestNonce", ""];
localNamespace setVariable ["A4A_ClientAceProxyState", []];
missionNamespace setVariable ["A4A_aceStock_active", false];
missionNamespace setVariable ["A4A_aceStock_arsenalObj", nil];
missionNamespace setVariable ["A4A_aceStock_box", nil];

private _session = localNamespace getVariable ["A4A_ClientSession", []];
if (_session isEqualType createHashMap && {(_session getOrDefault ["generation", -1]) isEqualTo _generation}) then {
    localNamespace setVariable ["A4A_ClientSession", []];
};

if (!isNull _proxy && {(missionNamespace getVariable ["ace_arsenal_currentBox", objNull]) isEqualTo _proxy}) then {
    private _display = findDisplay 1127001;
    if (!isNull _display) then { _display closeDisplay 2 };
};

private _cleanup = {
    params ["_proxy"];
    if (!isNull _proxy) then {
        if (!isNil "ace_arsenal_fnc_removeVirtualItems") then {
            [_proxy, true, false] call ace_arsenal_fnc_removeVirtualItems;
        };
        deleteVehicle _proxy;
    };
};
if (!isNull _proxy) then {
    if (!isNil "CBA_fnc_execNextFrame") then {
        [_cleanup, [_proxy]] call CBA_fnc_execNextFrame;
    } else {
        [_proxy, _cleanup] spawn {
            params ["_proxy", "_cleanup"];
            uiSleep 0;
            [_proxy] call _cleanup;
        };
    };
};

["RestoreTFAR"] call jn_fnc_arsenal;
private _loadingIds = missionNamespace getVariable ["BIS_fnc_startLoadingScreen_ids", []];
if ("jn_fnc_arsenal" in _loadingIds) then { ["jn_fnc_arsenal"] call BIS_fnc_endLoadingScreen };

if (_notifyServer && {!isNull _originalObject} && {_requestNonce isNotEqualTo ""} && {_generation >= 1}) then {
    private _payload = [_originalObject, _requestNonce, _generation];
    _payload remoteExecCall ["A4A_fnc_requestClose", 2];
};

true
