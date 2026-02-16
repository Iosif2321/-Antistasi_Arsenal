/*
    Antistasi Garage MVP — standalone multi-garage vehicle storage system
    All-in-one function: called with ["mode", params] call A3A_fnc_garage

    Data model per garage (stored on `server` object as A3A_GRG_<garageID>):
    Array of 6 HashMaps (one per category: Cars, Armor, Heli, Plane, Boat, Static)
    Each HashMap: key = vehUID (number), value = [displayName, className, stateData]
      stateData = [damage, fuel, vectorDir, vectorUp, pylonLoadout, textureData]

    Persistence: profileNamespace key "A3A_GarageData_<garageID>"
*/

#include "defines.inc"

params ["_mode", ["_params", []]];

switch (toLower _mode) do {

///////////////////////////////////////////////////////////////////////////////////////////
// SERVER: Initialize garage data for a specific garage ID
case "initserver": {
    if (!isServer) exitWith {};
    _params params ["_garageID"];

    private _serverKey = format ["A3A_GRG_%1", _garageID];
    if (!isNil {server getVariable _serverKey}) exitWith {};

    // Load from profile or create empty
    private _profileKey = format ["A3A_GarageData_%1", _garageID];
    private _saved = profileNamespace getVariable [_profileKey, []];

    private _data = [];
    for "_i" from 0 to (A3A_GRG_NUM_CATS - 1) do { _data pushBack createHashMap };

    // Load saved data
    if (count _saved == A3A_GRG_NUM_CATS) then {
        {
            if (_x isEqualType []) then {
                private _hm = createHashMap;
                { _hm set [_x select 0, _x select 1] } forEach _x;
                _data set [_forEachIndex, _hm];
            };
        } forEach _saved;
    };

    // UID counter
    if (isNil {server getVariable format ["A3A_GRG_UID_%1", _garageID]}) then {
        server setVariable [format ["A3A_GRG_UID_%1", _garageID], 0, true];
    };

    server setVariable [_serverKey, _data, true];

    private _totalVeh = 0;
    { _totalVeh = _totalVeh + count _x } forEach _data;
    diag_log format ["A3A_Garage: Initialized garage '%1' with %2 vehicles", _garageID, _totalVeh];
    systemChat format ["Garage '%1': %2 vehicles loaded", _garageID, _totalVeh];
};

///////////////////////////////////////////////////////////////////////////////////////////
// SERVER: Save garage data to profileNamespace
case "save": {
    if (!isServer) exitWith {};
    _params params ["_garageID"];

    private _serverKey = format ["A3A_GRG_%1", _garageID];
    private _data = server getVariable [_serverKey, []];
    if (count _data != A3A_GRG_NUM_CATS) exitWith {};

    // Convert HashMaps to arrays for serialization
    private _toSave = [];
    {
        private _arr = [];
        { _arr pushBack [_x, _y] } forEach _x;
        _toSave pushBack _arr;
    } forEach _data;

    profileNamespace setVariable [format ["A3A_GarageData_%1", _garageID], _toSave];
    saveProfileNamespace;
    diag_log format ["A3A_Garage: Saved garage '%1'", _garageID];
};

///////////////////////////////////////////////////////////////////////////////////////////
// SERVER: Get next UID for a garage
case "nextuid": {
    if (!isServer) exitWith { 0 };
    _params params ["_garageID"];
    private _key = format ["A3A_GRG_UID_%1", _garageID];
    private _uid = (server getVariable [_key, 0]) + 1;
    server setVariable [_key, _uid, true];
    _uid
};

///////////////////////////////////////////////////////////////////////////////////////////
// SERVER: Store a vehicle into the garage
case "addvehicle": {
    if (!isServer) exitWith {};
    _params params ["_garageID", "_vehicle", "_clientOwner"];

    if (isNull _vehicle || !alive _vehicle) exitWith {
        [format ["Garage '%1': vehicle is null or destroyed", _garageID]] remoteExecCall ["systemChat", _clientOwner];
    };

    // Classify vehicle
    private _className = typeOf _vehicle;
    private _displayName = getText (configFile >> "CfgVehicles" >> _className >> "displayName");
    private _catIdx = ["getCatIndex", [_vehicle]] call A3A_fnc_garage;
    if (_catIdx < 0) exitWith {
        [format ["Garage: cannot store this type of vehicle (%1)", _className]] remoteExecCall ["systemChat", _clientOwner];
    };

    // Check if crewed
    if (count (crew _vehicle - [player]) > 0) exitWith {
        ["Garage: vehicle has crew, cannot store"] remoteExecCall ["systemChat", _clientOwner];
    };

    // Save state
    private _damage = damage _vehicle;
    private _fuel = fuel _vehicle;
    private _vDir = vectorDir _vehicle;
    private _vUp = vectorUp _vehicle;
    private _pylons = getPylonMagazines _vehicle;
    private _textures = getObjectTextures _vehicle;
    private _stateData = [_damage, _fuel, _vDir, _vUp, _pylons, _textures];

    // Get UID
    private _uid = ["nextUID", [_garageID]] call A3A_fnc_garage;

    // Store
    private _serverKey = format ["A3A_GRG_%1", _garageID];
    private _data = server getVariable [_serverKey, []];
    if (count _data != A3A_GRG_NUM_CATS) exitWith {};

    (_data select _catIdx) set [_uid, [_displayName, _className, _stateData]];
    server setVariable [_serverKey, _data, true];

    // Delete world vehicle
    deleteVehicle _vehicle;

    // Save to profile
    ["save", [_garageID]] call A3A_fnc_garage;

    // Notify
    [format ["Garage '%1': stored %2", _garageID, _displayName]] remoteExecCall ["systemChat", _clientOwner];
    diag_log format ["A3A_Garage: Stored %1 (UID %2) in garage '%3' cat %4", _className, _uid, _garageID, _catIdx];
};

///////////////////////////////////////////////////////////////////////////////////////////
// SERVER: Remove vehicle from pool and return its data
case "removevehicle": {
    if (!isServer) exitWith { [] };
    _params params ["_garageID", "_catIdx", "_uid"];

    private _serverKey = format ["A3A_GRG_%1", _garageID];
    private _data = server getVariable [_serverKey, []];
    if (count _data != A3A_GRG_NUM_CATS) exitWith { [] };

    private _hm = _data select _catIdx;
    private _vehData = _hm getOrDefault [_uid, []];
    if (count _vehData == 0) exitWith { [] };

    _hm deleteAt _uid;
    server setVariable [_serverKey, _data, true];

    // Save to profile
    ["save", [_garageID]] call A3A_fnc_garage;

    _vehData
};

///////////////////////////////////////////////////////////////////////////////////////////
// SHARED: Get category index for a vehicle (0-5, -1 if unknown)
case "getcatindex": {
    _params params ["_vehicle"];
    private _className = if (_vehicle isEqualType "") then { _vehicle } else { typeOf _vehicle };

    private _catIdx = -1;
    if (_className isKindOf "StaticWeapon") then { _catIdx = 5 }
    else {
        if (_className isKindOf "Ship") then { _catIdx = 4 }
        else {
            if (_className isKindOf "Plane") then { _catIdx = 3 }
            else {
                if (_className isKindOf "Helicopter") then { _catIdx = 2 }
                else {
                    if (_className isKindOf "Tank" || {_className isKindOf "Wheeled_APC_F"}) then { _catIdx = 1 }
                    else {
                        if (_className isKindOf "Car" || {_className isKindOf "Motorcycle"}) then { _catIdx = 0 }
                    };
                };
            };
        };
    };
    _catIdx
};

///////////////////////////////////////////////////////////////////////////////////////////
// CLIENT: Get garage data from server for display
case "getdata": {
    _params params ["_garageID"];
    private _serverKey = format ["A3A_GRG_%1", _garageID];
    server getVariable [_serverKey, []]
};

///////////////////////////////////////////////////////////////////////////////////////////
// CLIENT: Open garage dialog
case "open": {
    private _garageObj = missionNamespace getVariable ["A3A_GRG_object", objNull];
    private _garageID = _garageObj getVariable ["A3A_Garage_ID", "Default"];

    // Ensure server has initialized this garage
    ["initServer", [_garageID]] remoteExecCall ["A3A_fnc_garage", 2];

    // Store current garage context
    uiNamespace setVariable ["A3A_GRG_currentID", _garageID];
    uiNamespace setVariable ["A3A_GRG_currentObj", _garageObj];
    uiNamespace setVariable ["A3A_GRG_currentCat", 0];

    // Open dialog
    createDialog "A3A_GRG_Dialog";
};

///////////////////////////////////////////////////////////////////////////////////////////
// CLIENT: Dialog onLoad
case "onload": {
    disableSerialization;
    private _display = (_params select 0);
    uiNamespace setVariable ["A3A_GRG_display", _display];

    private _garageID = uiNamespace getVariable ["A3A_GRG_currentID", "Default"];
    (_display displayCtrl A3A_GRG_IDC_TITLE) ctrlSetText format ["Garage: %1", _garageID];

    // Small delay to let server init complete, then load first category
    [] spawn {
        uiSleep 0.5;
        ["switchCat", [0]] call A3A_fnc_garage;
        ["updateCount"] call A3A_fnc_garage;
    };
};

///////////////////////////////////////////////////////////////////////////////////////////
// CLIENT: Dialog onUnload
case "onunload": {
    uiNamespace setVariable ["A3A_GRG_display", nil];
    uiNamespace setVariable ["A3A_GRG_selectedUID", nil];
    uiNamespace setVariable ["A3A_GRG_selectedCat", nil];
};

///////////////////////////////////////////////////////////////////////////////////////////
// CLIENT: Close dialog
case "close": {
    private _display = uiNamespace getVariable ["A3A_GRG_display", displayNull];
    if (!isNull _display) then { _display closeDisplay 2 };
};

///////////////////////////////////////////////////////////////////////////////////////////
// CLIENT: Switch category tab
case "switchcat": {
    disableSerialization;
    _params params ["_catIdx"];
    uiNamespace setVariable ["A3A_GRG_currentCat", _catIdx];

    private _display = uiNamespace getVariable ["A3A_GRG_display", displayNull];
    if (isNull _display) exitWith {};

    // Hide all listboxes, show selected
    private _catIDCs = [A3A_GRG_IDC_CAT_CARS, A3A_GRG_IDC_CAT_ARMOR, A3A_GRG_IDC_CAT_HELI, A3A_GRG_IDC_CAT_PLANE, A3A_GRG_IDC_CAT_BOAT, A3A_GRG_IDC_CAT_STATIC];
    private _btnIDCs = [A3A_GRG_IDC_BTN_CARS, A3A_GRG_IDC_BTN_ARMOR, A3A_GRG_IDC_BTN_HELI, A3A_GRG_IDC_BTN_PLANE, A3A_GRG_IDC_BTN_BOAT, A3A_GRG_IDC_BTN_STATIC];
    {
        private _ctrl = _display displayCtrl _x;
        _ctrl ctrlShow (_forEachIndex == _catIdx);
        _ctrl ctrlEnable (_forEachIndex == _catIdx);
    } forEach _catIDCs;

    // Highlight active button
    {
        private _ctrl = _display displayCtrl _x;
        if (_forEachIndex == _catIdx) then {
            _ctrl ctrlSetBackgroundColor [0.3, 0.3, 0.1, 1];
        } else {
            _ctrl ctrlSetBackgroundColor [0.2, 0.2, 0.2, 1];
        };
        _ctrl ctrlCommit 0;
    } forEach _btnIDCs;

    // Populate list
    ["reloadList", [_catIdx]] call A3A_fnc_garage;

    // Clear selection
    uiNamespace setVariable ["A3A_GRG_selectedUID", nil];
    (_display displayCtrl A3A_GRG_IDC_INFO) ctrlSetStructuredText parseText "";
    (_display displayCtrl A3A_GRG_IDC_BTN_RETRIEVE) ctrlEnable false;
};

///////////////////////////////////////////////////////////////////////////////////////////
// CLIENT: Reload vehicle list for a category
case "reloadlist": {
    disableSerialization;
    _params params ["_catIdx"];

    private _display = uiNamespace getVariable ["A3A_GRG_display", displayNull];
    if (isNull _display) exitWith {};

    private _garageID = uiNamespace getVariable ["A3A_GRG_currentID", "Default"];
    private _data = ["getData", [_garageID]] call A3A_fnc_garage;
    if (count _data != A3A_GRG_NUM_CATS) exitWith {};

    private _catIDCs = [A3A_GRG_IDC_CAT_CARS, A3A_GRG_IDC_CAT_ARMOR, A3A_GRG_IDC_CAT_HELI, A3A_GRG_IDC_CAT_PLANE, A3A_GRG_IDC_CAT_BOAT, A3A_GRG_IDC_CAT_STATIC];
    private _list = _display displayCtrl (_catIDCs select _catIdx);
    lbClear _list;

    private _hm = _data select _catIdx;
    {
        private _uid = _x;
        private _vehData = _y;
        _vehData params ["_displayName", "_className", "_stateData"];

        private _dmg = if (count _stateData > 0) then { _stateData select 0 } else { 0 };
        private _fuelPct = if (count _stateData > 1) then { round ((_stateData select 1) * 100) } else { 100 };

        private _text = format ["%1  [HP:%2%3 Fuel:%4%5]", _displayName, round ((1 - _dmg) * 100), "%", _fuelPct, "%"];
        private _idx = _list lbAdd _text;
        _list lbSetData [_idx, str _uid];
        _list lbSetValue [_idx, _uid];

        // Icon from config
        private _icon = getText (configFile >> "CfgVehicles" >> _className >> "icon");
        if (_icon isEqualTo "") then { _icon = getText (configFile >> "CfgVehicles" >> _className >> "picture") };
        _list lbSetPicture [_idx, _icon];

        // Color by damage
        if (_dmg > 0.5) then {
            _list lbSetColor [_idx, [1, 0.3, 0.3, 1]];
        } else {
            if (_dmg > 0.2) then {
                _list lbSetColor [_idx, [1, 0.8, 0.3, 1]];
            } else {
                _list lbSetColor [_idx, [1, 1, 1, 1]];
            };
        };
    } forEach _hm;

    ["updateCount"] call A3A_fnc_garage;
};

///////////////////////////////////////////////////////////////////////////////////////////
// CLIENT: Update total vehicle count display
case "updatecount": {
    disableSerialization;
    private _display = uiNamespace getVariable ["A3A_GRG_display", displayNull];
    if (isNull _display) exitWith {};

    private _garageID = uiNamespace getVariable ["A3A_GRG_currentID", "Default"];
    private _data = ["getData", [_garageID]] call A3A_fnc_garage;
    private _total = 0;
    { _total = _total + count _x } forEach _data;

    (_display displayCtrl A3A_GRG_IDC_COUNT) ctrlSetText format ["%1 vehicles", _total];
};

///////////////////////////////////////////////////////////////////////////////////////////
// CLIENT: Vehicle selection changed in listbox
case "selchanged": {
    disableSerialization;
    _params params ["_ctrl", "_selIdx"];

    private _display = uiNamespace getVariable ["A3A_GRG_display", displayNull];
    if (isNull _display) exitWith {};
    if (_selIdx < 0) exitWith {};

    private _uid = _ctrl lbValue _selIdx;
    private _catIdx = uiNamespace getVariable ["A3A_GRG_currentCat", 0];

    uiNamespace setVariable ["A3A_GRG_selectedUID", _uid];
    uiNamespace setVariable ["A3A_GRG_selectedCat", _catIdx];

    // Show info
    private _garageID = uiNamespace getVariable ["A3A_GRG_currentID", "Default"];
    private _data = ["getData", [_garageID]] call A3A_fnc_garage;
    if (count _data != A3A_GRG_NUM_CATS) exitWith {};

    private _hm = _data select _catIdx;
    private _vehData = _hm getOrDefault [_uid, []];
    if (count _vehData == 0) exitWith {};

    _vehData params ["_displayName", "_className", "_stateData"];
    private _dmg = if (count _stateData > 0) then { round ((1 - (_stateData select 0)) * 100) } else { 100 };
    private _fuelPct = if (count _stateData > 1) then { round ((_stateData select 1) * 100) } else { 100 };

    private _maxSpeed = getNumber (configFile >> "CfgVehicles" >> _className >> "maxSpeed");
    private _armor = getNumber (configFile >> "CfgVehicles" >> _className >> "armor");

    private _info = format [
        "<t size='1.1' color='#d0a050'>%1</t><br/><br/>" +
        "<t size='0.9'>Class: %2<br/><br/>HP: %3%4<br/>Fuel: %5%4<br/>Max Speed: %6 km/h<br/>Armor: %7</t>",
        _displayName, _className, _dmg, "%", _fuelPct, _maxSpeed, _armor
    ];
    (_display displayCtrl A3A_GRG_IDC_INFO) ctrlSetStructuredText parseText _info;

    // Enable retrieve button
    (_display displayCtrl A3A_GRG_IDC_BTN_RETRIEVE) ctrlEnable true;
};

///////////////////////////////////////////////////////////////////////////////////////////
// CLIENT: Store nearby vehicle into garage
case "storevehicle": {
    private _garageObj = uiNamespace getVariable ["A3A_GRG_currentObj", objNull];
    private _garageID = uiNamespace getVariable ["A3A_GRG_currentID", "Default"];

    // Find nearest vehicle within 25m of garage object
    private _nearVehs = nearestObjects [_garageObj, ["LandVehicle", "Air", "Ship", "StaticWeapon"], 25];
    _nearVehs = _nearVehs select { alive _x && crew _x isEqualTo [] };

    if (count _nearVehs == 0) exitWith {
        systemChat "No empty vehicle found within 25m of the garage.";
        hint "No vehicle nearby to store.";
    };

    private _vehicle = _nearVehs select 0;
    private _displayName = getText (configFile >> "CfgVehicles" >> (typeOf _vehicle) >> "displayName");

    // Send to server
    ["addVehicle", [_garageID, _vehicle, clientOwner]] remoteExecCall ["A3A_fnc_garage", 2];

    // Refresh after short delay
    [] spawn {
        uiSleep 1;
        private _catIdx = uiNamespace getVariable ["A3A_GRG_currentCat", 0];
        ["switchCat", [_catIdx]] call A3A_fnc_garage;
    };
};

///////////////////////////////////////////////////////////////////////////////////////////
// CLIENT: Retrieve selected vehicle from garage
case "retrievevehicle": {
    private _uid = uiNamespace getVariable ["A3A_GRG_selectedUID", nil];
    private _catIdx = uiNamespace getVariable ["A3A_GRG_selectedCat", nil];
    if (isNil "_uid" || isNil "_catIdx") exitWith { systemChat "No vehicle selected." };

    private _garageID = uiNamespace getVariable ["A3A_GRG_currentID", "Default"];
    private _garageObj = uiNamespace getVariable ["A3A_GRG_currentObj", objNull];

    // Close dialog first
    ["close"] call A3A_fnc_garage;

    // Request vehicle from server and spawn
    [_garageID, _catIdx, _uid, _garageObj] spawn {
        params ["_garageID", "_catIdx", "_uid", "_garageObj"];

        // Get data from server
        private _vehData = ["removeVehicle", [_garageID, _catIdx, _uid]] call A3A_fnc_garage;
        if (count _vehData == 0) exitWith { systemChat "Vehicle no longer available." };

        _vehData params ["_displayName", "_className", "_stateData"];

        // Find spawn position near garage object
        private _pos = _garageObj getRelPos [10, 0];
        _pos = _pos findEmptyPosition [0, 50, _className];
        if (count _pos == 0) then { _pos = _garageObj getRelPos [15, random 360] };
        _pos set [2, 0];

        // Create vehicle
        private _vehicle = createVehicle [_className, _pos, [], 0, "NONE"];
        _vehicle setPos _pos;

        // Restore state
        if (count _stateData > 0) then { _vehicle setDamage (_stateData select 0) };
        if (count _stateData > 1) then { _vehicle setFuel (_stateData select 1) };
        if (count _stateData > 2 && {count _stateData > 3}) then {
            _vehicle setVectorDirAndUp [_stateData select 2, _stateData select 3];
        };
        // Pylons
        if (count _stateData > 4) then {
            private _pylons = _stateData select 4;
            { _vehicle setPylonLoadout [_forEachIndex + 1, _x, true] } forEach _pylons;
        };
        // Textures
        if (count _stateData > 5) then {
            private _textures = _stateData select 5;
            { _vehicle setObjectTextureGlobal [_forEachIndex, _x] } forEach _textures;
        };

        systemChat format ["Garage: spawned %1", _displayName];
    };
};

///////////////////////////////////////////////////////////////////////////////////////////
default {
    diag_log format ["A3A_Garage: Unknown mode '%1'", _mode];
};

};
