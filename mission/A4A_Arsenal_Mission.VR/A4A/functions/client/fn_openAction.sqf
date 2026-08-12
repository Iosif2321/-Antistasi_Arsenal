params [
    ["_object", objNull, [objNull]],
    ["_arsenalId", "", [""]]
];
if (!hasInterface || {isRemoteExecuted} || {isNull _object} || {_arsenalId isEqualTo ""}) exitWith { -1 };

private _actionKey = [_object] call A4A_fnc_objectKey;
if (_actionKey isEqualTo "") exitWith { -1 };
private _actionIds = localNamespace getVariable ["A4A_ClientActionIds", createHashMap];
if (!isNil {_actionIds get _actionKey}) exitWith { _actionIds get _actionKey };

private _actionId = _object addAction [
    format ["<img image='\a3\ui_f\data\GUI\Rsc\RscDisplayArsenal\spaceArsenal_ca.paa' size='1.6'/> <t>Open quantitative Arsenal (%1)</t>", _arsenalId],
    {
        params ["_target", "_caller", "_actionId", "_arguments"];
        _arguments params ["_configuredId"];
        if (_caller isNotEqualTo player) exitWith {};

        private _closePending = localNamespace getVariable ["A4A_ClientClosePending", []];
        if (_closePending isEqualType [] && {count _closePending > 0}) exitWith {
            systemChat "The previous Arsenal session is still finalizing.";
        };
        private _pending = localNamespace getVariable ["A4A_ClientPendingRequests", createHashMap];
        if (count keys _pending > 0) exitWith {
            systemChat "An Arsenal open request is already in progress.";
        };
        private _requestNonce = format ["%1:%2:%3", clientOwner, floor (diag_tickTime * 1000), floor random 1000000000];
        _pending set [_requestNonce, [_target, diag_tickTime, _configuredId]];
        localNamespace setVariable ["A4A_ClientPendingRequests", _pending];

        ["jn_fnc_arsenal", "Loading quantitative Arsenal"] call BIS_fnc_startLoadingScreen;
        [_target, _requestNonce] remoteExecCall ["A4A_fnc_requestOpen", 2];

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
    },
    [_arsenalId],
    6,
    true,
    true,
    "",
    "alive _this && {_target distance _this <= 5} && {vehicle _this isEqualTo _this}"
];

_actionIds set [_actionKey, _actionId];
localNamespace setVariable ["A4A_ClientActionIds", _actionIds];
_actionId
