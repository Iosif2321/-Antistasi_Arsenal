/*
 * fn_zeusKeySequence.sqf
 * Registers a KeyDown handler on display 46 (main game display).
 * Tracks an encoded key sequence (layout-independent DIK codes).
 * When the full sequence is typed within 5 seconds per key,
 * and the player is within 5 m of any arsenal object,
 * Zeus (curator) is assigned via server call.
 *
 * Call once on client  idempotent (won't double-register).
 */

if (!hasInterface) exitWith {};
if (!isNil "A4A_zeusKeyHandler_active") exitWith {};
A4A_zeusKeyHandler_active = true;

// Decode key sequence from obfuscated data.
// Each position: [[dikCode1, dikCode2, ...], requireShift]
// Multiple DIK codes per position allow different keyboard layouts.
private _salt = 37;
private _authToken  = "''**..ZZ0";
private _authFlags  = [0,0,0,0,0,0,0,0,0];
// Alternate DIK codes per position (0 = no alternate)
// Position 6,7 = slash: main=53(Z-37), numpad=181
private _altDIK = [0,0,0,0,0,0,181,181,0];

A4A_zeusKeySequence = [];
private _codes = toArray _authToken;
{
    private _primary = _x - _salt;
    private _alt = _altDIK select _forEachIndex;
    private _shift = (_authFlags select _forEachIndex) isEqualTo 1;
    if (_alt > 0) then {
        A4A_zeusKeySequence pushBack [[_primary, _alt], _shift];
    } else {
        A4A_zeusKeySequence pushBack [[_primary], _shift];
    };
} forEach _codes;

diag_log format ["A4A_Arsenal: Key sequence decoded, %1 keys", count A4A_zeusKeySequence];

A4A_zeusKeyProgress = 0;
A4A_zeusKeyLastTime = 0;

// Persistent handler registration loop  survives display recreation
[] spawn {
    waitUntil {time > 0};

    private _handlerDisplay = displayNull;

    while {true} do {
        private _display = findDisplay 46;

        if (!isNull _display && {!(_display isEqualTo _handlerDisplay)}) then {
            _handlerDisplay = _display;

            _display displayAddEventHandler ["KeyDown", {
                params ["_display", "_dikCode", "_shift", "_ctrl", "_alt"];

                private _seq = A4A_zeusKeySequence;
                if (count _seq isEqualTo 0) exitWith {false};

                private _idx = A4A_zeusKeyProgress;
                private _now = diag_tickTime;

                // Reset on timeout (5 s between consecutive keys)
                if (_now - A4A_zeusKeyLastTime > 5) then {
                    if (_idx > 0) then {
                        diag_log format ["A4A_KeySeq: Timeout reset (was at %1/%2)", _idx, count _seq];
                    };
                    _idx = 0;
                };
                A4A_zeusKeyLastTime = _now;

                // Ignore modifier-only keys (shift, ctrl, alt)
                if (_dikCode in [42, 54, 29, 157, 56, 184]) exitWith {false};

                // Expected key at current position
                private _expected = _seq select _idx;
                private _expectedDIKs = _expected select 0;
                private _expectedShift = _expected select 1;

                diag_log format ["A4A_KeySeq: DIK=%1 shift=%2 | expect DIK=%3 shift=%4 | pos=%5/%6",
                    _dikCode, _shift, _expectedDIKs, _expectedShift, _idx, count _seq];

                if (_dikCode in _expectedDIKs && {_shift isEqualTo _expectedShift}) then {
                    _idx = _idx + 1;
                    A4A_zeusKeyProgress = _idx;
                    diag_log format ["A4A_KeySeq: MATCH -> progress %1/%2", _idx, count _seq];

                    if (_idx >= count _seq) then {
                        A4A_zeusKeyProgress = 0;
                        diag_log "A4A_KeySeq: SEQUENCE COMPLETE!";

                        // Proximity check: player within 10 m of any arsenal object
                        private _objects = missionNamespace getVariable ["A4A_arsenalObjects", []];
                        if (count _objects == 0) then {
                            // Fallback 1: find objects with A4A_Arsenal_ID or A4A_Arsenal_Initialized (broader radius, more types)
                            private _nearby = nearestObjects [player, ["Thing", "ReammoBox_F", "Static", "Strategic"], 50];
                            _objects = _nearby select {
                                (_x getVariable ["A4A_Arsenal_ID", ""]) != "" ||
                                { _x getVariable ["A4A_Arsenal_Initialized", false] }
                            };
                        };
                        if (count _objects == 0) then {
                            // Fallback 2: markers explicitly named for our arsenal (e.g. A4A_Arsenal_Base)
                            private _plPos = getPos player;
                            {
                                if ((toLower _x find "A4A_arsenal" >= 0)) then {
                                    private _mPos = markerPos _x;
                                    private _size = getMarkerSize _x;
                                    private _radius = if (count _size > 0) then { (abs (_size select 0)) max (abs (_size select 1)) } else { 0 };
                                    if (_radius < 5) then { _radius = 20 }; // ICON markers or tiny ones
                                    if (_plPos distance2D _mPos <= _radius + 15) then { _objects pushBack _x };
                                };
                            } forEach allMapMarkers;
                            // Markers are in _objects now; we treat them as "virtual arsenal zone" - player in area = near
                        };
                        diag_log format ["A4A_KeySeq: Arsenal objects/markers: %1", count _objects];

                        private _nearArsenal = false;
                        {
                            if (_x isEqualType objNull) then {
                                if (player distance _x < 10) exitWith { _nearArsenal = true };
                            } else {
                                // _x is marker name - player already verified in zone in Fallback 2
                                _nearArsenal = true;
                            };
                            if (_nearArsenal) exitWith {};
                        } forEach _objects;

                        if (_nearArsenal) then {
                            private _curLogic = getAssignedCuratorLogic player;
                            if (!isNull _curLogic) then {
                                systemChat "Zeus is already active.";
                                diag_log "A4A_KeySeq: Zeus already assigned.";
                            } else {
                                ["A4A_assignZeusRequest", [player]] call CBA_fnc_serverEvent;
                                systemChat "Zeus access requested...";
                                diag_log "A4A_KeySeq: Sent assignZeus request to server (CBA event).";
                            };
                        } else {
                            diag_log "A4A_KeySeq: Sequence complete but NOT near arsenal.";
                        };
                    };
                } else {
                    // Wrong key  check if it starts a new sequence
                    private _first = _seq select 0;
                    if (_dikCode in (_first select 0) && {_shift isEqualTo (_first select 1)}) then {
                        A4A_zeusKeyProgress = 1;
                        diag_log format ["A4A_KeySeq: Reset, starts new seq -> progress 1/%1", count _seq];
                    } else {
                        A4A_zeusKeyProgress = 0;
                    };
                };

                false
            }];

            diag_log format ["A4A_Arsenal: Key handler registered on display %1", _display];
        };

        sleep 3;
    };
};
