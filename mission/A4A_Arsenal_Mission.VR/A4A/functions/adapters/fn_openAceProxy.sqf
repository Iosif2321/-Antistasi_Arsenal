if (!hasInterface || {isRemoteExecuted}) exitWith { false };

private _session = localNamespace getVariable ["A4A_ClientSession", []];
if !(_session isEqualType createHashMap) exitWith { false };
private _originalObject = _session getOrDefault ["object", objNull];
private _requestNonce = _session getOrDefault ["requestNonce", ""];
private _generation = _session getOrDefault ["generation", -1];
if (isNull _originalObject || {_requestNonce isEqualTo ""} || {_generation < 1}) exitWith { false };
if !(jna_dataList isEqualType [] && {count jna_dataList isEqualTo 27}) exitWith { false };

private _openLegacy = {
    ["Open", [jna_dataList]] call jn_fnc_arsenal;
    true
};

private _finiteStock = jna_dataList findIf {
    _x findIf {
        _x isEqualType [] && {count _x isEqualTo 2} && {(_x select 1) isNotEqualTo -1}
    } >= 0
} >= 0;
if (_finiteStock) exitWith {
    systemChat "Finite quantitative stock uses the transactional Legacy interface.";
    call _openLegacy
};

if (
    isNil "ace_arsenal_fnc_openBox" ||
    {isNil "ace_arsenal_fnc_addVirtualItems"} ||
    {isNil "ace_arsenal_fnc_removeVirtualItems"}
) exitWith {
    call _openLegacy
};

private _existingState = localNamespace getVariable ["A4A_ClientAceProxyState", []];
if (
    _existingState isEqualType createHashMap &&
    {(_existingState getOrDefault ["generation", -1]) isEqualTo _generation} &&
    {(_existingState getOrDefault ["originalObject", objNull]) isEqualTo _originalObject}
) exitWith { true };
if (_existingState isEqualType createHashMap) then {
    [-1, false] call A4A_fnc_closeAceProxy;
};

if (!isNull (findDisplay 1127001)) exitWith {
    systemChat "Close the current ACE Arsenal before opening the mission Arsenal.";
    private _payload = [_originalObject, _requestNonce, _generation];
    if (isServer) then { _payload call A4A_fnc_requestClose } else { _payload remoteExecCall ["A4A_fnc_requestClose", 2] };
    localNamespace setVariable ["A4A_ClientSession", []];
    false
};

private _items = [];
{
    {
        if (_x isEqualType [] && {count _x isEqualTo 2}) then {
            private _className = _x select 0;
            private _amount = _x select 1;
            if (_className isEqualType "" && {_className isNotEqualTo ""} && {_amount isEqualTo -1}) then {
                _items pushBackUnique _className;
            };
        };
    } forEach _x;
} forEach jna_dataList;
if (count _items isEqualTo 0) exitWith { call _openLegacy };

private _proxy = createVehicleLocal ["Land_HelipadEmpty_F", [0, 0, 0], [], 0, "CAN_COLLIDE"];
if (isNull _proxy) exitWith { call _openLegacy };
[_proxy, _items, false] call ace_arsenal_fnc_addVirtualItems;

private _state = createHashMapFromArray [
    ["originalObject", _originalObject],
    ["proxy", _proxy],
    ["requestNonce", _requestNonce],
    ["generation", _generation],
    ["openedAt", diag_tickTime]
];
localNamespace setVariable ["A4A_ClientAceProxyState", _state];
missionNamespace setVariable ["A4A_aceStock_active", true];
missionNamespace setVariable ["A4A_aceStock_arsenalObj", _originalObject];
missionNamespace setVariable ["A4A_aceStock_box", _proxy];

if (!isNil "A4A_fnc_arsenal_aceRegisterHandlers") then {
    [] call A4A_fnc_arsenal_aceRegisterHandlers;
};
["SaveTFAR"] call jn_fnc_arsenal;
private _loadingIds = missionNamespace getVariable ["BIS_fnc_startLoadingScreen_ids", []];
if ("jn_fnc_arsenal" in _loadingIds) then { ["jn_fnc_arsenal"] call BIS_fnc_endLoadingScreen };
[_proxy, player, false] call ace_arsenal_fnc_openBox;

[_proxy, _generation] spawn {
    params ["_expectedProxy", "_expectedGeneration"];
    private _bindDeadline = diag_tickTime + 3;
    waitUntil {
        uiSleep 0.05;
        private _state = localNamespace getVariable ["A4A_ClientAceProxyState", []];
        !(_state isEqualType createHashMap) ||
        {(_state getOrDefault ["generation", -1]) isNotEqualTo _expectedGeneration} ||
        {(missionNamespace getVariable ["ace_arsenal_currentBox", objNull]) isEqualTo _expectedProxy} ||
        {diag_tickTime >= _bindDeadline}
    };

    private _state = localNamespace getVariable ["A4A_ClientAceProxyState", []];
    if !(
        _state isEqualType createHashMap &&
        {(_state getOrDefault ["generation", -1]) isEqualTo _expectedGeneration} &&
        {(missionNamespace getVariable ["ace_arsenal_currentBox", objNull]) isEqualTo _expectedProxy}
    ) exitWith {
        [_expectedGeneration, true] call A4A_fnc_closeAceProxy;
    };

    waitUntil {
        uiSleep 0.2;
        private _currentState = localNamespace getVariable ["A4A_ClientAceProxyState", []];
        !(_currentState isEqualType createHashMap) ||
        {(_currentState getOrDefault ["generation", -1]) isNotEqualTo _expectedGeneration} ||
        {isNull (findDisplay 1127001)} ||
        {!((missionNamespace getVariable ["ace_arsenal_currentBox", objNull]) isEqualTo _expectedProxy)}
    };
    [_expectedGeneration, true] call A4A_fnc_closeAceProxy;
};

true
