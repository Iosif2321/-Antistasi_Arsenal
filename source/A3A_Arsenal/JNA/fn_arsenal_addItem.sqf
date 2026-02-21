
#include "..\defineCommon.inc"

private _array = [[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[]];

if(typeName (_this select 0) isEqualTo "SCALAR")then{//[_index, _item] and [_index, _item, _amount];
	params["_index","_item",["_amount",1]];
	if(_index < 0)exitWith{
		ERROR_JN_2("Failed to addItem: ", _this);
		};
	_array set [_index,[[_item,_amount]]];
}else{
	_array = _this;
};

{
	private _index = _forEachIndex;
	{
		private _item = _x select 0;
		private _amount = _x select 1;
		if (_item isEqualType "") then
			{
			if !(_item isEqualTo "")then{

				if(_index == -1)exitWith{["Antistasi: ERROR in additemarsenal: %1", _this] call BIS_fnc_error};
				if(_index == IDC_RSCDISPLAYARSENAL_TAB_CARGOMAG)then{_index = IDC_RSCDISPLAYARSENAL_TAB_CARGOMAGALL};

				//TFAR fix
				private _radioName = getText(configfile >> "CfgWeapons" >> _item >> "tf_parent");
				if!(_radioName isEqualTo "")then{_item = _radioName};

				//Weapon Stack fix
				private _weaponname = getText(configfile >> "CfgWeapons" >> _item >> "baseWeapon");
				if!(_weaponname isEqualTo "")then{_item = _weaponname};

				//RHS Sight Stack fix
				private _sightname = getText(configfile >> "CfgWeapons" >> _item >> "rhs_optic_base");
				if!(_sightname isEqualTo "")then{_item = _sightname};
				
				//ACRE fix
				private _radioName = getText(configfile >> "CfgVehicles" >> _item >> "acre_baseClass");
				if!(_radioName isEqualTo "")then{_item = _radioName};

				// Determine Arsenal ID for this specific interaction
				private _curArsenalID = (missionNamespace getVariable ["jna_object", objNull]) getVariable ["A3A_Arsenal_ID", "Base"];

				// Update server immediately if local. Avoids lag after unlockEquipment
				if (isServer) then { ["UpdateItemAdd",[_index, _item, _amount,true, name player, getPlayerUID player, _curArsenalID]] call jn_fnc_arsenal }
				else { ["UpdateItemAdd",[_index, _item, _amount,true, name player, getPlayerUID player, _curArsenalID]] remoteExecCall ["jn_fnc_arsenal",2] };

				// then update other players. Don't execute on server twice
				if (!isNil "server") then {
					private _playersInArsenal = +(server getVariable [format ["jna_playersInArsenal_%1", _curArsenalID], []]) - [2];
					if (0 in _playersInArsenal) then { _playersInArsenal = -2 };
					if !(_playersInArsenal isEqualTo []) then {
						["UpdateItemAdd",[_index, _item, _amount,true, name player, getPlayerUID player, _curArsenalID]] remoteExecCall ["jn_fnc_arsenal",_playersInArsenal];
					};
				};
			};
		};
	} forEach _x;
}foreach _array;

