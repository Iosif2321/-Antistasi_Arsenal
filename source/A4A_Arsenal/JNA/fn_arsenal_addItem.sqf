
#include "..\defineCommon.inc"

// Clients must send normalized deltas through the sender-bound dispatcher.
// Reject direct remote execution of this permissive bulk wrapper on server.
if (isRemoteExecuted) exitWith {
	diag_log format ["A4A_Arsenal: rejected direct remote addItem wrapper from owner %1", remoteExecutedOwner];
};

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

				//Weapon Stack fix (only for actual weapons with muzzles, not GPS/misc items)
				if (isArray (configfile >> "CfgWeapons" >> _item >> "muzzles")) then {
					private _weaponname = getText(configfile >> "CfgWeapons" >> _item >> "baseWeapon");
					if!(_weaponname isEqualTo "")then{_item = _weaponname};
				};

				//RHS Sight Stack fix
				private _sightname = getText(configfile >> "CfgWeapons" >> _item >> "rhs_optic_base");
				if!(_sightname isEqualTo "")then{_item = _sightname};

				//ACRE fix
				private _radioName2 = getText(configfile >> "CfgVehicles" >> _item >> "acre_baseClass");
				if!(_radioName2 isEqualTo "")then{_item = _radioName2};

				// Clients pre-apply for responsive UI. Hosted servers use the server path once.
				if (!isServer && {!isNil "jna_dataList"}) then {
					jna_dataList set [_index, [jna_dataList select _index, [_item, _amount]] call jn_fnc_arsenal_addToArray];
				};

				// Determine Arsenal ID for this specific interaction
				private _curArsenalID = (missionNamespace getVariable ["jna_object", objNull]) getVariable ["A4A_Arsenal_ID", "Base"];

				// Update server immediately if local. Avoids lag after unlockEquipment
				if (isServer) then { ["UpdateItemAdd",[_index, _item, _amount,true, name player, getPlayerUID player, _curArsenalID]] call jn_fnc_arsenal }
				else { ["UpdateItemAdd",[_index, _item, _amount,true, name player, getPlayerUID player, _curArsenalID]] remoteExecCall ["jn_fnc_arsenal",2] };

			};
		};
	} forEach _x;
} forEach _array;

