params [
    ["_key", "", [""]],
    ["_default", nil]
];

private _defaults = localNamespace getVariable ["A4A_ClientSettings", []];
if !(_defaults isEqualType createHashMap) then {
    _defaults = call compile preprocessFileLineNumbers "A4A\config\settings.sqf";
    if !(_defaults isEqualType createHashMap) then { _defaults = createHashMap };
    _defaults = [_defaults] call A4A_fnc_normalizeSettings;
    if (hasInterface) then { localNamespace setVariable ["A4A_ClientSettings", _defaults] };
};
private _fallback = _default;
if (isNil "_fallback" && {_defaults isEqualType createHashMap}) then {
    _fallback = _defaults getOrDefault [_key, nil];
};

switch (toLower _key) do {
    case "uistyle": {
        private _fallbackStyleIndex = if (
            (_fallback isEqualType 0 && {_fallback isEqualTo 1}) ||
            {_fallback isEqualType "" && {toUpper _fallback isEqualTo "ACE"}}
        ) then {1} else {0};
        private _fallbackStyle = ["Legacy", "ACE"] select _fallbackStyleIndex;
        private _rawStyle = missionNamespace getVariable ["A4A_Mission_UIStyle", _fallbackStyleIndex];
        if (_rawStyle isEqualType 0) then {
            if (_rawStyle in [0, 1]) then {
                ["Legacy", "ACE"] select _rawStyle
            } else {
                _fallbackStyle
            }
        } else {
            if (_rawStyle isEqualType "") then {
                switch (toUpper _rawStyle) do {
                    case "ACE": {"ACE"};
                    case "LEGACY": {"Legacy"};
                    default {_fallbackStyle};
                }
            } else {
                _fallbackStyle
            }
        }
    };
    case "cargoaccess": { missionNamespace getVariable ["A4A_Mission_CargoAccess", _fallback] };
    case "editaccessmode": { missionNamespace getVariable ["A4A_Mission_EditAccessMode", _fallback] };
    case "unlockthresholdoverride": { missionNamespace getVariable ["A4A_Mission_UnlockThreshold", _fallback] };
    case "editorsteamids": { missionNamespace getVariable ["A4A_Mission_EditorSteamIDs", _fallback] };
    default { _fallback };
}
