pragma solidity ^0.8.0;

import "src/paymaster/VerifyingPaymaster.sol";
import "src/paymaster/MetaPaymaster.sol";
import "forge-std/Script.sol";
import "forge-std/console.sol";
import "account-abstraction/core/EntryPoint.sol";

contract DeployPaymaster is Script {
    address internal constant DETERMINISTIC_CREATE2_FACTORY = 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789;

    function run() public {
        uint256 key = vm.envUint("DEPLOYER_PRIVATE_KEY");
        vm.startBroadcast(key);

        EntryPoint entryPoint = new EntryPoint();
        address entryPointAddress = address(entryPoint);
        console.log("entryPointAddress deployed at: %s", entryPointAddress);

        Paymaster paymaster = new Paymaster(IEntryPoint(entryPointAddress), 0xB89655D499A6EbD9a33C159697EFDa91d7A10433, MetaPaymaster(payable(0xe4d2db385a32C7A61E11e921A6238afA2D3EB2f1)));
        address verifyingPaymaster = address(paymaster);
        console.log("VerifyingPaymaster deployed at: %s", verifyingPaymaster);

        // Paymaster paymaster = Paymaster(payable(0x6B7d1c9d519DFc3A5D8D1B7c15d4E5bbe8DdE1cF));

        UserOperation memory userOp = UserOperation(
            0xCBC26AfD7eF9cfA3f843d08Ec58a32De59bdeDB7, 
            0x00, 
            "0x",
            "0x51945447000000000000000000000000b390e253e43171a11a6afcb04e340fde5ae1b0a1000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000800000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002440d097c3000000000000000000000000",
            0x2dc6c0,
            0x2dc6c0,
            0x2dc6c0,
            0x0f43a3, 
            0x0f43a3, 
            "0x96bc93963963f91b10937f28b435929ce0c56af60000000000000000000000000000000000000000000000000000000070dbd8800000000000000000000000000000000000000000000000000000000065851de0ebb4a3d675da8c4d25b9b16326c463186d5590b8c9dcffcb78e2c8bedc3704b0038a3b29099b1d15861c199d2082cde8f9a4b68c889087e8c3d5a6b2782b5b4b1c",
            "0x000000007d88841a8e6d6081e917ac1a4a2ab75d34cc0a26a7fe5816d35bec925ed12cc92b574c49630ddce7c298bcecefd982908d72d9a6f73b329fdff8c0fd9c0806931b"
        );
        // bytes32 userOpHash = 0xe2788fe904e89ab840bf17a4dbd11efb4273484d27e694b5ce9fcc1b0876f556;
        // paymaster.testValidatePaymasterUserOp(userOp, userOpHash, 10000000000000);
        // // paymaster.testParsePaymasterAndData("0x96bc93963963f91b10937f28b435929ce0c56af6000070dbd88000006580923e568794702bbb871e11e3947c5738e9bc472ba9aa1c6fa9e02c3087b33704a2267a9c4514adbef2004b2c333ebf5f1837138a4dd76c096d0fe44f1783269db92e1c");
        address a = paymaster.verifyingSigner();
        console.log("a %s",a);
        bytes memory pd = hex"96bc93963963f91b10937f28b435929ce0c56af60000000000000000000000000000000000000000000000000000000070dbd8800000000000000000000000000000000000000000000000000000000065851de0ebb4a3d675da8c4d25b9b16326c463186d5590b8c9dcffcb78e2c8bedc3704b0038a3b29099b1d15861c199d2082cde8f9a4b68c889087e8c3d5a6b2782b5b4b1c";
        (uint48 validUntil, uint48 validAfter, bytes memory signature) = paymaster.testParsePaymasterAndData(pd);
        console.log("%s %s",validUntil,validAfter);

        paymaster.testHashSignature(0x69d0be2a76c5fc9ad86d71ca78405bf6360f9f7edede8ec183c94a69ae59654e, hex"8ff7a87b8292b194b8e702bd858f93114e3eaf3e452e8f6f7a4568ce694a539f0a54b20ce389695c947c467da613f57cd8df9f9794c13c762e0ee65db7b2be4e1b");
    }
}
