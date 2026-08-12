params [["_candidate", [], [[]]]];
if (!isServer || {count _candidate isNotEqualTo 27}) exitWith {
    [false, [], 0, "Snapshot must contain exactly 27 buckets."]
};

private _settings = localNamespace getVariable ["A4A_ServerSettings", createHashMap];
private _maxEntries = _settings getOrDefault ["maxEntries", 10000];
private _maxPayloadCharacters = _settings getOrDefault ["maxPayloadCharacters", 2000000];
private _maxAmount = _settings getOrDefault ["maxAmount", 100000000];
if (count str _candidate > _maxPayloadCharacters) exitWith {
    [false, [], 0, format ["Snapshot exceeds %1 serialized characters.", _maxPayloadCharacters]]
};
private _normalized = [];
_normalized resize 27;
private _seenClasses = createHashMap;
private _totalEntries = 0;
private _valid = true;
private _message = "";

for "_bucketIndex" from 0 to 26 do {
    if (!_valid) exitWith {};
    private _bucket = _candidate select _bucketIndex;
    if !(_bucket isEqualType []) then {
        _valid = false;
        _message = format ["Bucket %1 is not an array.", _bucketIndex];
    } else {
        private _normalizedBucket = [];
        {
            if (!_valid) exitWith {};
            private _row = _x;
            if !(_row isEqualType [] && {count _row isEqualTo 2}) then {
                _valid = false;
                _message = format ["Bucket %1 contains a malformed row.", _bucketIndex];
            } else {
                _row params ["_className", "_amount"];
                if !(
                    _className isEqualType "" &&
                    {_className isNotEqualTo ""} &&
                    {count _className <= 256} &&
                    {_amount isEqualType 0} &&
                    {finite _amount} &&
                    {_amount isEqualTo floor _amount} &&
                    {_amount isEqualTo -1 || {_amount > 0 && {_amount <= _maxAmount}}}
                ) then {
                    _valid = false;
                    _message = format ["Invalid row in bucket %1.", _bucketIndex];
                } else {
                    private _classKey = toLower _className;
                    if (_seenClasses getOrDefault [_classKey, false]) then {
                        _valid = false;
                        _message = format ["Duplicate class '%1'.", _className];
                    } else {
                        private _derivedIndex = [_className, false] call A4A_fnc_itemTypeCached;
                        if (_derivedIndex isNotEqualTo _bucketIndex) then {
                            _valid = false;
                            _message = format ["Class '%1' belongs to bucket %2, not %3.", _className, _derivedIndex, _bucketIndex];
                        } else {
                            _seenClasses set [_classKey, true];
                            _normalizedBucket pushBack [_className, _amount];
                            _totalEntries = _totalEntries + 1;
                            if (_totalEntries > _maxEntries) then {
                                _valid = false;
                                _message = format ["Snapshot exceeds %1 entries.", _maxEntries];
                            };
                        };
                    };
                };
            };
        } forEach _bucket;
        _normalized set [_bucketIndex, _normalizedBucket];
    };
};

if (!_valid) exitWith { [false, [], _totalEntries, _message] };
[true, _normalized, _totalEntries, ""]
