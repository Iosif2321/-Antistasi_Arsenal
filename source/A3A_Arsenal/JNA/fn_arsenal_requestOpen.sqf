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
params ["_clientOwner", ["_arsenalObj", objNull, [objNull]]];

// Determine arsenal ID from the object
private _arsenalID = _arsenalObj getVariable ["A3A_Arsenal_ID", "Base"];
private _serverKey = format ["jna_dataList_%1", _arsenalID];
private _playerListKey = format ["jna_playersInArsenal_%1", _arsenalID];
private _defaultData = [[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[]];

// Load the correct arsenal data
private _data = server getVariable [_serverKey, _defaultData];

// Track player per-arsenal
_temp = server getVariable [_playerListKey, []];
_temp pushBackUnique _clientOwner;
server setVariable [_playerListKey, _temp, true];

// Also set global jna_dataList on server for save operations
jna_dataList = _data;

Info_1("_open arsenal for: clientOwner ",_clientOwner);
if (_clientOwner == clientOwner) then {
    ["Open",[_data]] call jn_fnc_arsenal;
} else {
    ["Open",[_data]] remoteExecCall ["jn_fnc_arsenal", _clientOwner];
};

