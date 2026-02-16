/*
	Author: Jeroen Notenbomer

	Description:
	Return a array of all items that are in a inventory of a vehicle/crate in the form of the jna_datalist

	Parameter(s):
	VEHICLE with a inventory

	Returns:
	ARRAY of arrays of arrays of items and amounts
*/


#include "\A3\ui_f\hpp\defineDIKCodes.inc"
#include "\A3\Ui_f\hpp\defineResinclDesign.inc"


private["_array","_addToArray","_unloadContainer"];
params ["_container", ["_isPlayer", false]];
_array = [[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[]];


_addToArray = {
	private ["_array","_index","_item","_amount"];
	_array = _this select 0;
	_index = _this select 1;
	_item = _this select 2;
	_amount = _this select 3;

	if!(_index == -1 || _item isEqualTo ""|| _amount == 0)then{
		_array set [_index,[_array select _index,[_item,_amount]] call jn_fnc_arsenal_addToArray];
	};
};

//recursion function to check all sub containers
_unloadContainer = {
	_container_sub = _this;

	//magazines (excl. loaded in weapons) — magazinesAmmoCargo: [[class,ammo],...] per physical mag
	_mags = [magazinesAmmoCargo _container_sub, magazinesAmmo _container_sub] select (_isPlayer);
	{
		_item = _x select 0;
		_amount = _x select 1;
		_index = _item call jn_fnc_arsenal_itemType;
		[_array,_index,_item,_amount]call _addToArray;
	} forEach _mags;

	//items — use getItemCargo [classes,counts] for correct counts
	if (_isPlayer) then {
		_items = (items _container_sub) + (assignedItems player);
		{
			_item = _x;
			if (_item isNotEqualTo "") then {
				_index = _item call jn_fnc_arsenal_itemType;
				[_array,_index,_item,1]call _addToArray;
			};
		} forEach _items;
	} else {
		private _itemData = getItemCargo _container_sub;
		private _classes = _itemData select 0;
		private _counts = _itemData select 1;
		for "_i" from 0 to (count _classes - 1) do {
			private _cls = _classes select _i;
			private _cnt = if (_i < count _counts) then { _counts select _i } else { 1 };
			if (_cls isNotEqualTo "" && _cnt > 0) then {
				_index = _cls call jn_fnc_arsenal_itemType;
				[_array,_index,_cls,_cnt]call _addToArray;
			};
		};
	};

	//backpacks — use getBackpackCargo [classes,counts] for correct counts
	if (_isPlayer) then {
		private _bp = backpack _container_sub;
		if (_bp isNotEqualTo "") then {
			_item = _bp call A3A_fnc_basicBackpack;
			if (_item isNotEqualTo "") then {
				[_array, IDC_RSCDISPLAYARSENAL_TAB_BACKPACK, _item, 1] call _addToArray;
			};
		};
	} else {
		private _bpData = getBackpackCargo _container_sub;
		private _classes = _bpData select 0;
		private _counts = _bpData select 1;
		for "_i" from 0 to (count _classes - 1) do {
			private _cls = _classes select _i;
			private _cnt = if (_i < count _counts) then { _counts select _i } else { 1 };
			if (_cls isNotEqualTo "" && _cnt > 0) then {
				_item = _cls call A3A_fnc_basicBackpack;
				if (_item isEqualTo "") then { _item = _cls };
				[_array, IDC_RSCDISPLAYARSENAL_TAB_BACKPACK, _item, _cnt] call _addToArray;
			};
		};
	};

	//weapons — use getWeaponCargo for correct counts, weaponsItemsCargo for attachments & loaded mags
	if (_isPlayer) then {
		_attItems = weaponsItems _container_sub;
		{
			{
				private["_index","_item","_amount"];
				if(typename _x isEqualTo "ARRAY")then{
					if(count _x > 0)then{
						_item = _x select 0;
						_amount = _x select 1;
						_index = IDC_RSCDISPLAYARSENAL_TAB_CARGOMAGALL;
						[_array,_index,_item,_amount]call _addToArray;
					};
				}else{
					if!(_x isEqualTo "")then{
						_item = _x;
						_amount = 1;
						_index = _item call jn_fnc_arsenal_itemType;
						if(_index in [IDC_RSCDISPLAYARSENAL_TAB_PRIMARYWEAPON, IDC_RSCDISPLAYARSENAL_TAB_SECONDARYWEAPON, IDC_RSCDISPLAYARSENAL_TAB_HANDGUN])then{
							_item = _x call bis_fnc_baseWeapon;
						};
						if(_index != -1)then{
							[_array,_index,_item,_amount]call _addToArray;
						};
					};
				};
			} foreach _x;
		} foreach _attItems;
	} else {
		// Container: getWeaponCargo [classes,counts] for base weapons
		private _wepData = getWeaponCargo _container_sub;
		private _wepClasses = _wepData select 0;
		private _wepCounts = _wepData select 1;
		for "_i" from 0 to (count _wepClasses - 1) do {
			private _cls = _wepClasses select _i;
			private _cnt = if (_i < count _wepCounts) then { _wepCounts select _i } else { 1 };
			if (_cls isNotEqualTo "" && _cnt > 0) then {
				private _base = _cls call bis_fnc_baseWeapon;
				_index = _base call jn_fnc_arsenal_itemType;
				if (_index != -1) then {
					[_array, _index, _base, _cnt] call _addToArray;
				};
			};
		};
		// weaponsItemsCargo for attachments and loaded magazines (weapons already added above)
		{
			{
				private["_index","_item","_amount"];
				if(typename _x isEqualTo "ARRAY")then{
					if(count _x > 0)then{
						_item = _x select 0;
						_amount = _x select 1;
						_index = IDC_RSCDISPLAYARSENAL_TAB_CARGOMAGALL;
						[_array,_index,_item,_amount]call _addToArray;
					};
				}else{
					if!(_x isEqualTo "")then{
						_item = _x;
						_index = _item call jn_fnc_arsenal_itemType;
						// Skip base weapons — already added via getWeaponCargo
						if!(_index in [IDC_RSCDISPLAYARSENAL_TAB_PRIMARYWEAPON, IDC_RSCDISPLAYARSENAL_TAB_SECONDARYWEAPON, IDC_RSCDISPLAYARSENAL_TAB_HANDGUN])then{
							_amount = 1;
							if(_index != -1)then{
								[_array,_index,_item,_amount]call _addToArray;
							};
						};
					};
				};
			}foreach _x;
		}foreach (weaponsItemsCargo _container_sub);
	};



	//sub containers;
	if (_isPlayer) then {
		{
			_item = _x;
			if (_x isNotEqualTo "") then {
				_index = _item call jn_fnc_arsenal_itemType;
				[_array,_index,_item,1]call _addToArray;
			};
		} forEach [uniform _container_sub, vest _container_sub, headgear _container_sub, goggles _container_sub];
	} else {
		{
			_x select 1 call _unloadContainer;
		} foreach (everyContainer _container_sub);
	};
};

//startloop
_container call _unloadContainer;

//return array of items
_array;