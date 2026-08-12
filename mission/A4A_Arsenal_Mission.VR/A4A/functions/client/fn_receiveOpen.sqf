params [
    ["_object", objNull, [objNull]],
    ["_requestNonce", "", [""]],
    ["_generation", -1, [0]],
    ["_revision", -1, [0]],
    ["_snapshot", [], [[]]],
    ["_presentationMode", "Auto", [""]]
];

private _serverAuth = if (isRemoteExecuted) then {
    remoteExecutedOwner isEqualTo 2
} else {
    isServer && {hasInterface}
};
if (!_serverAuth || {isNull _object} || {_requestNonce isEqualTo ""} || {_generation < 1} || {_revision < 0}) exitWith {};
if !(count _snapshot isEqualTo 27 && {_snapshot findIf {!(_x isEqualType [])} < 0}) exitWith {};

private _pending = localNamespace getVariable ["A4A_ClientPendingRequests", createHashMap];
if (isNil {_pending get _requestNonce}) exitWith {};
private _pendingRequest = _pending get _requestNonce;
if !(
    _pendingRequest isEqualType [] &&
    {count _pendingRequest >= 2} &&
    {(_pendingRequest select 0) isEqualTo _object} &&
    {diag_tickTime - (_pendingRequest select 1) <= 15}
) exitWith {
    _pending deleteAt _requestNonce;
    localNamespace setVariable ["A4A_ClientPendingRequests", _pending];
};
_pending deleteAt _requestNonce;
localNamespace setVariable ["A4A_ClientPendingRequests", _pending];

private _session = createHashMapFromArray [
    ["object", _object],
    ["requestNonce", _requestNonce],
    ["generation", _generation],
    ["revision", _revision],
    ["presentationMode", _presentationMode]
];
localNamespace setVariable ["A4A_ClientSession", _session];
missionNamespace setVariable ["jna_object", _object];
jna_dataList = parseSimpleArray str _snapshot;

private _meta = _object getVariable ["A4A_Arsenal_MissionMeta", ["", 25]];
private _threshold = _meta param [1, 25, [0]];
A4A_guestItemLimit = _threshold;
jna_minItemMember = [];
jna_minItemMember resize 27;
for "_index" from 0 to 26 do { jna_minItemMember set [_index, _threshold] };
jna_minItemMember set [23, _threshold * 3];
jna_minItemMember set [24, _threshold * 3];
uiNamespace setVariable ["jn_type", "arsenal"];

[_presentationMode] spawn {
    params ["_mode"];
    if !(localNamespace getVariable ["A4A_ClientLegacyPreloaded", false]) then {
        ["Preload"] call jn_fnc_arsenal;
        localNamespace setVariable ["A4A_ClientLegacyPreloaded", true];
    };

    private _style = ["uiStyle", "Legacy"] call A4A_fnc_getSetting;
    private _useAce = _style in ["ACE", 1] && {!isNil "A4A_fnc_openAceProxy"};
    if (_useAce) then {
        [] call A4A_fnc_openAceProxy;
    } else {
        ["Open", [jna_dataList]] call jn_fnc_arsenal;
    };
};

