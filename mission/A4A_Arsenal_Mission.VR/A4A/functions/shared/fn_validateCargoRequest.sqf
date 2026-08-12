params [
    ["_arsenalObject", objNull, [objNull]],
    ["_holder", objNull, [objNull]]
];
if (!isServer || {isRemoteExecuted && {canSuspend}}) exitWith { [false, objNull, -1, false, [], ""] };

private _localHostCall = !isRemoteExecuted && {hasInterface} && {!isNull player};
if (!isRemoteExecuted && {!_localHostCall}) exitWith { [false, objNull, -1, false, [], ""] };
private _senderOwner = if (_localHostCall) then { clientOwner } else { remoteExecutedOwner };
private _requestPlayer = [_senderOwner, _localHostCall] call A4A_fnc_resolveRemotePlayer;
if (isNull _requestPlayer || {isNull _arsenalObject} || {isNull _holder}) exitWith {
    [false, _requestPlayer, _senderOwner, _localHostCall, [], ""]
};

private _holderKey = netId _holder;
private _registry = localNamespace getVariable ["A4A_ServerRegistry", createHashMap];
private _arsenalKey = netId _arsenalObject;
if (isNil {_registry get _arsenalKey}) exitWith { [false, _requestPlayer, _senderOwner, _localHostCall, [], _holderKey] };
private _canonical = _registry get _arsenalKey;
if !(_canonical isEqualType [] && {count _canonical isEqualTo 3} && {(_canonical select 0) isEqualTo _arsenalObject}) exitWith {
    [false, _requestPlayer, _senderOwner, _localHostCall, [], _holderKey]
};

private _arsenalId = _canonical select 1;
private _ready = localNamespace getVariable ["A4A_ServerReady", createHashMap];
private _settings = localNamespace getVariable ["A4A_ServerSettings", createHashMap];
private _interactionDistance = _settings getOrDefault ["interactionDistance", 5];
private _cargoDistance = _settings getOrDefault ["cargoDistance", 15];
private _holderConfig = configFile >> "CfgVehicles" >> typeOf _holder;
private _hasCargo =
    getNumber (_holderConfig >> "maximumLoad") > 0 ||
    {getNumber (_holderConfig >> "transportMaxBackpacks") > 0} ||
    {getNumber (_holderConfig >> "transportMaxMagazines") > 0} ||
    {getNumber (_holderConfig >> "transportMaxWeapons") > 0};

if (
    !(_ready getOrDefault [_arsenalId, false]) ||
    {_holderKey isEqualTo "" || {_holderKey isEqualTo "0:0"}} ||
    {!alive _requestPlayer} ||
    {vehicle _requestPlayer isNotEqualTo _requestPlayer} ||
    {_requestPlayer distance _arsenalObject > _interactionDistance} ||
    {_requestPlayer distance _holder > _cargoDistance} ||
    {_arsenalObject distance _holder > (_cargoDistance + _interactionDistance)} ||
    {!_hasCargo} ||
    {count crew _holder > 0}
) exitWith { [false, _requestPlayer, _senderOwner, _localHostCall, _canonical, _holderKey] };

if (!local _holder) then { _holder setOwner 2 };
if (!local _holder) exitWith { [false, _requestPlayer, _senderOwner, _localHostCall, _canonical, _holderKey] };

[true, _requestPlayer, _senderOwner, _localHostCall, _canonical, _holderKey]

