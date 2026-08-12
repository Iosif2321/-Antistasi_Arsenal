/*
    Converts finite canonical rows to the explicit unlimited marker once the
    configured physical-item threshold is reached. V1 magazine stock stores
    remaining rounds, so a magazine threshold is converted to rounds using the
    magazine's configured capacity.

    A threshold of zero disables automatic unlocks for that Arsenal.
    Returns [normalizedData, changed].
*/
params [
    ["_data", [], [[]]],
    ["_threshold", 0, [0]]
];
if (!isServer) exitWith { [parseSimpleArray str _data, false] };

private _normalized = parseSimpleArray str _data;
if !(
    count _normalized isEqualTo 27 &&
    {_threshold isEqualType 0} &&
    {finite _threshold} &&
    {_threshold isEqualTo floor _threshold} &&
    {_threshold > 0}
) exitWith { [_normalized, false] };

private _changed = false;
{
    private _bucketIndex = _forEachIndex;
    private _bucket = _x;
    if (_bucket isEqualType []) then {
        {
            private _rowIndex = _forEachIndex;
            if (_x isEqualType [] && {count _x isEqualTo 2}) then {
                _x params ["_className", "_amount"];
                if (
                    _className isEqualType "" &&
                    {_className isNotEqualTo ""} &&
                    {_amount isEqualType 0} &&
                    {finite _amount} &&
                    {_amount >= 0}
                ) then {
                    private _requiredAmount = _threshold;
                    if (isClass (configFile >> "CfgMagazines" >> _className)) then {
                        private _magazineCapacity = (getNumber (configFile >> "CfgMagazines" >> _className >> "count")) max 1;
                        _requiredAmount = _threshold * _magazineCapacity;
                    };
                    if (_amount >= _requiredAmount) then {
                        _bucket set [_rowIndex, [_className, -1]];
                        _changed = true;
                    };
                };
            };
        } forEach _bucket;
        _normalized set [_bucketIndex, _bucket];
    };
} forEach _normalized;

[_normalized, _changed]
