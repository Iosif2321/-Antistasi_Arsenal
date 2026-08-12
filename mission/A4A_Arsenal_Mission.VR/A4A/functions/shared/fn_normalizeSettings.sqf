/*
    Treat settings.sqf and optional adapter values as untrusted configuration.
    Return a new map containing only known keys with bounded values.
*/
params [["_source", createHashMap, [createHashMap]]];

private _boundedNumber = {
    params ["_key", "_default", "_minimum", "_maximum"];
    private _value = _source getOrDefault [_key, _default];
    if (
        _value isEqualType 0 &&
        {finite _value} &&
        {_value >= _minimum} &&
        {_value <= _maximum}
    ) then { _value } else { _default }
};

private _boundedInteger = {
    params ["_key", "_default", "_minimum", "_maximum"];
    private _value = [_key, _default, _minimum, _maximum] call _boundedNumber;
    if (_value isEqualTo floor _value) then { _value } else { _default }
};

private _rawStyle = _source getOrDefault ["uiStyle", "Legacy"];
private _uiStyle = if (
    (_rawStyle isEqualType 0 && {_rawStyle isEqualTo 1}) ||
    {_rawStyle isEqualType "" && {toUpper _rawStyle isEqualTo "ACE"}}
) then { "ACE" } else { "Legacy" };

private _cargoAccess = ["cargoAccess", 0, 0, 2] call _boundedInteger;
if !(_cargoAccess in [0, 1, 2]) then { _cargoAccess = 0 };
private _editAccessMode = ["editAccessMode", 0, 0, 1] call _boundedInteger;
if !(_editAccessMode in [0, 1]) then { _editAccessMode = 0 };

private _editorSteamIDs = [];
private _seenIds = createHashMap;
private _rawIds = _source getOrDefault ["editorSteamIDs", []];
if (_rawIds isEqualType []) then {
    {
        if (
            _x isEqualType "" &&
            {_x isNotEqualTo ""} &&
            {count _x >= 8} &&
            {count _x <= 32} &&
            {parseNumber _x > 0} &&
            {isNil {_seenIds get _x}}
        ) then {
            _seenIds set [_x, true];
            _editorSteamIDs pushBack _x;
        };
    } forEach _rawIds;
};

createHashMapFromArray [
    ["uiStyle", _uiStyle],
    ["unlockThreshold", ["unlockThreshold", 25, 0, 100000000] call _boundedInteger],
    ["interactionDistance", ["interactionDistance", 5, 1, 50] call _boundedNumber],
    ["cargoDistance", ["cargoDistance", 15, 1, 100] call _boundedNumber],
    ["cargoAccess", _cargoAccess],
    ["sessionLifetime", ["sessionLifetime", 900, 60, 86400] call _boundedNumber],
    ["transactionLifetime", ["transactionLifetime", 10, 1, 60] call _boundedNumber],
    ["maxEntries", ["maxEntries", 10000, 1, 10000] call _boundedInteger],
    ["maxCargoEntries", ["maxCargoEntries", 2000, 1, 2000] call _boundedInteger],
    ["maxPayloadCharacters", ["maxPayloadCharacters", 2000000, 1024, 2000000] call _boundedInteger],
    ["maxAmount", ["maxAmount", 100000000, 1, 100000000] call _boundedInteger],
    ["unlockThresholdOverride", ["unlockThresholdOverride", 0, 0, 25000] call _boundedInteger],
    ["editorSteamIDs", _editorSteamIDs],
    ["editAccessMode", _editAccessMode]
]
