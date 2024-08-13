pragma solidity ^0.8.0;

import "src/modules/SubscriptionModule.sol";
import "src/modules/Initiator.sol";
import "forge-std/Script.sol";
import "forge-std/console.sol";

contract DeploySubscriptionModule is Script {
    address internal constant DETERMINISTIC_CREATE2_FACTORY = 0x7A0D94F55792C434d74a40883C6ed8545E406D12;
    address internal constant FEE_RECEIVER = 0xB89655D499A6EbD9a33C159697EFDa91d7A10433;

    function run() public {
        uint256 key = vm.envUint("DEPLOYER_PRIVATE_KEY");
        vm.startBroadcast(key);
        bytes memory bytecode = type(SubscriptionModule).creationCode;
        bool success;
        
        // bytes memory returnData;
        // (success, returnData) = DETERMINISTIC_CREATE2_FACTORY.call(abi.encodePacked(bytecode,abi.encode(FEE_RECEIVER)));
        // require(success, "Failed to deploy SubscriptionModule");
        // address subscriptionModule = address(bytes20(returnData));
        // console.log("SubscriptionModule deployed at: %s", subscriptionModule);


        // SubscriptionModule(subscriptionModule).registerInitiator();
        // address initiator =  SubscriptionModule(subscriptionModule).initiators(0);
        // console.log("Initiator deployed at: %s", initiator);




        // to whitelist token
        Initiator initiator = Initiator(payable(0x6F4090bD989717d902e8C43845267EA0EB96397f));
        address owner = initiator.owner();
        console.log("owner: %s", owner);
        initiator.whitelistTokenForPayment(0xd5B713112B1BD3c4fFF38ac710b1cFAe1dd40727);

        vm.stopBroadcast();


        
    }
}

// independent initiator deployment
//address subscriptionModule = 0x2cb3335D681d2C00a5c4eCeEdf0a29635367DAB9;
// bytes memory bytecode2 = type(Initiator).creationCode;
// bool success2;

// bytes memory returnData2;
// (success2, returnData2) = DETERMINISTIC_CREATE2_FACTORY.call(
//     abi.encodePacked(bytecode2, abi.encode(subscriptionModule))
//     );
// require(success2, "Failed to deploy Initiator");
// address initiator = address(bytes20(returnData2));
// console.log("Initiator deployed at: %s", initiator);