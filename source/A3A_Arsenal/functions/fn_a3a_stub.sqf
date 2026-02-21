// Stub definitions for Jeroen Arsenal to work standalone
// Defines functions and variables expected by JNA that are usually provided by Antistasi Core.
// Based on original implementations from: Antistasi\A3A\addons\core\

// ========================================================================================
// Global variables - Mod detection (from fn_initVarCommon.sqf)
// ========================================================================================

if (isNil "A3A_hasTFAR") then {
    A3A_hasTFAR = isClass (configFile >> "CfgPatches" >> "task_force_radio");
};
if (isNil "A3A_hasACRE") then {
    A3A_hasACRE = isClass (configFile >> "cfgPatches" >> "acre_main");
};
if (isNil "A3A_hasTFARBeta") then {
    A3A_hasTFARBeta = isClass (configFile >> "CfgPatches" >> "tfar_static_radios");
    if (A3A_hasTFARBeta) then { A3A_hasTFAR = false };
};
if (isNil "A3A_hasACE") then {
    A3A_hasACE = !isNil "ace_common_fnc_isModLoaded";
};
if (isNil "A3A_hasACEMedical") then {
    A3A_hasACEMedical = isClass (configFile >> "CfgSounds" >> "ACE_heartbeat_fast_3");
};
if (isNil "A3A_hasACEHearing") then {
    A3A_hasACEHearing = isClass (configFile >> "CfgSounds" >> "ACE_EarRinging_Weak");
};

// ========================================================================================
// Faction data - HashMap for rebel faction (used by FactionGet macro)
// FactionGet(reb,"initialRebelEquipment") expands to (A3A_faction_reb get "initialRebelEquipment")
// ========================================================================================

if (isNil "A3A_faction_reb") then {
    A3A_faction_reb = createHashMap;

    // Build initialRebelEquipment based on loaded mods (from template files)
    private _initialRebelEquipment = [];

    if (A3A_hasTFAR) then {
        _initialRebelEquipment append ["tf_microdagr", "tf_anprc154"];
    };
    if (A3A_hasTFARBeta) then {
        _initialRebelEquipment append ["TFAR_microdagr", "TFAR_anprc154"];
    };
    _initialRebelEquipment append [
        "Chemlight_blue", "Chemlight_green", "Chemlight_red", "Chemlight_yellow"
    ];

    A3A_faction_reb set ["initialRebelEquipment", _initialRebelEquipment];
};

// ========================================================================================
// Membership system - In standalone, everyone is a "member" (no restrictions)
// Original: fn_isMember.sqf - checks player UID against membersX array
// ========================================================================================

if (isNil "membershipEnabled") then { membershipEnabled = false };
if (isNil "membersX") then { membersX = [] };

A3A_fnc_isMember = {
    // Standalone: no membership restrictions, always allow
    if !(membershipEnabled) exitWith { true };
    params ["_player"];
    if (_player getVariable ["owner", _player] != _player) exitWith { false };
    (_player getVariable ["A3A_playerUID", getPlayerUID _player]) in membersX;
};

// ========================================================================================
// Medic check - Original: fn_isMedic.sqf
// ========================================================================================

A3A_fnc_isMedic = {
    private _unit = _this select 0;
    if (_unit getUnitTrait "Medic") exitWith { true };
    if (getNumber (configFile >> "CfgVehicles" >> (typeOf _unit) >> "attendant") == 2) exitWith { true };
    false
};

// ========================================================================================
// Engineer check - Original: fn_isEngineer.sqf
// ========================================================================================

A3A_fnc_isEngineer = {
    params ["_unit"];
    if (!isNil {_unit getVariable "ace_isEngineer"}) exitWith {
        !(_unit getVariable "ace_isEngineer" in [0, false])
    };
    _unit getUnitTrait "engineer";
};

// ========================================================================================
// Radio check - Original: fn_hasARadio.sqf
// ========================================================================================

A3A_fnc_hasARadio = {
    assignedItems _this findIf {
        _x == "ItemRadio" || {"tf_" in _x} || {"TFAR" in _x} || {"item_radio" in _x}
    } > -1
    || { backpack _this in allBackpacksRadio }
};

// ========================================================================================
// Basic backpack - Original: fn_basicBackpack.sqf
// ========================================================================================

A3A_fnc_basicBackpack = {
    params ["_backpack"];
    if (_backpack isEqualTo "") exitWith { "" };
    private _basicBackpack = _backpack call BIS_fnc_basicBackpack;
    if (_basicBackpack isEqualTo "") exitWith { _backpack };
    _basicBackpack
};

// ========================================================================================
// All magazines for a config - Original: fn_allMagazines.sqf
// Retrieves all compatible magazines from CfgWeapons or CfgVehicles config
// ========================================================================================

A3A_fnc_allMagazines = {
    params ["_config"];
    if (!isClass _config) exitWith { [] };

    private _magazines = [];
    private _magazineWells = [];

    private _processVehicle = {
        if (isArray (_config / "magazines")) then { _magazines append getArray (_config / "magazines") };
        if (isArray (_config / "magazineWell")) then { _magazineWells append getArray (_config / "magazineWell") };
        {
            if (isArray (_x / "magazines")) then { _magazines append getArray (_x / "magazines") };
            if (isArray (_x / "magazineWell")) then { _magazineWells append getArray (_x / "magazineWell") };
        } forEach (configProperties [_config / "Turrets"]);
    };

    private _processWeapon = {
        if (isArray (_config / "magazines")) then { _magazines append getArray (_config / "magazines") };
        if (isArray (_config / "magazineWell")) then { _magazineWells append getArray (_config / "magazineWell") };
        {
            if (_x isEqualTo "this") then { continue };
            if (isArray (_config / _x / "magazines")) then { _magazines append getArray (_config / _x / "magazines") };
            if (isArray (_config / _x / "magazineWell")) then { _magazineWells append getArray (_config / _x / "magazineWell") };
        } forEach (getArray (_config / "muzzles"));
    };

    if ((configFile / "cfgWeapons") in (configHierarchy _config)) then _processWeapon else _processVehicle;

    {
        {
            if (isArray _x) then { _magazines append getArray _x };
        } forEach configProperties [configFile / "cfgMagazineWells" / _x];
    } forEach _magazineWells;

    _magazines arrayIntersect _magazines
};

// ========================================================================================
// Logging - Original: uses CBA logging macros, simplified here
// ========================================================================================

A3A_fnc_log = {
    params ["_level", "_text", ["_file", ""]];
    diag_log format ["A3A_Ars Log: %1 - %2 (%3)", _level, _text, _file];
};

// ========================================================================================
// Custom hint - Original: A3A UI hint system
// ========================================================================================

A3A_fnc_customHint = {
    params ["_header", "_text"];
    hint parseText format ["<t size='1.2' color='#d04f00'>%1</t><br/>%2", _header, _text];
};

// ========================================================================================
// Equip Rebel - Original: complex loadout system, disabled in standalone
// ========================================================================================

A3A_fnc_equipRebel = {
    params ["_unit", "_index", "_loadoutName"];
    systemChat "Quick Equip not available in standalone mode.";
};

// ========================================================================================
// Arsenal limits HashMap
// ========================================================================================

if (isNil "A3A_arsenalLimits") then {
    A3A_arsenalLimits = createHashMap;
};

// ========================================================================================
// SCRT loadout arsenal stub - prevent undefined function errors
// ========================================================================================

if (isNil "SCRT_fnc_arsenal_loadoutArsenal") then {
    SCRT_fnc_arsenal_loadoutArsenal = {};
};

// CBA server events are registered in fn_arsenal_init.sqf (isServer block)
//  that path is guaranteed to execute on server during module init.

// ========================================================================================
// CBA Settings  addon options (ESC  Options  Game  Configure Addons  Antistasi Arsenal)
// ========================================================================================
if (!isNil "CBA_fnc_addSetting") then {
    [
        "A3A_Arsenal_ContainerAccess",
        "LIST",
        ["Container Arsenal Access", "Who can use 'Select vehicle to open arsenal' action"],
        "Antistasi Arsenal",
        [[0, 1, 2], ["Everyone", "Zeus Only", "Disabled"], 0]
    ] call CBA_fnc_addSetting;
    diag_log "A3A_Arsenal: CBA settings registered.";
} else {
    A3A_Arsenal_ContainerAccess = 0;
    diag_log "A3A_Arsenal: CBA not available, using default settings.";
};

diag_log "A3A_Arsenal: Stubs initialized.";
