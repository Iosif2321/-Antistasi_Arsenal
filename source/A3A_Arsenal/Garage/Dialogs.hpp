// Base GUI classes (required by Arma 3 dialog system)
class RscText;
class RscButton;
class RscListBox;
class RscStructuredText;

// Garage Vehicle Select Dialog
class A3A_GRG_Dialog {
    idd = 18001;
    movingEnable = 0;
    enableSimulation = 1;
    onLoad = "['onLoad', _this] call A3A_fnc_garage";
    onUnload = "['onUnload', _this] call A3A_fnc_garage";

    class controlsBackground {
        // Dark overlay behind dialog
        class Background: RscText {
            idc = -1;
            x = "safezoneX";
            y = "safezoneY";
            w = "safezoneW";
            h = "safezoneH";
            colorBackground[] = {0, 0, 0, 0.6};
        };
        // Main panel background
        class Panel: RscText {
            idc = -1;
            x = "safezoneX + safezoneW * 0.15";
            y = "safezoneY + safezoneH * 0.08";
            w = "safezoneW * 0.7";
            h = "safezoneH * 0.84";
            colorBackground[] = {0.05, 0.05, 0.05, 0.95};
        };
    };

    class controls {
        // Title
        class Title: RscText {
            idc = 1800300;
            x = "safezoneX + safezoneW * 0.16";
            y = "safezoneY + safezoneH * 0.09";
            w = "safezoneW * 0.5";
            h = "safezoneH * 0.04";
            colorBackground[] = {0.15, 0.15, 0.15, 1};
            text = "Garage";
            sizeEx = "safezoneH * 0.03";
        };
        // Vehicle count
        class Count: RscText {
            idc = 1800305;
            x = "safezoneX + safezoneW * 0.66";
            y = "safezoneY + safezoneH * 0.09";
            w = "safezoneW * 0.12";
            h = "safezoneH * 0.04";
            colorBackground[] = {0.15, 0.15, 0.15, 1};
            text = "0 / 0";
            sizeEx = "safezoneH * 0.025";
            style = 1; // right align
        };
        // Close button
        class BtnClose: RscButton {
            idc = 1800301;
            x = "safezoneX + safezoneW * 0.79";
            y = "safezoneY + safezoneH * 0.09";
            w = "safezoneW * 0.05";
            h = "safezoneH * 0.04";
            text = "X";
            colorBackground[] = {0.5, 0.1, 0.1, 1};
            onButtonClick = "['close'] call A3A_fnc_garage";
        };

        // Category buttons row
        class BtnCars: RscButton {
            idc = 1800200;
            x = "safezoneX + safezoneW * 0.16";
            y = "safezoneY + safezoneH * 0.14";
            w = "safezoneW * 0.1";
            h = "safezoneH * 0.04";
            text = "Cars";
            colorBackground[] = {0.3, 0.3, 0.1, 1};
            onButtonClick = "['switchCat', [0]] call A3A_fnc_garage";
        };
        class BtnArmor: RscButton {
            idc = 1800201;
            x = "safezoneX + safezoneW * 0.265";
            y = "safezoneY + safezoneH * 0.14";
            w = "safezoneW * 0.1";
            h = "safezoneH * 0.04";
            text = "Armor";
            colorBackground[] = {0.2, 0.2, 0.2, 1};
            onButtonClick = "['switchCat', [1]] call A3A_fnc_garage";
        };
        class BtnHeli: RscButton {
            idc = 1800202;
            x = "safezoneX + safezoneW * 0.37";
            y = "safezoneY + safezoneH * 0.14";
            w = "safezoneW * 0.1";
            h = "safezoneH * 0.04";
            text = "Heli";
            colorBackground[] = {0.2, 0.2, 0.2, 1};
            onButtonClick = "['switchCat', [2]] call A3A_fnc_garage";
        };
        class BtnPlane: RscButton {
            idc = 1800203;
            x = "safezoneX + safezoneW * 0.475";
            y = "safezoneY + safezoneH * 0.14";
            w = "safezoneW * 0.1";
            h = "safezoneH * 0.04";
            text = "Plane";
            colorBackground[] = {0.2, 0.2, 0.2, 1};
            onButtonClick = "['switchCat', [3]] call A3A_fnc_garage";
        };
        class BtnBoat: RscButton {
            idc = 1800204;
            x = "safezoneX + safezoneW * 0.58";
            y = "safezoneY + safezoneH * 0.14";
            w = "safezoneW * 0.1";
            h = "safezoneH * 0.04";
            text = "Boat";
            colorBackground[] = {0.2, 0.2, 0.2, 1};
            onButtonClick = "['switchCat', [4]] call A3A_fnc_garage";
        };
        class BtnStatic: RscButton {
            idc = 1800205;
            x = "safezoneX + safezoneW * 0.685";
            y = "safezoneY + safezoneH * 0.14";
            w = "safezoneW * 0.1";
            h = "safezoneH * 0.04";
            text = "Static";
            colorBackground[] = {0.2, 0.2, 0.2, 1};
            onButtonClick = "['switchCat', [5]] call A3A_fnc_garage";
        };

        // Vehicle list (one per category, stacked  only active one shown)
        #define LISTBOX_POS_X "safezoneX + safezoneW * 0.16"
        #define LISTBOX_POS_Y "safezoneY + safezoneH * 0.19"
        #define LISTBOX_W     "safezoneW * 0.52"
        #define LISTBOX_H     "safezoneH * 0.65"

        class ListCars: RscListBox {
            idc = 1800100;
            x = LISTBOX_POS_X; y = LISTBOX_POS_Y; w = LISTBOX_W; h = LISTBOX_H;
            colorBackground[] = {0.1, 0.1, 0.1, 0.9};
            onLBSelChanged = "['selChanged', _this] call A3A_fnc_garage";
        };
        class ListArmor: ListCars { idc = 1800101; };
        class ListHeli: ListCars { idc = 1800102; };
        class ListPlane: ListCars { idc = 1800103; };
        class ListBoat: ListCars { idc = 1800104; };
        class ListStatic: ListCars { idc = 1800105; };

        // Info panel (right side)
        class InfoPanel: RscStructuredText {
            idc = 1800304;
            x = "safezoneX + safezoneW * 0.69";
            y = "safezoneY + safezoneH * 0.19";
            w = "safezoneW * 0.15";
            h = "safezoneH * 0.45";
            colorBackground[] = {0.08, 0.08, 0.08, 0.9};
            size = "safezoneH * 0.022";
        };

        // Store button (park vehicle into garage)
        class BtnStore: RscButton {
            idc = 1800302;
            x = "safezoneX + safezoneW * 0.69";
            y = "safezoneY + safezoneH * 0.66";
            w = "safezoneW * 0.15";
            h = "safezoneH * 0.05";
            text = "STORE VEHICLE";
            colorBackground[] = {0.1, 0.35, 0.1, 1};
            onButtonClick = "['storeVehicle'] call A3A_fnc_garage";
        };
        // Retrieve button (spawn vehicle from garage)
        class BtnRetrieve: RscButton {
            idc = 1800303;
            x = "safezoneX + safezoneW * 0.69";
            y = "safezoneY + safezoneH * 0.72";
            w = "safezoneW * 0.15";
            h = "safezoneH * 0.05";
            text = "RETRIEVE";
            colorBackground[] = {0.1, 0.1, 0.5, 1};
            onButtonClick = "['retrieveVehicle'] call A3A_fnc_garage";
        };
    };
};
