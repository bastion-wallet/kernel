pragma solidity ^0.8.0;

import "src/paymaster/VerifyingPaymaster.sol";
import "src/paymaster/MetaPaymaster.sol";
import "forge-std/Script.sol";
import "forge-std/console.sol";

contract DeployPaymaster is Script {

    function run() public {
        uint256 key = vm.envUint("DEPLOYER_PRIVATE_KEY");
        vm.startBroadcast(key);

        //mainnet
        Paymaster paymaster =  Paymaster(payable(0xb45d849340174B9363E0E435102F0eCecedcd9f1));

        paymaster.withdrawTo(payable(0x2429EB38cB9b456160937e11aefc80879a2d2712), 9998499493601388);

    }
}
