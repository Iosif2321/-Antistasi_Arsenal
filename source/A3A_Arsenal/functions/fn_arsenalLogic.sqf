params ["_mode", ["_params", []]];

switch (_mode) do {
    case "INIT_SERVER": {
        _params params ["_object"];
        if (isNull _object) exitWith {};

        private _id = _object getVariable ["A3A_Arsenal_ID", "Default"];
        private _profileKey = format ["A3A_ArsenalData_%1", _id];
        
        // Load data from profile — supports both JNA format (27 sub-arrays) and flat format
        private _rawData = profileNamespace getVariable [_profileKey, []];
        
        // Convert to HashMap for runtime efficiency
        private _counts = createHashMap;
        
        if (count _rawData == 27 && {_rawData select 0 isEqualType []}) then {
            // JNA format: 27 sub-arrays, each containing [["className", count], ...]
            {
                {
                    if (_x isEqualType [] && {count _x >= 2}) then {
                        _x params ["_cls", "_cnt"];
                        if (_cls isEqualType "" && {!(_cls isEqualTo "")}) then {
                            private _existing = _counts getOrDefault [_cls, 0];
                            _counts set [_cls, _existing + _cnt];
                        };
                    };
                } forEach _x;
            } forEach _rawData;
            diag_log format ["A3A_arsenalLogic: Loaded JNA format data for '%1' (%2 unique items)", _id, count _counts];
        } else {
            // Flat format: [["className", count], ...]
            {
                if (_x isEqualType [] && {count _x >= 2}) then {
                    _x params ["_cls", "_cnt"];
                    _counts set [_cls, _cnt];
                };
            } forEach _rawData;
            diag_log format ["A3A_arsenalLogic: Loaded flat format data for '%1' (%2 items)", _id, count _counts];
        };
        
        _object setVariable ["A3A_Arsenal_Counts", _counts, true];
        
        // Initial update of virtual items
        ["UPDATE_VIRTUAL", [_object]] call A3A_fnc_arsenalLogic;
    };

    case "INIT_CLIENT": {
        _params params ["_object"];
        if (isNull _object) exitWith {};

        // Add 'Open Arsenal' action
        _object addAction [
            "<t color='#f0d498'>Open Arsenal</t>", 
            { 
                params ["_target", "_caller", "_actionId", "_arguments"];
                ["Open", [true]] call BIS_fnc_arsenal; 
            }, 
            [], 
            6, 
            true, 
            true, 
            "", 
            "alive _target && {_target distance _this < 5}"
        ];

        // Add 'Deposit Inventory' action
        _object addAction [
            "<t color='#ff0000'>Deposit Inventory to Arsenal</t>", 
            { 
                params ["_target", "_caller"];
                // Transfer from player inventory
                [_caller, _target] spawn {
                    params ["_unit", "_box"];
                    
                    // Simple transfer of current loadout items
                    private _items = [];
                    
                    // Helper to add recursive items from containers would be better due to complexity, 
                    // but for now let's just dump the *entire* loadout structure using getUnitLoadout? 
                    // No, that's too complex to parse back. 
                    // Let's use simple command: all items.
                    
                    // Using a simpler approach: 
                    // 1. Get all items
                    // 2. Clear inventory
                    // 3. Add to arsenal
                    
                    // Note: This is a destructive action.
                    
                    private _loadout = getUnitLoadout _unit;
                    _unit setUnitLoadout (configFile >> "EmptyLoadout");
                    
                    // Parse loadout (complex) OR simplistic approach:
                    // Actually, let's just use "Cargo To Arsenal" logic if it's a box.
                    // For player, we iterate typical slots.
                    
                    // Simplest for MVP:
                    // Move specific items from uniform, vest, backpack.
                    // This is tedious to write here. 
                    // Better approach: Let user put items IN the box, then "Save Box to Arsenal".
                };
            },
            [],
            1.5,
            false,
            true,
            "",
            "false" // Disabled for now, prefer 'Save Box Content' approach
        ];
        
        // 'Transfer Cargo to Arsenal' - Useful for boxes
        _object addAction [
            "<t color='#00ff00'>Transfer Cargo to Arsenal</t>",
            {
                params ["_target", "_caller"];
                ["CARGO_TO_ARSENAL", [_target]] remoteExec ["A3A_fnc_arsenalLogic", 2];
            },
            [],
            5,
            true,
            true,
            "",
            "alive _target && {_target distance _this < 5} && {count (itemCargo _target) > 0 || count (weaponCargo _target) > 0 || count (magazineCargo _target) > 0 || count (backpackCargo _target) > 0}"
        ];
        
        // Debug/Admin: Unlock Item (Shortcut)
        _object addAction [
            "<t color='#00ffff'>[Admin] Unlock All In Cargo</t>",
            {
                params ["_target", "_caller"];
                ["UNLOCK_CARGO", [_target]] remoteExec ["A3A_fnc_arsenalLogic", 2];
            },
            [],
            0,
            false,
            true,
            "",
            "serverCommandAvailable '#vote' || isServer"
        ];
    };

    case "ADD_ITEMS": {
        _params params ["_object", "_itemsAndCounts"]; 
        // _itemsAndCounts: [["class", count], ["class", count]]
        
        if (isNull _object) exitWith {};
        
        private _counts = _object getVariable ["A3A_Arsenal_Counts", createHashMap];
        private _threshold = _object getVariable ["A3A_Arsenal_Threshold", 25];
        private _updated = false;
        
        {
            _x params ["_cls", "_amt"];
            private _current = _counts getOrDefault [_cls, 0];
            
            // If already infinite (>= threshold used to flag it, 
            // but we might want to keep counting? Antistasi usually stops counting or keeps it high.
            // Let's just add.
            
            _counts set [_cls, _current + _amt];
            _updated = true;
        } forEach _itemsAndCounts;
        
        if (_updated) then {
            _object setVariable ["A3A_Arsenal_Counts", _counts, true];
            ["UPDATE_VIRTUAL", [_object]] call A3A_fnc_arsenalLogic;
            ["SAVE", [_object]] call A3A_fnc_arsenalLogic;
        };
    };

    case "UPDATE_VIRTUAL": {
        _params params ["_object"];
        
        if (isNull _object) exitWith {};
        
        private _counts = _object getVariable ["A3A_Arsenal_Counts", createHashMap];
        private _threshold = _object getVariable ["A3A_Arsenal_Threshold", 25];
        
        private _virtualItems = [];
        private _virtualWeapons = [];
        private _virtualMags = [];
        private _virtualBackpacks = [];
        
        {
            private _cls = _x;
            private _cnt = _y;
            
            if (_cnt >= _threshold) then {
                // Determine type
                if (isClass (configFile >> "CfgWeapons" >> _cls)) then {
                    private _type = getNumber (configFile >> "CfgWeapons" >> _cls >> "type");
                    if (_type == 131072) then { _virtualItems pushBack _cls; } // ItemCore
                    else { _virtualWeapons pushBack _cls; };
                } else {
                    if (isClass (configFile >> "CfgMagazines" >> _cls)) then { _virtualMags pushBack _cls; }
                    else {
                        if (isClass (configFile >> "CfgVehicles" >> _cls)) then { _virtualBackpacks pushBack _cls; }
                        else { _virtualItems pushBack _cls; }; // Glasses, etc.
                    };
                };
            };
        } forEach _counts;
        
        // Add to virtual cargo
        [_object, _virtualWeapons, true] call BIS_fnc_addVirtualWeaponCargo;
        [_object, _virtualMags, true] call BIS_fnc_addVirtualMagazineCargo;
        [_object, _virtualItems, true] call BIS_fnc_addVirtualItemCargo;
        [_object, _virtualBackpacks, true] call BIS_fnc_addVirtualBackpackCargo;
    };
    
    case "CARGO_TO_ARSENAL": {
        _params params ["_object"];
        
        if (isNull _object) exitWith {};
        
        private _itemsToAdd = [];
        
        // Collect Weapons
        private _weapons = getWeaponCargo _object;
        private _classes = _weapons select 0;
        private _counts = _weapons select 1;
        {
            _itemsToAdd pushBack [_x, _counts select _forEachIndex];
        } forEach _classes;
        
        // Collect Magazines
        private _mags = getMagazineCargo _object;
        _classes = _mags select 0;
        _counts = _mags select 1;
        {
            _itemsToAdd pushBack [_x, _counts select _forEachIndex];
        } forEach _classes;
        
        // Collect Items
        private _items = getItemCargo _object;
        _classes = _items select 0;
        _counts = _items select 1;
        {
            _itemsToAdd pushBack [_x, _counts select _forEachIndex];
        } forEach _classes;
        
        // Collect Backpacks
        private _backpacks = getBackpackCargo _object;
        _classes = _backpacks select 0;
        _counts = _backpacks select 1;
        {
            _itemsToAdd pushBack [_x, _counts select _forEachIndex];
        } forEach _classes;
        
        // Clear Cargo
        clearWeaponCargoGlobal _object;
        clearMagazineCargoGlobal _object;
        clearItemCargoGlobal _object;
        clearBackpackCargoGlobal _object;
        
        // Add to system
        if (count _itemsToAdd > 0) then {
            ["ADD_ITEMS", [_object, _itemsToAdd]] call A3A_fnc_arsenalLogic;
            
            // Notification
            private _msg = format ["Added %1 items to Arsenal.", count _itemsToAdd];
            // Send hint to players nearby?
             // Remote hint
             _msg remoteExec ["hint", 0];
        };
    };
    
    case "UNLOCK_CARGO": {
        _params params ["_object"];
        // Adds 99999 of every item currently in cargo
        if (isNull _object) exitWith {};
        
        private _itemsToAdd = [];
        
        // Helper to collect keys
        private _collect = {
           params ["_cargo"];
           private _classes = _cargo select 0;
           {
               _itemsToAdd pushBack [_x, 99999];
           } forEach _classes;
        };
        
        [getWeaponCargo _object] call _collect;
        [getMagazineCargo _object] call _collect;
        [getItemCargo _object] call _collect;
        [getBackpackCargo _object] call _collect;
        
        clearWeaponCargoGlobal _object;
        clearMagazineCargoGlobal _object;
        clearItemCargoGlobal _object;
        clearBackpackCargoGlobal _object;
        
        if (count _itemsToAdd > 0) then {
             ["ADD_ITEMS", [_object, _itemsToAdd]] call A3A_fnc_arsenalLogic;
             "Selected items unlocked (infinite)." remoteExec ["hint", 0];
        };
    };

    case "SAVE": {
        _params params ["_object"];
        
        if (isNull _object) exitWith {};
        
        private _id = _object getVariable ["A3A_Arsenal_ID", "Default"];
        private _counts = _object getVariable ["A3A_Arsenal_Counts", createHashMap];
        
        // Save in JNA-compatible format: 27 sub-arrays indexed by arsenal tab
        // Each sub-array contains [["className", count], ...] pairs
        // Items whose tab index cannot be determined go into CARGOMISC (index 26)
        private _dataToSave = [];
        for "_i" from 0 to 26 do { _dataToSave pushBack [] };
        
        {
            private _cls = _x;
            private _cnt = _y;
            private _tabIndex = _cls call jn_fnc_arsenal_itemType;
            if (_tabIndex < 0 || _tabIndex > 26) then { _tabIndex = 26 }; // fallback to CARGOMISC
            (_dataToSave select _tabIndex) pushBack [_cls, _cnt];
        } forEach _counts;
        
        private _profileKey = format ["A3A_ArsenalData_%1", _id];
        profileNamespace setVariable [_profileKey, _dataToSave];
        saveProfileNamespace;
        
        diag_log format ["Antistasi Arsenal Saved: %1 (%2 unique items)", _id, count _counts];
    };
};
