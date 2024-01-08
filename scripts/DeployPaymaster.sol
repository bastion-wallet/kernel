pragma solidity ^0.8.0;

// import "src/paymaster/VerifyingPaymaster.sol";
import "src/MetaPaymaster/FundedPaymaster.sol";
// import "src/paymaster/MetaPaymaster.sol";
import "forge-std/Script.sol";
import "forge-std/console.sol";

contract DeployPaymaster is Script {

    function run() public {
        uint256 key = vm.envUint("DEPLOYER_PRIVATE_KEY");
        vm.startBroadcast(key);

        // testnet
        // Paymaster paymaster = 
        // new Paymaster(IEntryPoint(0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789), 0x136A971d2F3aa5076F26f2952375EF5a44e29Ec4, MetaPaymaster(payable(0x5D2d03cE31975A745Ff6d0579d5c29AA6dD777F3)));
        // console.log("VerifyingPaymaster deployed at: %s", address(paymaster));

        // FundedPaymaster fundedPaymaster = 
        // new FundedPaymaster(IEntryPoint(0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789), MetaPaymaster(payable(0xED17e7e23067d2aB9C8D50B6346eB6E859d4D2AF)),0x136A971d2F3aa5076F26f2952375EF5a44e29Ec4);
        // console.log("FundedPaymaster deployed at: %s", address(fundedPaymaster));
      
        //mainnet
        // Paymaster paymaster = 
        // new Paymaster(IEntryPoint(0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789), 0x136A971d2F3aa5076F26f2952375EF5a44e29Ec4, MetaPaymaster(payable(0x75B9328BB753144705b77b215E304eC7ef45235C)));
        // address verifyingPaymaster = address(paymaster);
        // console.log("VerifyingPaymaster deployed at: %s", verifyingPaymaster);


        FundedPaymaster fundedPaymaster = 
        new FundedPaymaster(IEntryPoint(0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789), MetaPaymaster(payable(0x75B9328BB753144705b77b215E304eC7ef45235C)),0x136A971d2F3aa5076F26f2952375EF5a44e29Ec4);
        console.log("FundedPaymaster deployed at: %s", address(fundedPaymaster));

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

//forge script scripts/DeployMetapaymaster.s.sol --chain-id 84531 --broadcast --rpc-url https://base-goerli.g.alchemy.com/v2/glLz9wPYnslhkdN-3iM21HPRnRIykOFE --etherscan-api-key ZBZ1S7RRTEWK47U1TVG28PWFVI2JCJJ59V
// forge script scripts/DeployPaymaster.sol --chain-id 8453 --broadcast --rpc-url https://base.blockpi.network/v1/rpc/public --etherscan-api-key ZBZ1S7RRTEWK47U1TVG28PWFVI2JCJJ59V  