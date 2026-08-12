params [
    ["_arsenalObject", objNull, [objNull]],
    ["_arsenalId", "", [""]]
];
if (!hasInterface || {isRemoteExecuted} || {isNull _arsenalObject} || {_arsenalId isEqualTo ""}) exitWith { [] };

private _actionKey = format ["cargo:%1", netId _arsenalObject];
private _actionIds = localNamespace getVariable ["A4A_ClientActionIds", createHashMap];
if (!isNil {_actionIds get _actionKey}) exitWith { _actionIds get _actionKey };

private _submit = {
    params ["_target", "_kind", "_manifest"];
    private _holder = cursorObject;
    if (isNull _holder || {_holder isEqualTo _target}) exitWith {
        systemChat "Look at a nearby cargo crate or empty vehicle first.";
    };
    private _requestId = format ["cargo:%1:%2:%3", clientOwner, floor (diag_tickTime * 1000), floor random 1000000000];
    private _pending = localNamespace getVariable ["A4A_ClientPendingCargo", createHashMap];
    _pending set [_requestId, [_kind, _holder, diag_tickTime]];
    localNamespace setVariable ["A4A_ClientPendingCargo", _pending];

    if (_kind isEqualTo "deposit") then {
        if (isServer) then {
            [_target, _holder, _requestId] call A4A_fnc_requestCargoDeposit;
        } else {
            [_target, _holder, _requestId] remoteExecCall ["A4A_fnc_requestCargoDeposit", 2];
        };
    } else {
        if (isServer) then {
            [_target, _holder, _requestId, _manifest] call A4A_fnc_requestCargoWithdraw;
        } else {
            [_target, _holder, _requestId, _manifest] remoteExecCall ["A4A_fnc_requestCargoWithdraw", 2];
        };
    };

    [_requestId] spawn {
        params ["_pendingId"];
        uiSleep 12;
        private _pendingRequests = localNamespace getVariable ["A4A_ClientPendingCargo", createHashMap];
        if (!isNil {_pendingRequests get _pendingId}) then {
            _pendingRequests deleteAt _pendingId;
            localNamespace setVariable ["A4A_ClientPendingCargo", _pendingRequests];
            systemChat "Cargo transaction timed out without a server result.";
        };
    };
};

private _depositAction = _arsenalObject addAction [
    format ["Deposit looked-at cargo into Arsenal (%1)", _arsenalId],
    {
        params ["_target", "_caller", "_actionId", "_arguments"];
        _arguments params ["_configuredId", "_submit"];
        if (_caller isEqualTo player) then { [_target, "deposit", []] call _submit };
    },
    [_arsenalId, _submit],
    5.5,
    true,
    true,
    "",
    "alive _this && {vehicle _this isEqualTo _this} && {_target distance _this <= 5} && {!isNull cursorObject} && {cursorObject isNotEqualTo _target} && {_this distance cursorObject <= 15}"
];

private _withdrawAction = _arsenalObject addAction [
    format ["Load looked-at cargo with a copy of my kit (%1)", _arsenalId],
    {
        params ["_target", "_caller", "_actionId", "_arguments"];
        _arguments params ["_configuredId", "_submit"];
        if (_caller isNotEqualTo player) exitWith {};

        private _loadoutData = [player, true] call jn_fnc_arsenal_cargoToArray;
        private _manifest = [];
        {
            private _index = _forEachIndex;
            {
                if (_x isEqualType [] && {count _x isEqualTo 2}) then {
                    private _className = _x select 0;
                    private _amount = _x select 1;
                    if (_className isEqualType "" && {_className isNotEqualTo ""} && {_amount > 0}) then {
                        _manifest pushBack [_index, _className, _amount];
                    };
                };
            } forEach _x;
        } forEach _loadoutData;

        if (count _manifest isEqualTo 0) exitWith {
            systemChat "Your current equipment produced an empty cargo manifest.";
        };
        [_target, "withdraw", _manifest] call _submit;
    },
    [_arsenalId, _submit],
    5.4,
    true,
    true,
    "",
    "alive _this && {vehicle _this isEqualTo _this} && {_target distance _this <= 5} && {!isNull cursorObject} && {cursorObject isNotEqualTo _target} && {_this distance cursorObject <= 15}"
];

private _createdActions = [_depositAction, _withdrawAction];
_actionIds set [_actionKey, _createdActions];
localNamespace setVariable ["A4A_ClientActionIds", _actionIds];
_createdActions
