pragma solidity ^0.8.0;

import "src/subscriptions/Initiator.sol";
import "forge-std/Script.sol";
import "forge-std/console.sol";

contract DeployInitiator is Script {
    address internal constant DETERMINISTIC_CREATE2_FACTORY = 0x7A0D94F55792C434d74a40883C6ed8545E406D12;

    function run() public {
        uint256 key = vm.envUint("DEPLOYER_PRIVATE_KEY");
        vm.startBroadcast(key);
        bytes memory bytecode = type(Initiator).creationCode;
        bool success;
        bytes memory returnData;
        (success, returnData) = DETERMINISTIC_CREATE2_FACTORY.call(abi.encodePacked(bytecode));
        require(success, "Failed to deploy Initiator");
        address initiator = address(bytes20(returnData));
        console.log("Initiator deployed at: %s", initiator);
    }
}

//0x422b17556e4745c370968905B2Ba1e500822FBd0