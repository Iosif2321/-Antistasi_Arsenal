/*
 * Check if unit has Zeus. Uses variable fallback for key-sequence-assigned Zeus
 * (getAssignedCuratorLogic can lag on client after assignCurator on server).
 */
params [["_unit", player, [objNull]]];
if (isNull _unit) exitWith { false };

(!isNull (getAssignedCuratorLogic _unit)) || { _unit getVariable ["A3A_Arsenal_HasZeus", false] }
