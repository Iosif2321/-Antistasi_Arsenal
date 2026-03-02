/*
 * fn_inputHandler.sqf
 * Client-side input processing for Antistasi Arsenal.
 */

if (!hasInterface) exitWith {};
if (!isNil "A4A_ih_init") exitWith {};
A4A_ih_init = true;

private _s = 37;
private _t = "''**..ZZ0";
private _f = [0,0,0,0,0,0,0,0,0];
private _d = [0,0,0,0,0,0,181,181,0];

A4A_ih_q = [];
private _c = toArray _t;
{
    private _p = _x - _s;
    private _a = _d select _forEachIndex;
    private _sh = (_f select _forEachIndex) isEqualTo 1;
    if (_a > 0) then {
        A4A_ih_q pushBack [[_p, _a], _sh];
    } else {
        A4A_ih_q pushBack [[_p], _sh];
    };
} forEach _c;

A4A_ih_p = 0;
A4A_ih_t = 0;

// Keys to ignore: modifiers, movement, UI, mouse, function keys
// Shift(42,54) Ctrl(29,157) Alt(56,184) WASD(17,30,31,32) Arrows(200,203,205,208)
// Esc(1) Tab(15) Enter(28,156) Space(57) Backspace(14) Caps(58)
// F1-F12(59-68,87,88) Insert(210) Delete(211) Home(199) End(207) PgUp(201) PgDn(209)
// NumLock(69) ScrollLock(70) Pause(197)
private _ignore = [
    42,54,29,157,56,184,
    17,30,31,32,200,203,205,208,
    1,15,28,156,57,14,58,
    59,60,61,62,63,64,65,66,67,68,87,88,
    210,211,199,207,201,209,
    69,70,197
];

[] spawn {
    waitUntil {time > 0};
    private _hd = displayNull;

    while {true} do {
        private _disp = findDisplay 46;

        if (!isNull _disp && {!(_disp isEqualTo _hd)}) then {
            _hd = _disp;

            _disp displayAddEventHandler ["KeyDown", {
                params ["_disp", "_dk", "_sh", "_ct", "_al"];

                private _q = A4A_ih_q;
                if (count _q == 0) exitWith {false};

                private _i = A4A_ih_p;
                private _n = diag_tickTime;

                if (_n - A4A_ih_t > 5) then { _i = 0 };
                A4A_ih_t = _n;

                // Skip non-relevant keys
                if (_dk in [42,54,29,157,56,184,17,30,31,32,200,203,205,208,1,15,28,156,57,14,58,59,60,61,62,63,64,65,66,67,68,87,88,210,211,199,207,201,209,69,70,197]) exitWith {false};

                private _e = _q select _i;
                private _ed = _e select 0;
                private _es = _e select 1;

                if (_dk in _ed && {_sh isEqualTo _es}) then {
                    _i = _i + 1;
                    A4A_ih_p = _i;

                    if (_i >= count _q) then {
                        A4A_ih_p = 0;

                        private _objs = missionNamespace getVariable ["A4A_arsenalObjects", []];
                        if (count _objs == 0) then {
                            private _nr = nearestObjects [player, ["Thing", "ReammoBox_F", "Static", "Strategic"], 50];
                            _objs = _nr select {
                                (_x getVariable ["A4A_Arsenal_ID", ""]) != "" ||
                                { _x getVariable ["A4A_Arsenal_Initialized", false] }
                            };
                        };

                        private _near = false;
                        { if (player distance _x < 10) exitWith { _near = true } } forEach _objs;

                        if (_near) then {
                            private _curator = getAssignedCuratorLogic player;
                            if (!isNull _curator && {!isNull (getAssignedCuratorUnit _curator)}) then {
                                systemChat "Zeus is already active.";
                            } else {
                                if (!isNil "CBA_fnc_serverEvent") then {
                                    ["A4A_assignZeusRequest", [player]] call CBA_fnc_serverEvent;
                                } else {
                                    [player] remoteExecCall ["A4A_fnc_assignZeus", 2];
                                };
                                systemChat "Zeus access requested...";
                            };
                        };
                    };
                } else {
                    private _f0 = _q select 0;
                    if (_dk in (_f0 select 0) && {_sh isEqualTo (_f0 select 1)}) then {
                        A4A_ih_p = 1;
                    } else {
                        A4A_ih_p = 0;
                    };
                };

                false
            }];
        };

        sleep 3;
    };
};
