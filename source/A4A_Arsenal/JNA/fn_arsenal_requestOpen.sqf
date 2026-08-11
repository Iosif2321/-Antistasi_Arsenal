/*
	Author: Jeroen Notenbomer

	Description:
	Sends a command to the client to open the arsenal. It also adds the client to the serverlist so it knows with players need to be updated if a item gets removed/added. This command needs to be excuted on the server!

	Parameter(s):
	0: ID clientOwner
	1: OBJECT arsenalObject (optional, for multi-arsenal support)

	Returns:
	NOTHING, well it sends a command which contains the JNA_datalist
*/
#include "..\script_component.hpp"

if(!isServer)exitWith{};
params ["_clientOwner", ["_arsenalObj", objNull, [objNull]], ["_uiStyle", 0, [0]]];

private _networkRequest = isRemoteExecuted;
if (_networkRequest && {canSuspend}) exitWith {
    diag_log format ["A4A_Arsenal: requestOpen rejected scheduled call from owner %1", remoteExecutedOwner];
};
private _localHostRequest = !_networkRequest && {hasInterface} && {!isDedicated} && {_clientOwner isEqualTo clientOwner};
if (!_networkRequest && {!_localHostRequest}) exitWith {
    diag_log "A4A_Arsenal: requestOpen rejected non-network invocation";
};
if (_networkRequest) then {
    _clientOwner = remoteExecutedOwner;
};

private _requestPlayer = objNull;
{
    if (
        isPlayer _x
        && {!(_x isKindOf "VirtualMan_F")}
        && {!(_x isKindOf "HeadlessClient_F")}
        && {!((getPlayerUID _x) isEqualTo "")}
        && {(owner _x) isEqualTo _clientOwner}
    ) exitWith {
        _requestPlayer = _x;
    };
} forEach allPlayers;

if (_localHostRequest) then {
    if (
        isPlayer player
        && {!isNull player}
        && {local player}
        && {!((getPlayerUID player) isEqualTo "")}
    ) then {
        _requestPlayer = player;
    };
};

if (isNull _requestPlayer) exitWith {
    diag_log format ["A4A_Arsenal: requestOpen rejected; no player owns network client %1", _clientOwner];
};
private _serverArsenalRegistry = localNamespace getVariable ["A4A_Arsenal_ServerRegistry", []];
private _registryIndex = _serverArsenalRegistry findIf {
    (_x select 0) isEqualTo _arsenalObj
};
if (
    isNull _arsenalObj
    || {_registryIndex < 0}
    || {!alive _requestPlayer}
    || {_requestPlayer distance _arsenalObj > 10}
    || {vehicle _requestPlayer != _requestPlayer}
) exitWith {
    diag_log format ["A4A_Arsenal: requestOpen rejected for %1 (owner %2); invalid object, state, or distance", name _requestPlayer, _clientOwner];
};

private _readyObjects = localNamespace getVariable ["A4A_Arsenal_ServerReadyObjects", []];
if !(_arsenalObj in _readyObjects) exitWith {
    private _message = "Arsenal data is still loading on the server. Try again in a moment.";
    diag_log format ["A4A_Arsenal: requestOpen deferred for %1 (owner %2); server data is not ready", name _requestPlayer, _clientOwner];
    if (_clientOwner isEqualTo clientOwner && {hasInterface} && {!isDedicated}) then {
        localNamespace setVariable ["A4A_Arsenal_ServerDispatcherAuthorized", true];
        ["ServerInvalidate", [_message]] call jn_fnc_arsenal;
        localNamespace setVariable ["A4A_Arsenal_ServerDispatcherAuthorized", false];
    } else {
        ["ServerInvalidate", [_message]] remoteExecCall ["jn_fnc_arsenal", _clientOwner];
    };
};

// Resolve the canonical ID only from the private server registry.
private _arsenalID = (_serverArsenalRegistry select _registryIndex) select 1;
private _defaultData = [[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[]];

// Load only from private canonical server state.
private _serverData = localNamespace getVariable ["A4A_Arsenal_ServerData", createHashMap];
private _data = _serverData getOrDefault [_arsenalID, _defaultData];

// Private server-side binding used by later sender validation. Never trust a
// client-supplied arsenal ID as session authority.
private _sessions = localNamespace getVariable ["A4A_Arsenal_ServerSessions", createHashMap];
private _serverRevisions = localNamespace getVariable ["A4A_Arsenal_ServerRevisions", createHashMap];
private _revision = _serverRevisions getOrDefault [_arsenalID, 0];
_sessions set [str _clientOwner, [_arsenalObj, _arsenalID, diag_tickTime, getPlayerUID _requestPlayer, _revision]];
localNamespace setVariable ["A4A_Arsenal_ServerSessions", _sessions];

// ACE is a client UI capability. The server only routes the requested style;
// OpenACE performs the actual client-local capability/fallback check.
private _useAce = _uiStyle isEqualTo 1;
private _mode = if (_useAce) then { "OpenACE" } else { "Open" };
private _payload = if (_useAce) then { [+_data, _arsenalObj] } else { [+_data] };

diag_log format ["A4A_Arsenal: requestOpen client=%1 mode=%2 uiStyle=%3", _clientOwner, _mode, _uiStyle];
if (_clientOwner == clientOwner) then {
    // Hosted-server UI state belongs only to the local host's own session.
    jna_dataList = +_data;
    localNamespace setVariable ["A4A_Arsenal_ServerDispatcherAuthorized", true];
    [_mode, _payload] call jn_fnc_arsenal;
    localNamespace setVariable ["A4A_Arsenal_ServerDispatcherAuthorized", false];
} else {
    [_mode, _payload] remoteExecCall ["jn_fnc_arsenal", _clientOwner];
};

