pragma solidity ^0.8.0;

import "src/paymaster/MetaPaymaster.sol";
import "forge-std/Script.sol";
import "forge-std/console.sol";

contract DeployMetaPaymaster is Script {

    function run() public {
        uint256 key = vm.envUint("DEPLOYER_PRIVATE_KEY");
        vm.startBroadcast(key);

        // MetaPaymaster metaPaymaster = new MetaPaymaster();
        // console.log("metaPaymaster deployed at: %s", address(metaPaymaster));

        MetaPaymaster metaPaymaster = new MetaPaymaster(IEntryPoint(0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789),0x2429EB38cB9b456160937e11aefc80879a2d2712);
        console.log("metaPaymaster deployed at: %s", address(metaPaymaster));

        // MetaPaymaster metaPaymaster = MetaPaymaster(0x6F09c991431416f88a7F3B59a42306737575C364);
        // metaPaymaster.depositTo(0x175f178512bE40b2e2D78960751792046cec90a3);


    }
}
