params [
    ["_requestId", "", [""]],
    ["_success", false, [false]],
    ["_message", "", [""]],
    ["_revision", -1, [0]]
];

private _serverAuth = if (isRemoteExecuted) then { remoteExecutedOwner isEqualTo 2 } else { isServer && {hasInterface} };
if (!_serverAuth || {_requestId isEqualTo ""}) exitWith {};

private _pending = localNamespace getVariable ["A4A_ClientPendingCargo", createHashMap];
if (isNil {_pending get _requestId}) exitWith {};
_pending deleteAt _requestId;
localNamespace setVariable ["A4A_ClientPendingCargo", _pending];

if (_message isEqualTo "") then {
    _message = ["Cargo transaction failed.", "Cargo transaction completed."] select _success;
};
systemChat _message;
