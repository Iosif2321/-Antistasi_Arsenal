params [
    ["_arsenalId", "", [""]],
    ["_revision", -1, [0]],
    ["_data", [], [[]]],
    ["_excludedOwner", -1, [0]],
    ["_message", "Arsenal stock changed on the server.", [""]]
];
if (!isServer || {_arsenalId isEqualTo ""} || {_revision < 0} || {count _data isNotEqualTo 27}) exitWith {};

private _sessions = localNamespace getVariable ["A4A_ServerSessions", createHashMap];
{
    private _ownerKey = _x;
    private _session = _sessions get _ownerKey;
    if (
        _session isEqualType createHashMap &&
        {(_session getOrDefault ["arsenalId", ""]) isEqualTo _arsenalId}
    ) then {
        private _targetOwner = parseNumber _ownerKey;
        if (_targetOwner isNotEqualTo _excludedOwner) then {
            private _generation = _session getOrDefault ["generation", -1];
            private _payload = ["", "sync", true, _generation, _revision, parseSimpleArray str _data, false, _message];
            if (isServer && {hasInterface} && {_targetOwner isEqualTo clientOwner}) then {
                _payload call A4A_fnc_receiveTransactionResult;
            } else {
                _payload remoteExecCall ["A4A_fnc_receiveTransactionResult", _targetOwner];
            };
        };
    };
} forEach keys _sessions;
