/**
	Handler for when the 'Arsenal' action is taken.
	
	Usage:
		_thing addAction ["Action", JN_fnc_arsenal_handleAction];
	
	Params:
		Same as any 'addAction' handler
**/

if !(missionNamespace getVariable ["arsenalInit", false]) exitWith {};

private _uiStyle = 0;
if (!isNil "CBA_fnc_getSetting") then {
	_uiStyle = ["A4A_Arsenal_UIStyle", 0] call CBA_fnc_getSetting;
} else {
	if (!isNil "A4A_Arsenal_UIStyle") then { _uiStyle = A4A_Arsenal_UIStyle; };
};
if (
	_uiStyle isEqualTo 1
	&& {
		missionNamespace getVariable ["A4A_aceStock_active", false]
		|| {!isNull (findDisplay 1127001)}
	}
) exitWith {
	systemChat "Close the current ACE Arsenal before opening A4A ACE Preview.";
	diag_log "A4A_Arsenal: handleAction rejected overlapping ACE Arsenal open";
};
diag_log format [
	"A4A_Arsenal: handleAction uiStyle=%1 (0=Legacy, 1=ACE) aceAvailable=%2",
	_uiStyle,
	!isNil "ace_arsenal_fnc_openBox"
];

missionNamespace setVariable ["jna_object", _this select 0];

// Antistasi UI dependencies removed
/*
if (isMenuOpen) then {
	[] call SCRT_fnc_ui_toggleCommanderMenu;
	private _display = findDisplay 60000;
	if (str (_display) != "no display") then {
		_display closeDisplay 1;
	};

	private _loadoutMenuDisplay = findDisplay 120000;
	if (str (_loadoutMenuDisplay) != "no display") then {
		_loadoutMenuDisplay closeDisplay 1;
	};

	['off'] call SCRT_fnc_ui_toggleMenuBlur;

	uiNamespace setVariable ["isLoadoutArsenal", true];
};
*/

//start loading screen
["jn_fnc_arsenal", "Loading Nutz Arsenal"] call bis_fnc_startloadingscreen;
[] spawn {
uisleep 10;
private _ids = missionnamespace getvariable ["BIS_fnc_startLoadingScreen_ids",[]];
  if("jn_fnc_arsenal" in _ids)then{
	private _display =  uiNamespace getVariable ["arsenalDisplay","No display"];
	titleText["ERROR DURING LOADING ARSENAL", "PLAIN"];
	if (typeName _display == "DISPLAY") then {
		_display closedisplay 2;
	};
	["jn_fnc_arsenal"] call BIS_fnc_endLoadingScreen;
  };
};

//save proper ammo because BIS arsenal rearms it, and I will over write it back again
missionNamespace setVariable ["jna_magazines_init",  [
	magazinesAmmoCargo (uniformContainer player),
	magazinesAmmoCargo (vestContainer player),
	magazinesAmmoCargo (backpackContainer player)
]];

//Save attachments in containers, because BIS arsenal removes them
private _attachmentsContainers = [[],[],[]];
{
	private _container = _x;
	private _weaponAtt = weaponsItemsCargo _x;
	private _attachments = [];

	if!(isNil "_weaponAtt")then{

		{
			private _atts = [_x select 1,_x select 2,_x select 3,_x select 6];
			_atts = _atts - [""];
			_attachments = _attachments + _atts;
		} forEach _weaponAtt;
		_attachmentsContainers set [_foreachindex,_attachments];
	}
} forEach [uniformContainer player,vestContainer player,backpackContainer player];
missionNamespace setVariable ["jna_containerCargo_init", _attachmentsContainers];

//set type
UINamespace setVariable ["jn_type","arsenal"];

//request server to open arsenal (pass the object and client UI style preference)
private _arsenalObj = missionNamespace getVariable ["jna_object", objNull];
[clientOwner, _arsenalObj, _uiStyle] remoteExecCall ["jn_fnc_arsenal_requestOpen",2];
