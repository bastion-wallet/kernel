pragma solidity ^0.8.0;

import "src/modules/SubscriptionModule.sol";
import "src/modules/Initiator.sol";
import "forge-std/Script.sol";
import "forge-std/console.sol";

contract DeploySampleNFT is Script {
    address internal constant DETERMINISTIC_CREATE2_FACTORY = 0x7A0D94F55792C434d74a40883C6ed8545E406D12;

    function run() public {
        uint256 key = vm.envUint("DEPLOYER_PRIVATE_KEY");
        vm.startBroadcast(key);
        bytes memory bytecode = type(SubscriptionModule).creationCode;
        bool success;
        
        bytes memory returnData;
        (success, returnData) = DETERMINISTIC_CREATE2_FACTORY.call(abi.encodePacked(bytecode));
        require(success, "Failed to deploy SubscriptionModule");
        address subscriptionModule = address(bytes20(returnData));
        console.log("SubscriptionModule deployed at: %s", subscriptionModule);


        bytes memory bytecode2 = type(Initiator).creationCode;
        bool success2;
        
        bytes memory returnData2;
        (success2, returnData2) = DETERMINISTIC_CREATE2_FACTORY.call(
            abi.encodePacked(bytecode2, abi.encode(subscriptionModule))
            );
        require(success2, "Failed to deploy Initiator");
        address initiator = address(bytes20(returnData2));
        console.log("Initiator deployed at: %s", initiator);


        vm.stopBroadcast();


        
    }
}
