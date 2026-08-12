/*
    ACE3 is presentation-only in the mission edition. Finite quantitative stock
    remains on the correlated Legacy transaction path. This file therefore
    owns only proxy identity and display lifecycle; it never authorizes stock.
*/

A4A_fnc_arsenal_aceOwnsCurrentBox = {
    private _state = localNamespace getVariable ["A4A_ClientAceProxyState", []];
    private _session = localNamespace getVariable ["A4A_ClientSession", []];
    if !(_state isEqualType createHashMap && {_session isEqualType createHashMap}) exitWith { false };

    private _proxy = _state getOrDefault ["proxy", objNull];
    private _generation = _state getOrDefault ["generation", -1];
    !isNull _proxy &&
    {_generation >= 1} &&
    {(_session getOrDefault ["generation", -1]) isEqualTo _generation} &&
    {(missionNamespace getVariable ["ace_arsenal_currentBox", objNull]) isEqualTo _proxy}
};

A4A_fnc_arsenal_aceOnDataListUpdate = {
    // ACE is opened only for all-unlimited snapshots, so there is no mutable
    // finite stock list to mirror into its panels.
};

A4A_fnc_arsenal_aceBeginSession = {
    params ["_originalObject", "_proxy"];
    private _session = localNamespace getVariable ["A4A_ClientSession", []];
    if !(_session isEqualType createHashMap && {!isNull _originalObject} && {!isNull _proxy}) exitWith { false };

    private _items = [];
    {
        {
            if (_x isEqualType [] && {count _x isEqualTo 2} && {(_x select 1) isEqualTo -1}) then {
                _items pushBackUnique (_x select 0);
            };
        } forEach _x;
    } forEach jna_dataList;
    if (count _items isEqualTo 0 || {isNil "ace_arsenal_fnc_addVirtualItems"}) exitWith { false };
    [_proxy, _items, false] call ace_arsenal_fnc_addVirtualItems;

    localNamespace setVariable ["A4A_ClientAceProxyState", createHashMapFromArray [
        ["originalObject", _originalObject],
        ["proxy", _proxy],
        ["requestNonce", _session getOrDefault ["requestNonce", ""]],
        ["generation", _session getOrDefault ["generation", -1]],
        ["openedAt", diag_tickTime]
    ]];
    missionNamespace setVariable ["A4A_aceStock_active", true];
    missionNamespace setVariable ["A4A_aceStock_arsenalObj", _originalObject];
    missionNamespace setVariable ["A4A_aceStock_box", _proxy];
    true
};

A4A_fnc_arsenal_aceEndSession = {
    [-1, true] call A4A_fnc_closeAceProxy
};

A4A_fnc_arsenal_aceRegisterHandlers = {
    if (!hasInterface || {isNil "CBA_fnc_addEventHandler"}) exitWith { false };
    if (localNamespace getVariable ["A4A_ClientAceHandlersRegistered", false]) exitWith { true };

    ["ace_arsenal_displayClosed", {
        if ([] call A4A_fnc_arsenal_aceOwnsCurrentBox) then {
            private _state = localNamespace getVariable ["A4A_ClientAceProxyState", []];
            private _generation = _state getOrDefault ["generation", -1];
            [_generation, true] call A4A_fnc_closeAceProxy;
        };
    }] call CBA_fnc_addEventHandler;

    localNamespace setVariable ["A4A_ClientAceHandlersRegistered", true];
    true
};

if (hasInterface && {!isNil "ace_arsenal_fnc_openBox"}) then {
    [] call A4A_fnc_arsenal_aceRegisterHandlers;
};

true
