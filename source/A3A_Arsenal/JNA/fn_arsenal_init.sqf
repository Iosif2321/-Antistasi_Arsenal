#include "defineCommon.inc"
#include "\A3\ui_f\hpp\defineDIKCodes.inc"
#include "\A3\Ui_f\hpp\defineResinclDesign.inc"
#include "..\script_component.hpp"
FIX_LINE_NUMBERS()
///////////////////////////////////////////////////////////////////////////////////////////
scriptName "fn_arsenal_init.sqf";
private _fileName = "fn_arsenal_init.sqf";
[2,"JNA init started",_fileName] call A3A_fnc_log;
params [
    ["_object",objNull,[objNull]],
    ["_arsenalID", "Base", [""]],
    ["_unlockThreshold", 25, [0]]
];

if(isNull _object)exitWith{["Error: wrong input given '%1'",_object] call BIS_fnc_error;};

// Check if already initialized on this machine
if (_object getVariable ["A3A_Arsenal_Initialized", false]) exitWith {
    if (hasInterface) then { systemChat format ["Antistasi Arsenal: Object %1 already initialized", _object]; };
};
_object setVariable ["A3A_Arsenal_Initialized", true];

// Debug log for client side
if (hasInterface) then {
    systemChat format ["Antistasi Arsenal: Client Init for %1", _object];
};

// Set variables on object — but DON'T overwrite if already set by fn_arsenalInit.sqf
// (fn_arsenalInit sets the correct ID from module params BEFORE calling this function,
//  but only passes [_object] — so _arsenalID param here defaults to "Base")
private _existingID = _object getVariable ["A3A_Arsenal_ID", ""];
if (_existingID isEqualTo "") then {
    _object setVariable ["A3A_Arsenal_ID", _arsenalID, true];
} else {
    _arsenalID = _existingID; // use the ID that was already set
};
private _existingThreshold = _object getVariable ["A3A_Arsenal_Threshold", -1];
if (_existingThreshold < 0) then {
    _object setVariable ["A3A_Arsenal_Threshold", _unlockThreshold, true];
} else {
    _unlockThreshold = _existingThreshold;
};

// Ensure server logic object exists FIRST (before any per-arsenal operations)
// Must be outside jna_commonInitDone since multiple inits can race in scheduled env
if (isServer && {isNil "server"}) then {
    server = (createGroup sideLogic) createUnit ["Logic", [0,0,0], [], 0, "NONE"];
    publicVariable "server";
    Info("JNA created server logic object");
};

// Common init (once per machine) — Preload, minItemMember
if (isNil "jna_commonInitDone") then {
    jna_commonInitDone = true;
    missionNamespace setVariable ["jna_object", _object]; // default, overwritten on each open

    jna_minItemMember = [-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1];
    jna_minItemMember = jna_minItemMember apply { A3A_guestItemLimit };
    jna_minItemMember set [IDC_RSCDISPLAYARSENAL_TAB_CARGOMAG, A3A_guestItemLimit*3];
    jna_minItemMember set [IDC_RSCDISPLAYARSENAL_TAB_CARGOMAGALL, A3A_guestItemLimit*3];
    ["Preload"] call jn_fnc_arsenal;
};

// Per-arsenal server-side init: load data for THIS arsenal by its ID
if (isServer) then {
    // One-time check: ensure A3A_fnc_assignZeus is allowed for remoteExec (Zeus key sequence)
    if (isNil "A3A_remoteExecCheckDone") then {
        A3A_remoteExecCheckDone = true;
        private _fnClass = configFile >> "CfgRemoteExec" >> "Functions" >> "A3A_fnc_assignZeus";
        private _mode = getNumber (configFile >> "CfgRemoteExec" >> "Functions" >> "mode");
        if (_mode == 0) then {
            diag_log "A3A_Arsenal: WARNING - CfgRemoteExec mode=0 (blocked). Zeus key sequence will NOT work.";
        } else {
            if (_mode == 1 && {!isClass _fnClass}) then {
                diag_log "A3A_Arsenal: WARNING - A3A_fnc_assignZeus not in whitelist (mode=1). Zeus key sequence may fail.";
            } else {
                diag_log format ["A3A_Arsenal: CfgRemoteExec OK - A3A_fnc_assignZeus allowed (mode=%1).", _mode];
            };
        };
    };

    private _arsenalID = _object getVariable ["A3A_Arsenal_ID", "Base"];
    private _profileKey = format ["A3A_ArsenalData_%1", _arsenalID];
    private _serverKey = format ["jna_dataList_%1", _arsenalID];
    private _defaultData = [[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[]];

    // Load from profile if not already on server
    if (isNil {server getVariable _serverKey}) then {
        private _loaded = profileNamespace getVariable [_profileKey, _defaultData];
        if (count _loaded != 27 || {!(_loaded select 0 isEqualType [])}) then {
            Info("JNA data format invalid, resetting to default");
            profileNamespace setVariable [_profileKey, nil];
            _loaded = _defaultData;
        };
        server setVariable [_serverKey, _loaded, true];
        Info_1("JNA loaded arsenal data for ID: ", _arsenalID);
    };

    private _data = server getVariable [_serverKey, _defaultData];
    private _itemCount = 0;
    { _itemCount = _itemCount + count _x } forEach _data;
    diag_log format ["A3A_Arsenal Storage: Arsenal '%1' key='%2' | %3 items | profile='%4'", _arsenalID, _profileKey, _itemCount, profileName];
    systemChat format ["A3A Arsenal '%1': %2 items loaded", _arsenalID, _itemCount];

    // Sync Zeus state to clients (getAssignedCuratorLogic unreliable on client in dedicated MP)
    if (isNil "A3A_zeusSyncStarted") then {
        A3A_zeusSyncStarted = true;
        [] spawn {
            while {true} do {
                {
                    private _hasCurator = !isNull (getAssignedCuratorLogic _x);
                    private _hasVar = _x getVariable ["A3A_Arsenal_HasZeus", false];
                    if (_hasCurator && !_hasVar) then {
                        _x setVariable ["A3A_Arsenal_HasZeus", true, true];
                    };
                    if (!_hasCurator && _hasVar) then {
                        _x setVariable ["A3A_Arsenal_HasZeus", nil, true];
                    };
                } forEach allPlayers;
                sleep 5;
            };
        };
        diag_log "A3A_Arsenal: Zeus sync loop started (server).";
    };
};

//player
if(hasInterface)then{
    Info("JNA loading player data");

    // Track arsenal objects for Zeus key sequence proximity check
    if (isNil "A3A_arsenalObjects") then { A3A_arsenalObjects = [] };
    A3A_arsenalObjects pushBackUnique _object;

    // Initialize Zeus key sequence handler (once, idempotent)
    [] call A3A_fnc_zeusKeySequence;

    //add arsenal button
    _object addAction [
        (format ["<img image='%1' size='1.6' shadow=2/>", STR_ACTION_ICON_ARSENAL] + format["<t size='1'> %1</t>", (localize "STR_A3_Arsenal")]),
        JN_fnc_arsenal_handleAction,
        [],
        6,
        true,
        false,
        "",
        "alive _target && {_target distance _this < 5} && {vehicle player == player}"
    ];

    //add vehicle/box filling button
    _object addAction [
		("<img image='" + QPATHTOFOLDER(Pictures\unloadvehicle.paa) + "' size='1.6' shadow=2/>" + format["<t size='1'> %1</t>", localize "STR_JNA_ACT_CONTAINER_OPEN"]),
        {
			private _object = _this select 0;
			
			private _script =  {
				params ["_object"];
				
				//check if player is looking at some object
				private _objectSelected = cursorObject;
				if(isnull _objectSelected)exitWith{hint localize "STR_JNA_ACT_CONTAINER_SELECTERROR1"; };

				//check if object is in range
				if(_object distance cursorObject > 50) exitWith {hint localize "STR_JNA_ACT_CONTAINER_SELECTERROR2";};

				//check if object has inventory
				private _className = typeOf _objectSelected;
				private _tb = getNumber (configFile >> "CfgVehicles" >> _className >> "transportmaxbackpacks");
				private _tm = getNumber (configFile >> "CfgVehicles" >> _className >> "transportmaxmagazines");
				private _tw = getNumber (configFile >> "CfgVehicles" >> _className >> "transportmaxweapons");
				if !(_tb > 0  || _tm > 0 || _tw > 0) exitWith{hint localize "STR_JNA_ACT_CONTAINER_SELECTERROR3";};

				//set type and object to use later
				UINamespace setVariable ["jn_type", "containerArsenal"];
				UINamespace setVariable ["jn_object",_object];
				UINamespace setVariable ["jn_object_selected",_objectSelected];

                //start loading screen and timer to close it if something breaks
				["jn_fnc_arsenal", "Loading Nutz™ Arsenal"] call bis_fnc_startloadingscreen;
				[] spawn {
					uisleep 5;
					private _ids = missionnamespace getvariable ["BIS_fnc_startLoadingScreen_ids",[]];
					if("jn_fnc_arsenal" in _ids)then{
						private _display =  uiNamespace getVariable ["arsenalDisplay","No display"];
						titleText["ERROR DURING LOADING ARSENAL", "PLAIN"];
						_display closedisplay 2;
						["jn_fnc_arsenal"] call BIS_fnc_endLoadingScreen;
					};
				};

                //request server to open arsenal (pass object for multi-arsenal)
                [clientOwner, _object] remoteExecCall ["jn_fnc_arsenal_requestOpen",2];
			};
			private _conditionActive = {
				params ["_object"];
				alive player;
			};
			private _conditionColor = {
				params ["_object"];
				
				!isnull cursorObject
				&&{
					_object distance cursorObject < 10;
				}&&{
					//check if object has inventory
					private _className = typeOf cursorObject;
					private _tb = getNumber (configFile >> "CfgVehicles" >> _className >> "transportmaxbackpacks");
					private _tm = getNumber (configFile >> "CfgVehicles" >> _className >> "transportmaxmagazines");
					private _tw = getNumber (configFile >> "CfgVehicles" >> _className >> "transportmaxweapons");
					if (_tb > 0  || _tm > 0 || _tw > 0) then {true;} else {false;};
				
				}//return
			};

            [localize "STR_A3AP_vehArsenal_header", localize "STR_A3AP_vehArsenal_desc"] call A3A_fnc_customHint;
						
			[_script,_conditionActive,_conditionColor,_object] call jn_fnc_common_addActionSelect;
		},
        [],
        6,
        true,
        false,
        "",
        "alive _target && {_target distance _this < 5 && {vehicle player == player}}"
    ];

    //add export arsenal data button (clipboard + RPT log) — Zeus only
    _object addAction [
        "<t color='#80ff80'>Export Arsenal Data</t>",
        { ["ExportData"] call jn_fnc_arsenal },
        [],
        1,
        false,
        false,
        "",
        "alive _target && {_target distance _this < 5} && {vehicle player == player} && {[_this] call A3A_fnc_arsenal_isZeus}"
    ];

    //add import arsenal data button (from clipboard) — Zeus only
    _object addAction [
        "<t color='#ffaa00'>Import Arsenal Data</t>",
        { ["ImportData"] call jn_fnc_arsenal },
        [],
        1,
        false,
        false,
        "",
        "alive _target && {_target distance _this < 5} && {vehicle player == player} && {[_this] call A3A_fnc_arsenal_isZeus}"
    ];

    //add quick equip button
    //add quick equip button - DISABLED FOR STANDALONE
    /*
    _object addAction [
        (format ["<img image='%1' size='1.6' shadow=2/>", "\A3\ui_f\data\GUI\Rsc\RscDisplayArsenal\vest_ca.paa"] + format["<t size='1'> %1</t>", (localize "STR_JNA_SCT_QUICK_EQUIP")]),
        { 
            private _player = _this select 1;
            private _prefix = "loadouts_reb_militia_";
            private _loadout =  switch (typeOf _player) do {
                case "I_G_medic_F":  { "Medic" }; 
                case "I_G_Soldier_TL_F": { "SquadLeader" };
                case "I_G_Soldier_F": { "Rifleman" };
                case "I_G_Soldier_GL_F": { "Grenadier" };
                case "I_G_Soldier_AR_F": { "MachineGunner" };
                case "I_G_engineer_F":  { "Engineer" };
                default { "Rifleman" };
            };

            private _array = [_player, true] call jn_fnc_arsenal_cargoToArray;
            _player setUnitLoadout (configFile >> "EmptyLoadout");
            [_player, 0, _prefix + _loadout] call A3A_fnc_equipRebel;
            _array call jn_fnc_arsenal_addItem;
        },
        [],
        6,
        true,
        false,
        "",
        "alive _target && {_target distance _this < 5} && {vehicle player == player}"
    ];
    */

    //add open event
    [missionNamespace, "arsenalOpened", {
        disableSerialization;
        UINamespace setVariable ["arsenalDisplay",(_this select 0)];

        //spawn this to make sure it doesnt freeze the game
        [] spawn {
            disableSerialization;
            private _type = UINamespace getVariable ["jn_type",""];
            _veh = vehicle player;

            switch (true) do {
                case (uiNamespace getVariable ["isLoadoutArsenal", false]): {
                    ["CustomInit", [uiNamespace getVariable "arsenalDisplay"]] call SCRT_fnc_arsenal_loadoutArsenal;
                    UINamespace setVariable ["jn_type","loadoutArsenal"];
                };
                case (_type isEqualTo "containerArsenal"): {
                    ["CustomInit", [uiNamespace getVariable "arsenalDisplay"]] call jn_fnc_vehicleArsenal;
                    UINamespace setVariable ["jn_type","containerArsenal"];
                };
                default {
                    ["CustomInit", [uiNamespace getVariable "arsenalDisplay"]] call jn_fnc_arsenal;
                };
            };
        };

    }] call BIS_fnc_addScriptedEventHandler;

	//add close event
    [missionNamespace, "arsenalClosed", {
        _type = UINamespace getVariable ["jn_type",""];

        private _arsenalObj = missionNamespace getVariable ["jna_object", objNull];

        if(_type isEqualTo "arsenal")then{
            [clientOwner, _arsenalObj] remoteExecCall ["jn_fnc_arsenal_requestClose",2];
            // Auto-export to RPT log on arsenal close
            ["ExportData", [true]] call jn_fnc_arsenal;
        };

        if(_type isEqualTo "containerArsenal")then{
            ["Close"] call jn_fnc_vehicleArsenal;
            [clientOwner, _arsenalObj] remoteExecCall ["jn_fnc_arsenal_requestClose",2];
            UINamespace setVariable ["jn_type",""];
        };

        if(_type isEqualTo "loadoutArsenal") then {
            ["Close"] call SCRT_fnc_arsenal_loadoutArsenal;
            [clientOwner, _arsenalObj] remoteExecCall ["jn_fnc_arsenal_requestClose",2];
            UINamespace setVariable ["jn_type",""];
        };

        if (uiNamespace getVariable ["isLoadoutArsenal", false]) then {
            uiNamespace setVariable ["isLoadoutArsenal", nil];
        };

    }] call BIS_fnc_addScriptedEventHandler;
};
Info("JNA init completed");
arsenalInit = true;
