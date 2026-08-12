params [
    ["_generation", -1, [0]],
    ["_message", "Arsenal session was invalidated by the server.", [""]]
];

private _serverAuth = if (isRemoteExecuted) then { remoteExecutedOwner isEqualTo 2 } else { isServer && {hasInterface} };
if (!_serverAuth) exitWith {};

private _session = localNamespace getVariable ["A4A_ClientSession", []];
if !(_session isEqualType createHashMap) exitWith {};
if (_generation >= 0 && {(_session getOrDefault ["generation", -1]) isNotEqualTo _generation}) exitWith {};

localNamespace setVariable ["A4A_ClientSession", []];
jna_dataList = [];
private _display = uiNamespace getVariable ["arsenalDisplay", displayNull];
if (!isNull _display) then { _display closeDisplay 2 };
if (missionNamespace getVariable ["A4A_aceStock_active", false] && {!isNil "A4A_fnc_closeAceProxy"}) then {
    [-1, false] call A4A_fnc_closeAceProxy;
};
private _loadingIds = missionNamespace getVariable ["BIS_fnc_startLoadingScreen_ids", []];
if ("jn_fnc_arsenal" in _loadingIds) then { ["jn_fnc_arsenal"] call BIS_fnc_endLoadingScreen };
systemChat _message;
