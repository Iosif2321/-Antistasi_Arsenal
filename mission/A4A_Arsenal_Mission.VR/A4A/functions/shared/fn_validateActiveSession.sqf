params [
    ["_senderOwner", -1, [0]],
    ["_requestPlayer", objNull, [objNull]],
    ["_object", objNull, [objNull]],
    ["_requestNonce", "", [""]],
    ["_generation", -1, [0]]
];

if (!isServer || {isNull _requestPlayer} || {isNull _object}) exitWith { [false, [], "", []] };

private _ownerKey = str _senderOwner;
private _sessions = localNamespace getVariable ["A4A_ServerSessions", createHashMap];
if (isNil {_sessions get _ownerKey}) exitWith { [false, [], _ownerKey, []] };

private _session = _sessions get _ownerKey;
if !(_session isEqualType createHashMap) exitWith { [false, [], _ownerKey, []] };

private _valid =
    (_session getOrDefault ["object", objNull]) isEqualTo _object &&
    {(_session getOrDefault ["requestNonce", ""]) isEqualTo _requestNonce} &&
    {(_session getOrDefault ["generation", -1]) isEqualTo _generation} &&
    {(_session getOrDefault ["playerUID", ""]) isEqualTo getPlayerUID _requestPlayer} &&
    {diag_tickTime <= (_session getOrDefault ["expiresAt", -1])};
if (!_valid) exitWith { [false, _session, _ownerKey, []] };

private _registry = localNamespace getVariable ["A4A_ServerRegistry", createHashMap];
private _objectKey = netId _object;
if (isNil {_registry get _objectKey}) exitWith { [false, _session, _ownerKey, []] };
private _canonical = _registry get _objectKey;
if !(_canonical isEqualType [] && {count _canonical isEqualTo 3} && {(_canonical select 0) isEqualTo _object}) exitWith {
    [false, _session, _ownerKey, []]
};

private _arsenalId = _canonical select 1;
private _ready = localNamespace getVariable ["A4A_ServerReady", createHashMap];
private _settings = localNamespace getVariable ["A4A_ServerSettings", createHashMap];
private _maxDistance = _settings getOrDefault ["interactionDistance", 5];
if (
    !(_ready getOrDefault [_arsenalId, false]) ||
    {!alive _requestPlayer} ||
    {_requestPlayer distance _object > _maxDistance}
) exitWith { [false, _session, _ownerKey, _canonical] };

private _sessionLifetime = _settings getOrDefault ["sessionLifetime", 30];
_session set ["expiresAt", diag_tickTime + _sessionLifetime];
_sessions set [_ownerKey, _session];
localNamespace setVariable ["A4A_ServerSessions", _sessions];

[true, _session, _ownerKey, _canonical]
