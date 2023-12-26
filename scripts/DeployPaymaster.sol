pragma solidity ^0.8.0;

import "src/paymaster/VerifyingPaymaster.sol";
import "src/paymaster/MetaPaymaster.sol";
import "forge-std/Script.sol";
import "forge-std/console.sol";

contract DeployPaymaster is Script {

    function run() public {
        uint256 key = vm.envUint("DEPLOYER_PRIVATE_KEY");
        vm.startBroadcast(key);

        //testnet
        // Paymaster paymaster = 
        // new Paymaster(IEntryPoint(0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789), 0x136A971d2F3aa5076F26f2952375EF5a44e29Ec4, MetaPaymaster(payable(0xe4d2db385a32C7A61E11e921A6238afA2D3EB2f1)));
        //mainnet
        Paymaster paymaster = 
        new Paymaster(IEntryPoint(0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789), 0x136A971d2F3aa5076F26f2952375EF5a44e29Ec4, MetaPaymaster(payable(0x75B9328BB753144705b77b215E304eC7ef45235C)));
        address verifyingPaymaster = address(paymaster);
        console.log("VerifyingPaymaster deployed at: %s", verifyingPaymaster);

        // bytes memory bytecode = type(Paymaster).creationCode;
        // bool success;
        // bytes memory returnData;
        // (success, returnData) = DETERMINISTIC_CREATE2_FACTORY.call(
        //     abi.encodePacked(
        //         bytecode,
        //         abi.encode(
        //             IEntryPoint(0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789),
        //             0xB89655D499A6EbD9a33C159697EFDa91d7A10433,
        //             MetaPaymaster(payable(0xe4d2db385a32C7A61E11e921A6238afA2D3EB2f1))
        //         )
        //     )
        // );
        // require(success, "Failed to deploy VerifyingPaymaster");
        // address verifyingPaymaster = address(bytes20(returnData));
        // console.log("VerifyingPaymaster deployed at: %s", verifyingPaymaster);

    }
}
