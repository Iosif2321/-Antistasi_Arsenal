#include "defineCommon.inc"
#include "\A3\ui_f\hpp\defineDIKCodes.inc"
#include "\A3\Ui_f\hpp\defineResinclDesign.inc"
#include "..\script_component.hpp"
FIX_LINE_NUMBERS()
///////////////////////////////////////////////////////////////////////////////////////////
scriptName "fn_arsenal_init.sqf";
private _fileName = "fn_arsenal_init.sqf";
diag_log format ["A4A_Arsenal: JNA init started (Version %1)", "0.5.0"];
params [
    ["_object",objNull,[objNull]],
    ["_arsenalID", "Base", [""]],
    ["_unlockThreshold", 25, [0]]
];

// Only the server may distribute initialization. Local client execution can
// at most create client UI, while remote client execution on the server would
// otherwise enroll an attacker-selected object into the canonical registry.
if (isRemoteExecuted && {remoteExecutedOwner != 2}) exitWith {
    diag_log format ["A4A_Arsenal: rejected client-authored JNA init from owner %1", remoteExecutedOwner];
};

if(isNull _object)exitWith{["Error: wrong input given '%1'",_object] call BIS_fnc_error;};

// Network-replicated object variables are UI compatibility only. Private
// per-machine registries decide whether server and client work must run.
private _runServerInit = isServer;
private _runClientInit = hasInterface;
if (_runServerInit) then {
    isNil {
        private _serverInitObjects = localNamespace getVariable ["A4A_Arsenal_ServerInitObjects", []];
        if (_object in _serverInitObjects) then {
            _runServerInit = false;
        } else {
            _serverInitObjects pushBack _object;
            localNamespace setVariable ["A4A_Arsenal_ServerInitObjects", _serverInitObjects];
        };
    };
};
if (_runClientInit) then {
    isNil {
        private _clientInitObjects = localNamespace getVariable ["A4A_Arsenal_ClientInitObjects", []];
        if (_object in _clientInitObjects) then {
            _runClientInit = false;
        } else {
            _clientInitObjects pushBack _object;
            localNamespace setVariable ["A4A_Arsenal_ClientInitObjects", _clientInitObjects];
        };
    };
};
if (!_runServerInit && {!_runClientInit}) exitWith {};
_object setVariable ["A4A_Arsenal_Initialized", true];

// Debug log for client side
if (_runClientInit) then {
    systemChat format ["Antistasi Arsenal: Client Init for %1", _object];
};

// The server resolves canonical ID/threshold only from its pre-registered
// localNamespace entry. Clients may read the public copies for display only.
private _serverRegistrationValid = true;
if (isServer) then {
    private _canonicalRegistry = localNamespace getVariable ["A4A_Arsenal_ServerRegistry", []];
    private _canonicalIndex = _canonicalRegistry findIf {count _x >= 2 && {(_x select 0) isEqualTo _object}};
    if (_canonicalIndex < 0) then {
        _serverRegistrationValid = false;
    } else {
        private _canonicalEntry = _canonicalRegistry select _canonicalIndex;
        _arsenalID = _canonicalEntry select 1;
        _unlockThreshold = _canonicalEntry param [
            2,
            localNamespace getVariable ["A4A_Arsenal_ServerUnlockThreshold", _unlockThreshold],
            [0]
        ];
    };
} else {
    _arsenalID = _object getVariable ["A4A_Arsenal_ID", _arsenalID];
    _unlockThreshold = _object getVariable ["A4A_Arsenal_Threshold", _unlockThreshold];
};
if (isServer && {!_serverRegistrationValid}) exitWith {
    diag_log format ["A4A_Arsenal: JNA server init rejected unregistered object %1", _object];
};

// Ensure server logic object exists FIRST (before any per-arsenal operations)
// Must be outside jna_commonInitDone since multiple inits can race in scheduled env
if (isServer) then {
    isNil {
        if (isNil "server") then {
            server = (createGroup sideLogic) createUnit ["Logic", [0,0,0], [], 0, "NONE"];
            publicVariable "server";
            Info("JNA created server logic object");
        };
    };
};

// Common init (once per machine) - Preload, minItemMember
private _runCommonInit = false;
isNil {
    if !(localNamespace getVariable ["A4A_Arsenal_CommonInitDone", false]) then {
        localNamespace setVariable ["A4A_Arsenal_CommonInitDone", true];
        _runCommonInit = true;
    };
};
if (_runCommonInit) then {
    jna_commonInitDone = true;
    missionNamespace setVariable ["jna_object", _object]; // default, overwritten on each open

    // Server authority uses only the preInit private CBA snapshot/callback.
    if (isServer) then {
        A4A_guestItemLimit = localNamespace getVariable ["A4A_Arsenal_ServerUnlockThreshold", _unlockThreshold];
    } else {
        A4A_guestItemLimit = missionNamespace getVariable ["A4A_Arsenal_UnlockThreshold", _unlockThreshold];
    };

    jna_minItemMember = [-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1,-1];
    jna_minItemMember = jna_minItemMember apply { A4A_guestItemLimit };
    jna_minItemMember set [IDC_RSCDISPLAYARSENAL_TAB_CARGOMAG, A4A_guestItemLimit*3];
    jna_minItemMember set [IDC_RSCDISPLAYARSENAL_TAB_CARGOMAGALL, A4A_guestItemLimit*3];
    ["Preload"] call jn_fnc_arsenal;
};

// Per-arsenal server-side init: load data for THIS arsenal by its ID
if (_runServerInit) then {
	// The server-authoritative reserve calculation must not depend on globals
	// that a client can replicate after initialization.  Snapshot both the
	// per-tab defaults and optional per-class overrides into localNamespace.
	if (isNil {localNamespace getVariable "A4A_Arsenal_ServerMinItems"}) then {
		localNamespace setVariable ["A4A_Arsenal_ServerMinItems", +jna_minItemMember];
		if (isNil {localNamespace getVariable "A4A_Arsenal_ServerLimits"}) then {
			localNamespace setVariable ["A4A_Arsenal_ServerLimits", createHashMap];
		};
	};

    // Private server registry supports proximity checks for privileged requests.
    private _serverArsenalObjects = localNamespace getVariable ["A4A_Arsenal_ServerObjects", []];
    _serverArsenalObjects pushBackUnique _object;
    localNamespace setVariable ["A4A_Arsenal_ServerObjects", _serverArsenalObjects];
    // Fail closed if preInit was bypassed; never import replicated settings here.
    if (isNil {localNamespace getVariable "A4A_Arsenal_ServerEditorSteamIDs"}) then {
        localNamespace setVariable ["A4A_Arsenal_ServerEditorSteamIDs", ""];
    };
    if (isNil {localNamespace getVariable "A4A_Arsenal_ServerEditAccessMode"}) then {
        localNamespace setVariable ["A4A_Arsenal_ServerEditAccessMode", 0];
    };

    // One-time check: ensure A4A_fnc_assignZeus is allowed for remoteExec (Zeus key sequence)
    private _runRemoteExecCheck = false;
    isNil {
        if !(localNamespace getVariable ["A4A_Arsenal_RemoteExecCheckDone", false]) then {
            localNamespace setVariable ["A4A_Arsenal_RemoteExecCheckDone", true];
            _runRemoteExecCheck = true;
        };
    };
    if (_runRemoteExecCheck) then {
        private _fnClass = configFile >> "CfgRemoteExec" >> "Functions" >> "A4A_fnc_assignZeus";
        private _mode = getNumber (configFile >> "CfgRemoteExec" >> "Functions" >> "mode");
        if (_mode == 0) then {
            diag_log "A4A_Arsenal: WARNING - CfgRemoteExec mode=0 (blocked). Zeus key sequence will NOT work.";
        } else {
            if (_mode == 1 && {!isClass _fnClass}) then {
                diag_log "A4A_Arsenal: WARNING - A4A_fnc_assignZeus not in whitelist (mode=1). Zeus key sequence may fail.";
            } else {
                diag_log format ["A4A_Arsenal: CfgRemoteExec OK - A4A_fnc_assignZeus allowed (mode=%1).", _mode];
            };
        };
    };

    private _profileKey = format ["A4A_ArsenalData_%1", _arsenalID];
    private _serverKey = format ["jna_dataList_%1", _arsenalID];
    private _defaultData = [[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[]];

    // Private canonical state. The public GameLogic value below is a legacy
    // read-only mirror and is never accepted back as server authority.
    private _serverData = localNamespace getVariable ["A4A_Arsenal_ServerData", createHashMap];
    private _data = _serverData getOrDefault [_arsenalID, []];
    if (count _data != 27) then {
        _data = profileNamespace getVariable [_profileKey, _defaultData];
        private _validatePersistedData = {
            params ["_candidate"];
            if !(_candidate isEqualType [] && {count _candidate == 27}) exitWith {false};
            private _valid = true;
            private _totalEntries = 0;
            {
                if !(_x isEqualType []) exitWith {_valid = false};
                private _seen = createHashMap;
                {
                    if !(_x isEqualType [] && {count _x == 2}) exitWith {_valid = false};
                    private _className = _x select 0;
                    private _amount = _x select 1;
                    if !(
                        _className isEqualType ""
                        && {!(_className isEqualTo "")}
                        && {count _className <= 256}
                        && {_amount isEqualType 0}
                        && {finite _amount}
                        && {_amount isEqualTo floor _amount}
                        && {_amount == -1 || {_amount > 0 && {_amount <= 100000000}}}
                    ) exitWith {_valid = false};
                    private _key = toLower _className;
                    if (_seen getOrDefault [_key, false]) exitWith {_valid = false};
                    _seen set [_key, true];
                    _totalEntries = _totalEntries + 1;
                    if (_totalEntries > 10000) exitWith {_valid = false};
                } forEach _x;
                if (!_valid) exitWith {};
            } forEach _candidate;
            _valid
        };
        if !([_data] call _validatePersistedData) then {
            Info("JNA data format invalid, resetting to default");
            profileNamespace setVariable [_profileKey, nil];
            _data = _defaultData;
        };
        _serverData set [_arsenalID, _data];
        localNamespace setVariable ["A4A_Arsenal_ServerData", _serverData];
        Info_1("JNA loaded arsenal data for ID: ", _arsenalID);
    };
    server setVariable [_serverKey, _data, true];
    private _serverRevisions = localNamespace getVariable ["A4A_Arsenal_ServerRevisions", createHashMap];
    if (isNil {_serverRevisions get _arsenalID}) then {
        _serverRevisions set [_arsenalID, 0];
        localNamespace setVariable ["A4A_Arsenal_ServerRevisions", _serverRevisions];
    };
    // requestOpen and one-shot save/import remain fail-closed until canonical
    // profile data and revision state are both installed.
    private _readyObjects = localNamespace getVariable ["A4A_Arsenal_ServerReadyObjects", []];
    _readyObjects pushBackUnique _object;
    localNamespace setVariable ["A4A_Arsenal_ServerReadyObjects", _readyObjects];
    private _itemCount = 0;
    { _itemCount = _itemCount + count _x } forEach _data;
    diag_log format ["A4A_Arsenal Init: Arsenal '%1' key='%2' | %3 items loaded | profile='%4'", _arsenalID, _profileKey, _itemCount, profileName];
    diag_log format ["A4A_Arsenal Init: --- Contents of Arsenal '%1' ---", _arsenalID];
    {
        private _tabIndex = _forEachIndex;
        if (count _x > 0) then {
            {
                _x params ["_cls", "_amt"];
                diag_log format ["A4A_Arsenal Init: [%1] Item: %2 | Amount: %3", _arsenalID, _cls, _amt];
            } forEach _x;
        };
    } forEach _data;
    diag_log format ["A4A_Arsenal Init: --- End of Arsenal '%1' ---", _arsenalID];
    
    systemChat format ["A4A Arsenal '%1': %2 items loaded", _arsenalID, _itemCount];

    // Sync Zeus state to clients (getAssignedCuratorLogic unreliable on client in dedicated MP)
    private _startZeusSync = false;
    isNil {
        if !(localNamespace getVariable ["A4A_Arsenal_ZeusSyncStarted", false]) then {
            localNamespace setVariable ["A4A_Arsenal_ZeusSyncStarted", true];
            _startZeusSync = true;
        };
    };
    if (_startZeusSync) then {
        [] spawn {
            while {true} do {
                {
                    private _hasCurator = !isNull (getAssignedCuratorLogic _x);
                    private _hasVar = _x getVariable ["A4A_Arsenal_HasZeus", false];
                    if (_hasCurator && !_hasVar) then {
                        _x setVariable ["A4A_Arsenal_HasZeus", true, true];
                    };
                    if (!_hasCurator && _hasVar) then {
                        _x setVariable ["A4A_Arsenal_HasZeus", nil, true];
                    };
                } forEach allPlayers;
                sleep 5;
            };
        };
        diag_log "A4A_Arsenal: Zeus sync loop started (server).";
    };
};

//player
if (_runClientInit) then {
    Info("JNA loading player data");

    // Track arsenal objects for Zeus key sequence proximity check
    if (isNil "A4A_arsenalObjects") then { A4A_arsenalObjects = [] };
    A4A_arsenalObjects pushBackUnique _object;

    // Initialize Zeus key sequence handler (once, idempotent)
    [] call A4A_fnc_inputHandler;

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
				missionNamespace setVariable ["jna_object", _object];
				UINamespace setVariable ["jn_object",_object];
				UINamespace setVariable ["jn_object_selected",_objectSelected];

                //start loading screen and timer to close it if something breaks
				["jn_fnc_arsenal", "Loading Nutz Arsenal"] call bis_fnc_startloadingscreen;
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

            [localize "STR_A4AP_vehArsenal_header", localize "STR_A4AP_vehArsenal_desc"] call A4A_fnc_customHint;
						
			[_script,_conditionActive,_conditionColor,_object] call jn_fnc_common_addActionSelect;
		},
        [],
        6,
        true,
        false,
        "",
        "alive _target && {_target distance _this < 5} && {vehicle player == player} && {(missionNamespace getVariable ['A4A_Arsenal_ContainerAccess', 0]) != 2} && {(missionNamespace getVariable ['A4A_Arsenal_ContainerAccess', 0]) != 1 || {[_this] call A4A_fnc_arsenal_canEdit}}"
    ];

    //add export arsenal data button (clipboard + RPT log) - authorized editors only
    _object addAction [
        "<t color='#80ff80'>Export Arsenal Data</t>",
        { ["ExportData"] call jn_fnc_arsenal },
        [],
        1,
        false,
        false,
        "",
        "alive _target && {_target distance _this < 5} && {vehicle player == player} && {[_this] call A4A_fnc_arsenal_canEdit}"
    ];

    //add import arsenal data button (from clipboard) - authorized editors only
    _object addAction [
        "<t color='#ffaa00'>Import Arsenal Data</t>",
        {
            params ["_target"];
            // Bind the one-shot import to the action's actual registered object;
            // never reuse a stale missionNamespace object from another arsenal.
            missionNamespace setVariable ["jna_object", _target];
            ["ImportData", [_target, true]] call jn_fnc_arsenal;
        },
        [],
        1,
        false,
        false,
        "",
        "alive _target && {_target distance _this < 5} && {vehicle player == player} && {[_this] call A4A_fnc_arsenal_canEdit}"
    ];

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
            [_player, 0, _prefix + _loadout] call A4A_fnc_equipRebel;
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

    //add open event — CustomInit runs synchronously to prevent BIS full-arsenal fallback from showing
    [missionNamespace, "arsenalOpened", {
        disableSerialization;
        UINamespace setVariable ["arsenalDisplay",(_this select 0)];

        private _display = _this select 0;
        private _type = UINamespace getVariable ["jn_type",""];

        switch (true) do {
            case (uiNamespace getVariable ["isLoadoutArsenal", false]): {
                ["CustomInit", [_display]] call SCRT_fnc_arsenal_loadoutArsenal;
                UINamespace setVariable ["jn_type","loadoutArsenal"];
            };
            case (_type isEqualTo "containerArsenal"): {
                ["CustomInit", [_display]] call jn_fnc_vehicleArsenal;
                UINamespace setVariable ["jn_type","containerArsenal"];
            };
            default {
                ["CustomInit", [_display]] call jn_fnc_arsenal;
            };
        };

    }] call BIS_fnc_addScriptedEventHandler;

	//add close event
    [missionNamespace, "arsenalClosed", {
        private _type = UINamespace getVariable ["jn_type",""];

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
