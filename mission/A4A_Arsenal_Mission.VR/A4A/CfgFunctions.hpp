class CfgFunctions {
    class A4A {
        tag = "A4A";

        class Bootstrap {
            file = "A4A\functions\bootstrap";
            class preInit { preInit = 1; };
            class serverInit {};
            class clientInit {};
            class registerConfiguredArsenals {};
        };

        class Server {
            file = "A4A\functions\server";
            class requestOpen {};
            class requestClose {};
            class requestWithdraw {};
            class completeWithdraw {};
            class requestReturn {};
            class completeReturn {};
            class expireTransactions {};
            class validateSnapshot {};
            class loadPersistence {};
            class schedulePersistence {};
            class saveEditorSnapshot {};
        };

        class Client {
            file = "A4A\functions\client";
            class openAction {};
            class receiveOpen {};
            class receiveInvalidate {};
            class receiveGrant {};
            class receiveTransactionResult {};
            class addCargoActions {};
        };

        class Cargo {
            file = "A4A\functions\cargo";
            class snapshotCargo {};
            class restoreCargo {};
            class requestCargoDeposit {};
            class requestCargoWithdraw {};
        };

        class Adapters {
            file = "A4A\functions\adapters";
            class initCbaSettings {};
            class openAceProxy {};
            class closeAceProxy {};
        };

        class Shared {
            file = "A4A\functions\shared";
            class getSetting {};
            class itemTypeCached {};
            class resolveRemotePlayer {};
            class validateActiveSession {};
            class publishSnapshot {};
            class beginClientOperation {};
            class flushClientBatch {};
            class canEdit {};
        };
    };

    class JN {
        tag = "JN";

        class Common {
            file = "A4A\Common";
            class common_addActionSelect {};
            class common_addActionCancel {};
            class common_updateActionCancel {};
            class common_removeActionCancel {};
            class common_getActionCanceled {};
        };

        class Common_Array {
            file = "A4A\Common\Array";
            class common_array_add {};
            class common_array_remove {};
        };

        class JNA {
            file = "A4A\JNA";
            class arsenal {};
            class arsenal_addItem {};
            class arsenal_addToArray {};
            class arsenal_cargoToArray {};
            class arsenal_handleAction {};
            class arsenal_inList {};
            class arsenal_itemCount {};
            class arsenal_itemType {};
            class arsenal_loadInventory {};
            class arsenal_removeFromArray {};
            class arsenal_removeItem {};
            class arsenal_aceStock { postInit = 1; };
        };
    };
};
