
#include "\A3\ui_f\hpp\defineDIKCodes.inc"
#include "\A3\Ui_f\hpp\defineResinclDesign.inc"

// Clients must send normalized deltas through the sender-bound dispatcher.
// Reject direct remote execution of this permissive bulk wrapper on server.
if (isRemoteExecuted) exitWith {
	diag_log format ["A4A_Arsenal: rejected direct remote removeItem wrapper from owner %1", remoteExecutedOwner];
};

private _array = [[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[],[]];

if(typeName (_this select 0) isEqualTo "SCALAR")then{//[_index, _item] or [_index, _item, _amount];
	params["_index","_item",["_amount",1]];
	_array set [_index,[[_item,_amount]]];
}else{
	_array = _this;
};

{
	private _index = _forEachIndex;
	{
		private _item = _x select 0;
		private _amount = _x select 1;

		if!(_item isEqualTo "")then{

			if(_index == -1)exitWith{["ERROR in additemarsenal: %1", _this] call BIS_fnc_error};
			if(_index == IDC_RSCDISPLAYARSENAL_TAB_CARGOMAG)then{_index = IDC_RSCDISPLAYARSENAL_TAB_CARGOMAGALL};

			// Clients pre-apply for responsive UI. Hosted servers use the server path once.
			if (!isServer && {!isNil "jna_dataList"}) then {
				jna_dataList set [_index, [jna_dataList select _index, [_item, _amount]] call jn_fnc_arsenal_removeFromArray];
			};

			// Send only to the server. The server fans out a sanitized committed delta.
			private _curArsenalID = (missionNamespace getVariable ["jna_object", objNull]) getVariable ["A4A_Arsenal_ID", "Base"];
			if (isServer) then { ["UpdateItemRemove",[_index, _item, _amount,true, name player, getPlayerUID player, _curArsenalID]] call jn_fnc_arsenal }
			else { ["UpdateItemRemove",[_index, _item, _amount,true, name player, getPlayerUID player, _curArsenalID]] remoteExecCall ["jn_fnc_arsenal",2] };
		};
	} forEach _x;
}foreach _array;
