/* Compatibility addAction handler routed into the mission-native open RPC. */
params [
    ["_target", objNull, [objNull]],
    ["_caller", objNull, [objNull]]
];
if (
    !hasInterface ||
    {isRemoteExecuted} ||
    {isNull _target} ||
    {_caller isNotEqualTo player} ||
    {!(missionNamespace getVariable ["arsenalInit", false])}
) exitWith {};

private _uiStyle = ["uiStyle", "Legacy"] call A4A_fnc_getSetting;
if (_uiStyle in ["ACE", 1] && {!isNull (findDisplay 1127001)}) exitWith {
    systemChat "Close the current ACE Arsenal before opening the mission Arsenal.";
};

private _closePending = localNamespace getVariable ["A4A_ClientClosePending", []];
if (_closePending isEqualType [] && {count _closePending > 0}) exitWith {
    systemChat "The previous Arsenal session is still finalizing.";
};
private _pending = localNamespace getVariable ["A4A_ClientPendingRequests", createHashMap];
if (count keys _pending > 0) exitWith {
    systemChat "An Arsenal open request is already in progress.";
};
private _requestNonce = format ["%1:%2:%3", clientOwner, floor (diag_tickTime * 1000), floor random 1000000000];
private _meta = _target getVariable ["A4A_Arsenal_MissionMeta", ["", 25]];
_pending set [_requestNonce, [_target, diag_tickTime, _meta param [0, ""]]];
localNamespace setVariable ["A4A_ClientPendingRequests", _pending];

["jn_fnc_arsenal", "Loading quantitative Arsenal"] call BIS_fnc_startLoadingScreen;
private _payload = [_target, _requestNonce];
_payload remoteExecCall ["A4A_fnc_requestOpen", 2];

[_requestNonce] spawn {
    params ["_nonce"];
    uiSleep 10;
    private _pendingRequests = localNamespace getVariable ["A4A_ClientPendingRequests", createHashMap];
    if (!isNil {_pendingRequests get _nonce}) then {
        _pendingRequests deleteAt _nonce;
        localNamespace setVariable ["A4A_ClientPendingRequests", _pendingRequests];
        private _loadingIds = missionNamespace getVariable ["BIS_fnc_startLoadingScreen_ids", []];
        if ("jn_fnc_arsenal" in _loadingIds) then { ["jn_fnc_arsenal"] call BIS_fnc_endLoadingScreen };
        systemChat "A4A Arsenal open request timed out.";
    };
};
