#include "script_component.hpp"

class CfgPatches {
    class A3A_Arsenal {
        units[] = {"A3A_ModuleArsenal", "A3A_ModuleGarage"};
        requiredVersion = 1.0;
        requiredAddons[] = {"A3_Modules_F", "A3_UI_F", "A3_Structures_F_Heli_Items_Electronics"};
        version = 0.4;
        versionStr = "0.4.0";
        versionAr[] = {0,4,0};
        author = "Zeta Ded";
    };
};

class CfgFactionClasses {
    class NO_CATEGORY;
    class A3A_Arsenal_Category: NO_CATEGORY {
        displayName = "Antistasi Arsenal";
    };
};

class CfgRemoteExec {
    class Functions {
        mode = 2;
        jip = 1;
        class A3A_fnc_arsenalInit { allowedTargets = 0; };
        class jn_fnc_arsenal { allowedTargets = 0; };
        class jn_fnc_arsenal_init { allowedTargets = 0; };
        class jn_fnc_arsenal_requestOpen { allowedTargets = 2; };
        class jn_fnc_arsenal_handleAction { allowedTargets = 0; };
        class A3A_fnc_assignZeus { allowedTargets = 2; };
        class A3A_fnc_arsenalLogic { allowedTargets = 2; };
        class A3A_fnc_garage { allowedTargets = 0; };
        class A3A_fnc_garageInit { allowedTargets = 0; };
    };
    // Allow engine commands (systemChat etc.) via remoteExec
    class Commands {
        mode = 1; // 1 = allow all commands
        jip = 0;
    };
};

// Garage dialog
#include "Garage\Dialogs.hpp"

class CfgFunctions {
    class A3A {
        class Arsenal {
            file = "A3A_Arsenal\functions";
            class moduleArsenal {};
            class arsenalInit {};
            class arsenalLogic {};
            class arsenal_isZeus {};
            class zeusKeySequence {};
            class assignZeus {};
            class a3a_stub { preInit = 1; };
        };
        class Garage {
            file = "A3A_Arsenal\Garage";
            class garage {};
            class garageInit {};
            class moduleGarage {};
        };
    };
    
    // Ported Jeroen Arsenal Functions
    class JN {
        class Common {
            file = "A3A_Arsenal\Common";
            class common_addActionSelect {};
            class common_addActionCancel {};
            class common_updateActionCancel {};
            class common_removeActionCancel {};
            class common_getActionCanceled {};
        };

        class Common_Vehicle {
            file = "A3A_Arsenal\Common\vehicle";
            class common_vehicle_getSeatNames {};
            class common_vehicle_getVehicleType {};
        };

        class Common_Array {
            file = "A3A_Arsenal\Common\array";
            class common_array_add {};
            class common_array_remove {};
        };

        class JNA {
            file = "A3A_Arsenal\JNA";
            class arsenal {};
            class arsenal_addItem {};
            class arsenal_addToArray {};
            class arsenal_cargoToArray {};
            class arsenal_cargoToArsenal {};
            class arsenal_handleAction {};
            class arsenal_init {};
            class arsenal_inList {};
            class arsenal_itemCount {};
            class arsenal_itemType {};
            class arsenal_loadInventory {};
            class arsenal_removeFromArray {};
            class arsenal_removeItem {};
            class arsenal_requestOpen {};
            class arsenal_requestClose {};
            class vehicleArsenal {};
        };
    };
};

class CfgVehicles {
    class Logic;
    class Module_F: Logic {
        class AttributesBase {
            class Default;
            class Edit;
            class Combo;
            class Checkbox;
            class CheckboxNumber;
            class ModuleDescription;
            class Units;
        };
        class ModuleDescription {
            class AnyBrain;
        };
    };

    class A3A_ModuleArsenal: Module_F {
        scope = 2;
        displayName = "Antistasi Arsenal";
        icon = "\A3\ui_f\data\igui\cfg\simpletasks\types\rearm_ca.paa";
        category = "A3A_Arsenal_Category";
        function = "A3A_fnc_moduleArsenal";
        functionPriority = 1;
        isGlobal = 0;
        isTriggerActivated = 0;
        isDisposable = 1;
        is3DEN = 0;

        class Attributes: AttributesBase {
            class ArsenalID: Edit {
                property = "A3A_Arsenal_ID";
                displayName = "Arsenal ID";
                tooltip = "Unique ID for this arsenal (e.g., 'Base', 'Outpost'). Used for saving.";
                defaultValue = "'Base'";
            };
            class UnlockThreshold: Edit {
                property = "A3A_Arsenal_Threshold";
                displayName = "Unlock Threshold";
                tooltip = "Number of items required to unlock infinite use.";
                defaultValue = "25";
                typeName = "NUMBER";
            };
            class ModuleDescription: ModuleDescription {};
        };

        class ModuleDescription: ModuleDescription {
            description = "Synchronize this module with an object to turn it into a persistent Antistasi-style Arsenal.";
            sync[] = {"AnyVehicle"};
        };
    };

    class A3A_ModuleGarage: Module_F {
        scope = 2;
        displayName = "Antistasi Garage";
        icon = "\A3\ui_f\data\map\vehicleicons\iconCar_ca.paa";
        category = "A3A_Arsenal_Category";
        function = "A3A_fnc_moduleGarage";
        functionPriority = 1;
        isGlobal = 0;
        isTriggerActivated = 0;
        isDisposable = 1;
        is3DEN = 0;

        class Attributes: AttributesBase {
            class GarageID: Edit {
                property = "A3A_Garage_ID";
                displayName = "Garage ID";
                tooltip = "Unique ID for this garage (e.g., 'Base', 'Airfield'). Used for saving.";
                defaultValue = "'Default'";
            };
            class ModuleDescription: ModuleDescription {};
        };

        class ModuleDescription: ModuleDescription {
            description = "Synchronize this module with an object to turn it into a persistent vehicle Garage. Players can store and retrieve vehicles.";
            sync[] = {"AnyVehicle"};
        };
    };
};
