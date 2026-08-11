/*
	Author: Jeroen Notenbomer

	Description:
	Removes to client from the servers list so it doesnt get called when the arsenal gets updated. This command needs to be excuted on the server!

	Parameter(s):
	0: ID clientOwner
	1: OBJECT arsenalObject (optional, for multi-arsenal support)

	Returns:
	NOTHING, well it sends a command which contains the JNA_datalist
*/

if(!isServer)exitWith{};
params ["_clientOwner", ["_arsenalObj", objNull, [objNull]]];

private _networkRequest = isRemoteExecuted;
if (_networkRequest && {canSuspend}) exitWith {
    diag_log format ["A4A_Arsenal: requestClose rejected scheduled call from owner %1", remoteExecutedOwner];
};
private _localHostRequest = !_networkRequest && {hasInterface} && {!isDedicated} && {_clientOwner isEqualTo clientOwner};
if (!_networkRequest && {!_localHostRequest}) exitWith {
    diag_log "A4A_Arsenal: requestClose rejected non-network invocation";
};
if (_networkRequest) then {
    _clientOwner = remoteExecutedOwner;
};

private _sessions = localNamespace getVariable ["A4A_Arsenal_ServerSessions", createHashMap];
private _sessionKey = str _clientOwner;
private _session = _sessions getOrDefault [_sessionKey, []];
if (count _session < 2) exitWith {
    diag_log format ["A4A_Arsenal: requestClose rejected; owner %1 has no bound session", _clientOwner];
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
if (_localHostRequest) then {_requestPlayer = player};
if (
    isNull _requestPlayer
    || {count _session >= 4 && {!((_session select 3) isEqualTo getPlayerUID _requestPlayer)}}
) exitWith {
    diag_log format ["A4A_Arsenal: requestClose rejected; owner %1 does not match the bound player", _clientOwner];
};
private _boundArsenalObj = _session select 0;
private _serverArsenalObjects = localNamespace getVariable ["A4A_Arsenal_ServerObjects", []];
if (
    isNull _boundArsenalObj
    || {!(_arsenalObj isEqualTo _boundArsenalObj)}
    || {!(_boundArsenalObj in _serverArsenalObjects)}
) exitWith {
    diag_log format ["A4A_Arsenal: requestClose rejected for owner %1; invalid arsenal object", _clientOwner];
};
_arsenalObj = _boundArsenalObj;

private _arsenalID = _session select 1;
_sessions deleteAt _sessionKey;
localNamespace setVariable ["A4A_Arsenal_ServerSessions", _sessions];

// Also save arsenal data to profile on close
private _serverData = localNamespace getVariable ["A4A_Arsenal_ServerData", createHashMap];
private _data = _serverData getOrDefault [_arsenalID, []];
if (count _data == 27) then {
    profileNamespace setVariable [format ["A4A_ArsenalData_%1", _arsenalID], _data];
    localNamespace setVariable ["A4A_Arsenal_ProfileSaveAuthorized", true];
    [] call A4A_fnc_arsenal_scheduleProfileSave;
    localNamespace setVariable ["A4A_Arsenal_ProfileSaveAuthorized", false];
};
