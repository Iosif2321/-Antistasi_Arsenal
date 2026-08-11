#include "defineCommon.inc"
#include "..\script_component.hpp"
FIX_LINE_NUMBERS()

#define A4A_ACE_IDD_ARSENAL 1127001
#define A4A_ACE_IDC_LEFT_LIST 13
#define A4A_ACE_IDC_RIGHT_LIST 14
#define A4A_ACE_IDC_RIGHT_LISTNBOX 15
#define A4A_ACE_IDC_BUTTON_UNIFORM 2010
#define A4A_ACE_IDC_BUTTON_VEST 2012
#define A4A_ACE_IDC_BUTTON_BACKPACK 2014
#define A4A_ACE_IDC_BUTTON_FACE 2033
#define A4A_ACE_IDC_BUTTON_VOICE 2035
#define A4A_ACE_IDC_BUTTON_INSIGNIA 2037
#define A4A_ACE_IDC_ICON_FACE 2032
#define A4A_ACE_IDC_ICON_VOICE 2034
#define A4A_ACE_IDC_ICON_INSIGNIA 2036

if (isNil "A4A_fnc_arsenal_formatStockPrefix") then {
	A4A_fnc_arsenal_formatStockPrefix = {
		params [["_amount", 0]];
		if (_amount == -1) exitWith { "[     ]  " };

		private _suffix = "";
		private _prefix = "";
		private _value = _amount;

		if (_value > 999) then {
			_value = round (_value / 1000);
			_suffix = "k";
			_prefix = switch true do {
				case (_value >= 100): { _value = 99; "" };
				case (_value >= 10): { "" };
				case (_value >= 0): { "0" };
			};
		} else {
			_prefix = switch true do {
				case (_value >= 100): { "" };
				case (_value >= 10): { "0" };
				case (_value >= 0): { "00" };
			};
		};
		("[ " + _prefix + (str _value) + _suffix + " ]  ")
	};
};

A4A_fnc_arsenal_aceGetStep = {
	params [["_shiftState", false, [false]]];
	// ACE physically applies only its native 1/5 transfer before cargoChanged.
	// A post-event adapter cannot truthfully synthesize Ctrl 10/50 transfers.
	private _shift = _shiftState || {uiNamespace getVariable ["A4A_arsenalShift", false]};
	[1, 5] select _shift
};

A4A_fnc_arsenal_aceItemConfig = {
	params ["_item"];
	switch true do {
		case (isClass (configFile >> "CfgMagazines" >> _item)): { configFile >> "CfgMagazines" >> _item };
		case (isClass (configFile >> "CfgVehicles" >> _item)): { configFile >> "CfgVehicles" >> _item };
		case (isClass (configFile >> "CfgGlasses" >> _item)): { configFile >> "CfgGlasses" >> _item };
		default { configFile >> "CfgWeapons" >> _item };
	};
};

A4A_fnc_arsenal_aceGetDisplay = {
	private _display = uiNamespace getVariable ["A4A_aceStock_display", displayNull];
	if (isNull _display) then {
		_display = findDisplay A4A_ACE_IDD_ARSENAL;
	};
	_display
};

A4A_fnc_arsenal_aceOwnsCurrentBox = {
	private _expectedBox = missionNamespace getVariable ["A4A_aceStock_box", objNull];
	!isNull _expectedBox
	&& {(missionNamespace getVariable ["ace_arsenal_currentBox", objNull]) isEqualTo _expectedBox}
};

A4A_fnc_arsenal_aceScheduleStockRefresh = {
	params [["_display", displayNull], ["_fullRefresh", false]];
	if (isNull _display) then {
		_display = [] call A4A_fnc_arsenal_aceGetDisplay;
	};
	if (isNull _display) exitWith {};
	uiNamespace setVariable ["A4A_aceStock_display", _display];

	// Ensure ACRE spare radios are in IDX_VIRT_MISC_ITEMS (17) not IDX_VIRT_RADIO (12) / COMMS (14)
	[] call A4A_fnc_arsenal_aceRelocateRadios;

	private _expectedBox = missionNamespace getVariable ["A4A_aceStock_box", objNull];
	[_display, _fullRefresh, _expectedBox] spawn {
		params ["_display", "_fullRefresh", "_expectedBox"];
		// ACE fillSort runs after panelFilled and overwrites row text — wait for it.
		uiSleep 0.1;
		if (
			isNull _display
			|| {!(missionNamespace getVariable ["A4A_aceStock_active", false])}
			|| {!((missionNamespace getVariable ["A4A_aceStock_box", objNull]) isEqualTo _expectedBox)}
			|| {!([] call A4A_fnc_arsenal_aceOwnsCurrentBox)}
		) exitWith {};

		if (_fullRefresh && {!isNil "ace_arsenal_fnc_refresh"}) then {
			// Guard: ensure ACE arsenal display is fully initialized and virtual items are consistent
			private _aceDisplay = findDisplay A4A_ACE_IDD_ARSENAL;
			if (!isNull _aceDisplay) then {
				// Verify left panel (IDC 13) and right panel (IDC 14) exist
				private _leftPanel = _aceDisplay displayCtrl 13;
				private _rightPanel = _aceDisplay displayCtrl 14;
				if (!isNull _leftPanel && !isNull _rightPanel) then {
					// Verify virtual items exist on the arsenal object
					private _arsenalObj = missionNamespace getVariable ["A4A_aceStock_box", objNull];
					if (!isNull _arsenalObj) then {
						private _virtItems = _arsenalObj getVariable ["ace_arsenal_virtualItems", []];
						if !(_virtItems isEqualTo []) then {
							[true, true, true] call ace_arsenal_fnc_refresh;
							uiSleep 0.05;
						} else {
							diag_log "[A4A_Arsenal] ACE refresh skipped: no virtual items on arsenal object";
						};
					};
				} else {
					diag_log "[A4A_Arsenal] ACE refresh skipped: display panels not ready";
				};
			} else {
				diag_log "[A4A_Arsenal] ACE refresh skipped: ACE display not found";
			};
		};
		if (!isNull _display && {missionNamespace getVariable ["A4A_aceStock_active", false]}) then {
			[_display] call A4A_fnc_arsenal_aceRefreshStockPanels;
		};
	};
};

A4A_fnc_arsenal_aceOnDataListUpdate = {
	params ["_index", "_item", "_amount", ["_isAdd", true]];
	if !(missionNamespace getVariable ["A4A_aceStock_active", false]) exitWith {};
	if (_item isEqualTo "" || {isNil "jna_dataList"}) exitWith {};

	if (_index == IDC_RSCDISPLAYARSENAL_TAB_CARGOMAG) then {
		_index = IDC_RSCDISPLAYARSENAL_TAB_CARGOMAGALL;
	};

	private _stock = [jna_dataList select _index, _item] call jn_fnc_arsenal_itemCount;

	// For weapon tabs, jna_dataList stores baseWeapon but ACE needs specific variant.
	// Look up the actual variant from pristine config data (A4A_arsenal_configData).
	private _aceItem = _item;
	if (_index in [IDC_RSCDISPLAYARSENAL_TAB_PRIMARYWEAPON, IDC_RSCDISPLAYARSENAL_TAB_SECONDARYWEAPON, IDC_RSCDISPLAYARSENAL_TAB_HANDGUN]) then {
		private _configData = missionNamespace getVariable ["A4A_arsenal_configData", []];
		private _variants = _configData param [_index, []];
		// Find a variant that matches this baseWeapon
		{
			private _base = _x call BIS_fnc_baseWeapon;
			if (_base isEqualTo _item) exitWith { _aceItem = _x; };
		} forEach _variants;
		// Fallback: if no variant found (e.g., modded weapon not in config), use baseWeapon
		if (_aceItem != _item) then {
			diag_log format ["[A4A_Arsenal] ACE sync: weapon variant resolved %1 -> %2", _item, _aceItem];
		} else {
			diag_log format ["[A4A_Arsenal] ACE sync: using baseWeapon %1 (no variant found in config)", _item];
		};
	};

	[_aceItem, _stock] call A4A_fnc_arsenal_aceSyncVirtualItems;

	private _display = [] call A4A_fnc_arsenal_aceGetDisplay;
	private _needsFullRefresh = _isAdd && {_stock > 0 || _stock == -1};
	[_display, _needsFullRefresh] call A4A_fnc_arsenal_aceScheduleStockRefresh;
};

A4A_fnc_arsenal_aceFormatItemLabel = {
	params ["_item", ["_displayName", ""]];
	if (_displayName isEqualTo "") then {
		private _cfg = [_item] call A4A_fnc_arsenal_aceItemConfig;
		_displayName = getText (_cfg >> "displayName");
	};
	if (_item isEqualTo "" || {isNil "jna_dataList"}) exitWith { _displayName };

	private _idx = _item call jn_fnc_arsenal_itemType;
	if (_idx < 0) exitWith { _displayName };

	private _amount = [jna_dataList select _idx, _item] call jn_fnc_arsenal_itemCount;
	private _prefix = [_amount] call A4A_fnc_arsenal_formatStockPrefix;
	_prefix + _displayName
};

A4A_fnc_arsenal_aceApplyListBoxStockLabels = {
	params ["_ctrlList"];
	if (isNull _ctrlList || {ctrlType _ctrlList != 5}) exitWith {};

	private _count = lbSize _ctrlList;
	for "_row" from 0 to (_count - 1) do {
		private _item = _ctrlList lbData _row;
		if (_item isEqualTo "") then { continue };

		private _label = [_item] call A4A_fnc_arsenal_aceFormatItemLabel;
		_ctrlList lbSetText [_row, _label];

		private _idx = _item call jn_fnc_arsenal_itemType;
		private _amount = if (_idx >= 0) then {[jna_dataList select _idx, _item] call jn_fnc_arsenal_itemCount} else {0};
		if (_amount == 0) then {
			_ctrlList lbSetColor [_row, [1, 1, 1, 0.25]];
		} else {
			_ctrlList lbSetColor [_row, [1, 1, 1, 1]];
		};
	};
};

A4A_fnc_arsenal_aceApplyListNBoxStockLabels = {
	params ["_ctrlList"];
	if (isNull _ctrlList || {ctrlType _ctrlList != 102}) exitWith {};

	private _rows = lnbSize _ctrlList select 0;
	for "_row" from 0 to (_rows - 1) do {
		private _item = _ctrlList lnbData [_row, 0];
		if (_item isEqualTo "") then { continue };

		private _label = [_item] call A4A_fnc_arsenal_aceFormatItemLabel;
		_ctrlList lnbSetText [[_row, 1], _label];

		private _idx = _item call jn_fnc_arsenal_itemType;
		private _amount = if (_idx >= 0) then {[jna_dataList select _idx, _item] call jn_fnc_arsenal_itemCount} else {0};
		if (_amount == 0) then {
			_ctrlList lnbSetColor [[_row, 1], [1, 1, 1, 0.25]];
		} else {
			_ctrlList lnbSetColor [[_row, 1], [1, 1, 1, 1]];
		};
	};
};

A4A_fnc_arsenal_aceRefreshLeftPanel = {
	params [["_display", displayNull]];
	if (isNull _display) exitWith {};
	if (isNil "jna_dataList") exitWith {};

	private _ctrlList = _display displayCtrl A4A_ACE_IDC_LEFT_LIST;
	if (isNull _ctrlList) exitWith {};
	private _count = lbSize _ctrlList;
	if (_count == 0) exitWith {};

	for "_row" from 0 to (_count - 1) do {
		private _item = _ctrlList lbData _row;
		if (_item isEqualTo "" || {_item isEqualType 0}) then { continue };

		private _label = [_item] call A4A_fnc_arsenal_aceFormatItemLabel;
		_ctrlList lbSetText [_row, _label];

		private _idx = _item call jn_fnc_arsenal_itemType;
		private _amount = if (_idx >= 0) then {[jna_dataList select _idx, _item] call jn_fnc_arsenal_itemCount} else {0};
		if (_amount == 0) then {
			_ctrlList lbSetColor [_row, [1, 1, 1, 0.25]];
		} else {
			_ctrlList lbSetColor [_row, [1, 1, 1, 1]];
		};
	};
};

A4A_fnc_arsenal_aceRefreshRightPanel = {
	params [["_display", displayNull]];
	if (isNull _display) exitWith {};
	if (isNil "jna_dataList") exitWith {};

	private _ctrlList = _display displayCtrl A4A_ACE_IDC_RIGHT_LIST;
	private _ctrlListNBox = _display displayCtrl A4A_ACE_IDC_RIGHT_LISTNBOX;

	if (!isNull _ctrlList && {lbSize _ctrlList > 0}) then {
		[_ctrlList] call A4A_fnc_arsenal_aceApplyListBoxStockLabels;
	};
	if (!isNull _ctrlListNBox && {(lnbSize _ctrlListNBox select 0) > 0}) then {
		[_ctrlListNBox] call A4A_fnc_arsenal_aceApplyListNBoxStockLabels;
	};
};

A4A_fnc_arsenal_aceRefreshStockPanels = {
	params [["_display", displayNull]];
	if (isNull _display) exitWith {};
	[_display] call A4A_fnc_arsenal_aceRefreshLeftPanel;
	[_display] call A4A_fnc_arsenal_aceRefreshRightPanel;
};

A4A_fnc_arsenal_aceSyncVirtualItems = {
	params ["_item", "_amount"];
	private _arsenalObj = missionNamespace getVariable ["A4A_aceStock_box", objNull];
	if (isNull _arsenalObj) exitWith {
		diag_log format ["[A4A_Arsenal] ACE syncVirtualItems skipped: no arsenal object for %1", _item];
	};
	if (isNil "ace_arsenal_fnc_removeVirtualItems") exitWith {
		diag_log "[A4A_Arsenal] ACE syncVirtualItems skipped: ACE arsenal functions not available";
	};
	if (_item isEqualTo "") exitWith {
		diag_log "[A4A_Arsenal] ACE syncVirtualItems skipped: empty item";
	};

	if (_amount <= 0 && {_amount != -1}) then {
		[_arsenalObj, [_item]] call ace_arsenal_fnc_removeVirtualItems;
	} else {
		if (!isNil "ace_arsenal_fnc_addVirtualItems") then {
			[_arsenalObj, [_item]] call ace_arsenal_fnc_addVirtualItems;
		};
	};
};

A4A_fnc_arsenal_aceRelocateRadios = {
	private _arsenalObj = missionNamespace getVariable ["A4A_aceStock_box", objNull];
	if (isNull _arsenalObj) exitWith {};

	private _cargo = _arsenalObj getVariable ["ace_arsenal_virtualItems", []];
	if (_cargo isEqualType []) then { _cargo = createHashMapFromArray _cargo; };
	if !(_cargo isEqualType createHashMap) then { _cargo = createHashMap; };

	private _radioHash = _cargo getOrDefault [12, createHashMap];	// IDX_VIRT_RADIO
	private _commsHash = _cargo getOrDefault [14, createHashMap];	// IDX_VIRT_COMMS
	private _miscHash = _cargo getOrDefault [17, createHashMap];	// IDX_VIRT_MISC_ITEMS
	private _moved = 0;

	{
		private _cfg = configFile >> "CfgWeapons" >> _x;
		if (isClass _cfg && {getText (_cfg >> "simulation") == "ItemRadio"}) then {
			private _isComms = getNumber (_cfg >> "ace_arsenal_isComms") == 1;
			// ACRE2 spare radios use _ID_ suffix (e.g. ACRE_PRC343_ID_1)
			private _isSpareRadio = "_ID_" in _x;
			if (_isComms || _isSpareRadio) then {
				_radioHash deleteAt _x;
				_miscHash set [_x, true];
				_moved = _moved + 1;
			};
		};
	} forEach (keys _radioHash);

	{
		private _cfg = configFile >> "CfgWeapons" >> _x;
		if (isClass _cfg && {getText (_cfg >> "simulation") == "ItemRadio"}) then {
			private _isComms = getNumber (_cfg >> "ace_arsenal_isComms") == 1;
			private _isSpareRadio = "_ID_" in _x;
			if (_isComms || _isSpareRadio) then {
				_commsHash deleteAt _x;
				_miscHash set [_x, true];
				_moved = _moved + 1;
			};
		};
	} forEach (keys _commsHash);

	if (_moved > 0) then {
		_cargo set [12, _radioHash];
		_cargo set [14, _commsHash];
		_cargo set [17, _miscHash];
		_arsenalObj setVariable ["ace_arsenal_virtualItems", _cargo];
		diag_log format ["[A4A_Arsenal] Relocated %1 radios to IDX_VIRT_MISC_ITEMS", _moved];
	};

};

A4A_fnc_arsenal_aceGetDisplayName = {
	params ["_item"];
	private _cfg = [_item] call A4A_fnc_arsenal_aceItemConfig;
	getText (_cfg >> "displayName");
};

// --- Cargo snapshot system ---
// ACE mutates the player inventory BEFORE firing cargoChanged.
// We save a "before" snapshot so we can compute the real delta.

A4A_fnc_arsenal_aceSaveCargoSnapshot = {
	private _center = missionNamespace getVariable ["ace_arsenal_center", player];
	private _uniformMags = magazinesAmmoCargo (uniformContainer _center);
	private _vestMags = magazinesAmmoCargo (vestContainer _center);
	private _bpMags = magazinesAmmoCargo (backpackContainer _center);
	private _uniformItems = getItemCargo (uniformContainer _center);
	private _vestItems = getItemCargo (vestContainer _center);
	private _bpItems = getItemCargo (backpackContainer _center);
	private _snap = [_uniformMags, _vestMags, _bpMags, _uniformItems, _vestItems, _bpItems];
	missionNamespace setVariable ["A4A_aceCargoSnapshot", _snap];
	_snap
};

A4A_fnc_arsenal_aceCountInCargo = {
	params ["_item", "_cargo", "_isItemCargo"];
	private _count = 0;
	if (_isItemCargo) then {
		if (count (_cargo select 0) > 0) then {
			private _idx = (_cargo select 0) find _item;
			if (_idx != -1) then { _count = (_cargo select 1) select _idx; };
		};
	} else {
		_count = {(_x select 0) isEqualTo _item} count _cargo;
	};
	_count
};

A4A_fnc_arsenal_aceCountInSnapshot = {
	params ["_item", "_snap"];
	if (_snap isEqualTo []) exitWith { 0 };
	private _count = 0;
	for "_i" from 0 to 2 do {
		_count = _count + ([_item, _snap select _i, false] call A4A_fnc_arsenal_aceCountInCargo);
	};
	for "_i" from 3 to 5 do {
		_count = _count + ([_item, _snap select _i, true] call A4A_fnc_arsenal_aceCountInCargo);
	};
	_count
};

A4A_fnc_arsenal_aceCountCurrentInventory = {
	params ["_item"];
	private _center = missionNamespace getVariable ["ace_arsenal_center", player];
	private _count = 0;
	{
		_count = _count + ([_item, magazinesAmmoCargo _x, false] call A4A_fnc_arsenal_aceCountInCargo);
	} forEach [uniformContainer _center, vestContainer _center, backpackContainer _center];
	{
		_count = _count + ([_item, getItemCargo _x, true] call A4A_fnc_arsenal_aceCountInCargo);
	} forEach [uniformContainer _center, vestContainer _center, backpackContainer _center];
	_count
};

A4A_fnc_arsenal_aceOnCargoChanged = {
	params ["_display", "_item", "_addOrRemove", "_shiftState"];
	if !(missionNamespace getVariable ["A4A_aceStock_active", false]) exitWith {};
	if !([] call A4A_fnc_arsenal_aceOwnsCurrentBox) exitWith {};
	if (_item isEqualTo "") exitWith {};
	if (isNil "jna_dataList") exitWith {};

	private _idx = _item call jn_fnc_arsenal_itemType;
	if (_idx < 0) exitWith {};

	private _step = [_shiftState] call A4A_fnc_arsenal_aceGetStep;
	private _stock = [jna_dataList select _idx, _item] call jn_fnc_arsenal_itemCount;
	private _take = _addOrRemove > 0;

	// Compute real delta from snapshot (before ACE mutated inventory)
	private _snap = missionNamespace getVariable ["A4A_aceCargoSnapshot", []];
	private _countBefore = [_item, _snap] call A4A_fnc_arsenal_aceCountInSnapshot;
	private _countAfter = [_item] call A4A_fnc_arsenal_aceCountCurrentInventory;
	private _realDelta = _countAfter - _countBefore; // positive = ACE added, negative = ACE removed

	if (_take) then {
		// Player pressed "+": ACE already added items to inventory.
		if (_realDelta <= 0) exitWith {
			systemChat "No items were added.";
		};

		private _count = _realDelta min _step;
		if (_stock != -1) then {
			_count = _count min _stock;
		};

		if (_count <= 0) exitWith {
			systemChat "Not enough items in arsenal.";
		};

		[_idx, _item, _count] call jn_fnc_arsenal_removeItem;
		private _newStock = [jna_dataList select _idx, _item] call jn_fnc_arsenal_itemCount;
		[_item, _newStock] call A4A_fnc_arsenal_aceSyncVirtualItems;
	} else {
		// Player pressed "-": ACE already removed items from inventory.
		if (_realDelta >= 0) exitWith {
			systemChat format ["You don't have any %1 to return.", [_item] call A4A_fnc_arsenal_aceGetDisplayName];
		};

		private _removed = abs _realDelta;
		private _count = _removed min _step;

		if (_count > 0) then {
			[_idx, _item, _count] call jn_fnc_arsenal_addItem;
			private _newStock = [jna_dataList select _idx, _item] call jn_fnc_arsenal_itemCount;
			[_item, _newStock] call A4A_fnc_arsenal_aceSyncVirtualItems;
		};
	};

	// Save new snapshot for next action
	[] call A4A_fnc_arsenal_aceSaveCargoSnapshot;
	[_display, false] call A4A_fnc_arsenal_aceScheduleStockRefresh;
};

A4A_fnc_arsenal_aceSyncEquippedItems = {
	params [["_display", displayNull]];
	if !(missionNamespace getVariable ["A4A_aceStock_active", false]) exitWith {};
	if !([] call A4A_fnc_arsenal_aceOwnsCurrentBox) exitWith {};
	if (isNil "jna_dataList") exitWith {};

	private _currItems = + (missionNamespace getVariable ["ace_arsenal_currentItems", []]);
	private _prevItems = missionNamespace getVariable ["A4A_acePrevItems", []];
	if (_currItems isEqualTo []) exitWith {};

	for "_slot" from 0 to 14 do {
		private _old = _prevItems param [_slot, ""];
		private _new = _currItems param [_slot, ""];
		if (_old isEqualTo _new) then { continue };

		if (_old != "") then {
			private _oldIdx = _old call jn_fnc_arsenal_itemType;
			if (_oldIdx >= 0) then { [_oldIdx, _old] call jn_fnc_arsenal_addItem; };
		};
		if (_new != "") then {
			private _newIdx = _new call jn_fnc_arsenal_itemType;
			private _stock = [jna_dataList select _newIdx, _new] call jn_fnc_arsenal_itemCount;
			if (_stock == 0) then {
				systemChat "Item unavailable in arsenal.";
				// Revert selection is handled on next ACE refresh; stock gate for next open.
			} else {
				[_newIdx, _new] call jn_fnc_arsenal_removeItem;
				private _newStock = [jna_dataList select _newIdx, _new] call jn_fnc_arsenal_itemCount;
				[_new, _newStock] call A4A_fnc_arsenal_aceSyncVirtualItems;
			};
		};
	};

	missionNamespace setVariable ["A4A_acePrevItems", +_currItems];
	[_display, false] call A4A_fnc_arsenal_aceScheduleStockRefresh;
};

A4A_fnc_arsenal_aceAttachKeyHandlers = {
	params ["_display"];
	// Track ACE's native Shift modifier without blocking its own key events.
	_display displayAddEventHandler ["KeyDown", {
		params ["", "", "_shift", "", ""];
		uiNamespace setVariable ["A4A_arsenalShift", _shift];
		false
	}];
	_display displayAddEventHandler ["KeyUp", {
		params ["", "", "_shift", "", ""];
		uiNamespace setVariable ["A4A_arsenalShift", _shift];
		false
	}];
};

A4A_fnc_arsenal_aceBeginSession = {
	params ["_arsenalObj", "_aceBox"];
	missionNamespace setVariable ["A4A_aceStock_active", true];
	// Original global object is retained only for the sender-bound close RPC.
	missionNamespace setVariable ["A4A_aceStock_arsenalObj", _arsenalObj];
	missionNamespace setVariable ["A4A_aceStock_box", _aceBox];
	uiNamespace setVariable ["A4A_aceStock_display", displayNull];
	uiNamespace setVariable ["A4A_arsenalShift", false];
	[] call A4A_fnc_arsenal_aceSaveCargoSnapshot;

	// Initial sync: populate ACE virtual items from JNA arsenal data
	if (!isNil "jna_dataList") then {
		{
			private _category = _x;
			{
				private _item = _x select 0;
				private _amount = _x select 1;
				if (_amount > 0 || _amount == -1) then {
					[_item, _amount] call A4A_fnc_arsenal_aceSyncVirtualItems;
				};
			} forEach _category;
		} forEach jna_dataList;
	};

	// Ensure ACRE spare radios are placed in Misc cargo tab (not Radio equipment tab)
	[] call A4A_fnc_arsenal_aceRelocateRadios;

	diag_log format ["A4A_Arsenal: ACE stock session started for %1", name player];
};

	A4A_fnc_arsenal_aceEndSession = {
		if !(missionNamespace getVariable ["A4A_aceStock_active", false]) exitWith {};
		missionNamespace setVariable ["A4A_aceStock_active", false];
		missionNamespace setVariable ["A4A_acePrevItems", nil];
		missionNamespace setVariable ["A4A_aceCargoSnapshot", []];
		uiNamespace setVariable ["A4A_aceStock_display", displayNull];
		uiNamespace setVariable ["A4A_arsenalShift", false];

		private _arsenalObj = missionNamespace getVariable ["A4A_aceStock_arsenalObj", objNull];
		private _aceBox = missionNamespace getVariable ["A4A_aceStock_box", objNull];
		missionNamespace setVariable ["A4A_aceStock_box", nil];
		missionNamespace setVariable ["A4A_aceStock_arsenalObj", nil];
		// ACE fires displayClosed before it resets currentBox. The proxy was
		// populated with addVirtualItems (no interaction/JIP), so deleting the
		// A4A-owned local object on the next frame is the complete cleanup.
		private _cleanupProxy = {
			params ["_box"];
			if (!isNull _box) then {
				deleteVehicle _box;
			};
		};
		if (!isNull _aceBox) then {
			if (!isNil "CBA_fnc_execNextFrame") then {
				[_cleanupProxy, [_aceBox]] call CBA_fnc_execNextFrame;
			} else {
				[_aceBox] call _cleanupProxy;
			};
		};
		["RestoreTFAR"] call jn_fnc_arsenal;
		if (!isNull _arsenalObj) then {
			[clientOwner, _arsenalObj] remoteExecCall ["jn_fnc_arsenal_requestClose", 2];
		};
		diag_log format ["A4A_Arsenal: ACE stock session ended for %1", name player];
	};

A4A_fnc_arsenal_aceRegisterHandlers = {
	if (!hasInterface) exitWith {};
	if (missionNamespace getVariable ["A4A_aceStock_handlersRegistered", false]) exitWith {};
	if (isNil "CBA_fnc_addEventHandler") exitWith {};

	["ace_arsenal_leftPanelFilled", {
		params ["_display"];
		if !(missionNamespace getVariable ["A4A_aceStock_active", false]) exitWith {};
		if !([] call A4A_fnc_arsenal_aceOwnsCurrentBox) exitWith {};
		uiNamespace setVariable ["A4A_aceStock_display", _display];
		[_display, false] call A4A_fnc_arsenal_aceScheduleStockRefresh;
	}] call CBA_fnc_addEventHandler;

	["ace_arsenal_rightPanelFilled", {
		params ["_display"];
		if !(missionNamespace getVariable ["A4A_aceStock_active", false]) exitWith {};
		if !([] call A4A_fnc_arsenal_aceOwnsCurrentBox) exitWith {};
		uiNamespace setVariable ["A4A_aceStock_display", _display];
		[_display, false] call A4A_fnc_arsenal_aceScheduleStockRefresh;
	}] call CBA_fnc_addEventHandler;

	["ace_arsenal_cargoChanged", {
		_this call A4A_fnc_arsenal_aceOnCargoChanged;
	}] call CBA_fnc_addEventHandler;

	["ace_arsenal_displayOpened", {
		params ["_display"];
		if !(missionNamespace getVariable ["A4A_aceStock_active", false]) exitWith {};
		if !([] call A4A_fnc_arsenal_aceOwnsCurrentBox) exitWith {};
		uiNamespace setVariable ["A4A_aceStock_display", _display];
		[_display] call A4A_fnc_arsenal_aceAttachKeyHandlers;

		// Hide left panel tabs that are not applicable to JNA quantitative arsenal
		{
			private _ctrl = _display displayCtrl _x;
			_ctrl ctrlShow false;
			_ctrl ctrlEnable false;
		} forEach [
			A4A_ACE_IDC_ICON_FACE, A4A_ACE_IDC_BUTTON_FACE,
			A4A_ACE_IDC_ICON_VOICE, A4A_ACE_IDC_BUTTON_VOICE,
			A4A_ACE_IDC_ICON_INSIGNIA, A4A_ACE_IDC_BUTTON_INSIGNIA
		];

		missionNamespace setVariable ["A4A_acePrevItems", + (missionNamespace getVariable ["ace_arsenal_currentItems", []])];
		private _list = _display displayCtrl A4A_ACE_IDC_LEFT_LIST;
		_list ctrlAddEventHandler ["LBSelChanged", {
			params ["_control"];
			private _disp = ctrlParent _control;
			[{ [(_this select 0)] call A4A_fnc_arsenal_aceSyncEquippedItems; }, [_disp]] call CBA_fnc_execNextFrame;
		}];
		[_display, false] call A4A_fnc_arsenal_aceScheduleStockRefresh;
	}] call CBA_fnc_addEventHandler;

	["ace_arsenal_displayClosed", {
		if !(missionNamespace getVariable ["A4A_aceStock_active", false]) exitWith {};
		if !([] call A4A_fnc_arsenal_aceOwnsCurrentBox) exitWith {};
		[] call A4A_fnc_arsenal_aceEndSession;
	}] call CBA_fnc_addEventHandler;

	missionNamespace setVariable ["A4A_aceStock_handlersRegistered", true];
	diag_log "A4A_Arsenal: ACE stock event handlers registered.";
};

// Bootstrap on file load (client)
if (hasInterface) then {
	[] call A4A_fnc_arsenal_aceRegisterHandlers;
};

true
