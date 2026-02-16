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

private _arsenalID = _arsenalObj getVariable ["A3A_Arsenal_ID", "Base"];
private _playerListKey = format ["jna_playersInArsenal_%1", _arsenalID];

_temp = server getVariable [_playerListKey, []];
_temp = _temp - [_clientOwner];
server setVariable [_playerListKey, _temp, true];

// Also save arsenal data to profile on close
private _serverKey = format ["jna_dataList_%1", _arsenalID];
private _data = server getVariable [_serverKey, []];
if (count _data == 27) then {
    profileNamespace setVariable [format ["A3A_ArsenalData_%1", _arsenalID], _data];
    saveProfileNamespace;
};