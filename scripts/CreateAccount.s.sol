pragma solidity ^0.8.0;

import "src/factory/ECDSAKernelFactory.sol";
import "src/factory/EIP1967Proxy.sol";
import "forge-std/Script.sol";
import "forge-std/console.sol";

contract CreateAccount is Script {
    function run() public {
        uint256 key = vm.envUint("DEPLOYER_PRIVATE_KEY");
        vm.startBroadcast(key);

        ECDSAKernelFactory kernelFactory = ECDSAKernelFactory(0x3d3080e19ed99050307153C3174D5D451fb9Db49);
        address owner = vm.addr(key);
        console.log("Owner: %s", owner);
        uint256 index = 0;
        EIP1967Proxy proxy = kernelFactory.createAccount(owner, index);
        console.log("Account created at: %s", address(proxy));
        vm.stopBroadcast();
    }
}

//BatchActions.sol executor = 0xF3F98574AC89220B5ae422306dC38b947901b421
//ECDSAKernelFactory = 0x3d3080e19ed99050307153C3174D5D451fb9Db49
