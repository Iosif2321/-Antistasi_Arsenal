/*
    Rows: [editor variable name, persistent arsenal ID, automatic unlock threshold].
    A positive threshold converts a finite row to -1 when that many physical
    items have been accumulated. For magazines, the V1 round pool uses
    threshold * CfgMagazines count. Zero disables automatic unlocks.
    The example mission creates a box named a4a_arsenal_base in mission.sqm.
*/
[
    ["a4a_arsenal_base", "Base", 25]
]
