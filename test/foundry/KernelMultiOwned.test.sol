// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "src/factory/KernelFactory.sol";
import "src/factory/TempKernel.sol";
import "src/factory/MultiECDSAKernelFactory.sol";
import "src/Kernel.sol";
import "src/validator/MultiECDSAValidator.sol";
import "src/factory/EIP1967Proxy.sol";
// test artifacts
import "src/test/TestValidator.sol";
// test utils
import "forge-std/Test.sol";
import {ERC4337Utils} from "./ERC4337Utils.sol";

using ERC4337Utils for EntryPoint;

contract KernelTest is Test {
    Kernel kernel;
    KernelFactory factory;
    MultiECDSAKernelFactory ecdsaFactory;
    EntryPoint entryPoint;
    MultiECDSAValidator validator;
    address owner;
    uint256 ownerKey;
    address owner2;
    uint256 owner2Key;
    address owner3;
    uint256 owner3Key;
    address newSignatory;
    uint256 newSignatoryKey;
    address payable beneficiary;

    function setUp() public {
        (owner, ownerKey) = makeAddrAndKey("owner");
        (owner2, owner2Key) = makeAddrAndKey("owner2");
        (owner3, owner3Key) = makeAddrAndKey("owner3");
        (newSignatory, newSignatoryKey) = makeAddrAndKey("newSignatory");
        entryPoint = new EntryPoint();
        factory = new KernelFactory(entryPoint);

        validator = new MultiECDSAValidator();
        address[] memory owners = new address[](3);
        owners[0]=owner;
        owners[1]=owner2;
        owners[2]=owner3;

        ecdsaFactory = new MultiECDSAKernelFactory(factory, validator, entryPoint, owners);
        
        vm.prank(owner);
        ecdsaFactory.approveChange();
        
        vm.prank(owner2);
        ecdsaFactory.approveChange();

        vm.prank(owner);
        ecdsaFactory.setOwners(owners);

        kernel = Kernel(payable(ecdsaFactory.createAccount(0)));
        vm.deal(address(kernel), 1e30);
        beneficiary = payable(address(makeAddr("beneficiary")));
    }

    function test_initialize_twice() external {
        vm.expectRevert();
        kernel.initialize(validator, abi.encodePacked(owner));
    }

    function test_add_signatory() external {
        ecdsaFactory.addSignatory(newSignatory);
        assertEq(ecdsaFactory.isSignatory(newSignatory), true);
        assertEq(ecdsaFactory.numSignatories(), 4);
    }

    function test_remove_signatory() external {
        ecdsaFactory.addSignatory(newSignatory);
        assertEq(ecdsaFactory.numSignatories(), 4);

        ecdsaFactory.removeSignatory(newSignatory);
        assertEq(ecdsaFactory.isSignatory(newSignatory), false);
        assertEq(ecdsaFactory.numSignatories(), 3);
    }

    function test_approve_change() external {
        vm.prank(owner);
        ecdsaFactory.approveChange();
        assertEq(ecdsaFactory.approvals(owner), true);
        assertEq(ecdsaFactory.numApprovals(), 1);

        vm.prank(owner2);
        ecdsaFactory.approveChange();
        assertEq(ecdsaFactory.approvals(owner2), true);
        assertEq(ecdsaFactory.numApprovals(), 2);
    }

    function test_revoke_approval() external {
        vm.prank(owner);
        ecdsaFactory.approveChange();
        vm.prank(owner2);
        ecdsaFactory.approveChange();
        assertEq(ecdsaFactory.numApprovals(), 2);

        vm.prank(owner);
        ecdsaFactory.revokeApproval();
        assertEq(ecdsaFactory.numApprovals(), 1);
        vm.prank(owner2);
        ecdsaFactory.revokeApproval();
        assertEq(ecdsaFactory.numApprovals(), 0);

    }

    function test_set_owners() external {
        address[] memory newOwners = new address[](2);
        newOwners[0]=owner;
        newOwners[1]=owner2;
        vm.expectRevert();
        ecdsaFactory.setOwners(newOwners);

        vm.prank(owner2);
        ecdsaFactory.approveChange();
        vm.prank(owner3);
        ecdsaFactory.approveChange();
        vm.prank(owner2);
        ecdsaFactory.setOwners(newOwners);
    }


    function test_validate_signature() external {
        Kernel kernel2 = Kernel(payable(address(ecdsaFactory.createAccount(1))));
        bytes32 hash = keccak256(abi.encodePacked("hello world"));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerKey, hash);
        assertEq(kernel2.isValidSignature(hash, abi.encodePacked(r, s, v)), Kernel.isValidSignature.selector);
    }

    function test_set_default_validator() external {
        TestValidator newValidator = new TestValidator();
        bytes memory empty;
        UserOperation memory op = entryPoint.fillUserOp(
            address(kernel),
            abi.encodeWithSelector(KernelStorage.setDefaultValidator.selector, address(newValidator), empty)
        );
        op.signature = abi.encodePacked(bytes4(0x00000000), entryPoint.signUserOpHash(vm, ownerKey, op));
        UserOperation[] memory ops = new UserOperation[](1);
        ops[0] = op;
        entryPoint.handleOps(ops, beneficiary);
        assertEq(address(KernelStorage(address(kernel)).getDefaultValidator()), address(newValidator));
    }

    function test_disable_mode() external {
        bytes memory empty;
        UserOperation memory op = entryPoint.fillUserOp(
            address(kernel),
            abi.encodeWithSelector(KernelStorage.disableMode.selector, bytes4(0x00000001), address(0), empty)
        );
        op.signature = abi.encodePacked(bytes4(0x00000000), entryPoint.signUserOpHash(vm, ownerKey, op));
        UserOperation[] memory ops = new UserOperation[](1);
        ops[0] = op;
        entryPoint.handleOps(ops, beneficiary);
        assertEq(uint256(bytes32(KernelStorage(address(kernel)).getDisabledMode())), 1 << 224);
    }

    function test_set_execution() external {
        console.log("owner", owner);
        TestValidator newValidator = new TestValidator();
        UserOperation memory op = entryPoint.fillUserOp(
            address(kernel),
            abi.encodeWithSelector(
                KernelStorage.setExecution.selector,
                bytes4(0xdeadbeef),
                address(0xdead),
                address(newValidator),
                uint48(0),
                uint48(0),
                bytes("")
            )
        );
        op.signature = abi.encodePacked(bytes4(0x00000000), entryPoint.signUserOpHash(vm, ownerKey, op));
        UserOperation[] memory ops = new UserOperation[](1);
        ops[0] = op;
        entryPoint.handleOps(ops, beneficiary);
        ExecutionDetail memory execution = KernelStorage(address(kernel)).getExecution(bytes4(0xdeadbeef));
        assertEq(execution.executor, address(0xdead));
        assertEq(address(execution.validator), address(newValidator));
        assertEq(uint256(execution.validUntil), uint256(0));
        assertEq(uint256(execution.validAfter), uint256(0));
    }

    function test_callcode() external {
        CallCodeTester t = new CallCodeTester();
        address(t).call{value: 1e18}("");
        Target target = new Target();
        t.callcodeTest(address(target));
        console.log("target balance", address(target).balance);
        console.log("t balance", address(t).balance);
        console.log("t slot1", t.slot1());
        console.log("t slot2", t.slot2());
    }
}

contract CallCodeTester {
    uint256 public slot1;
    uint256 public slot2;
    receive() external payable {
    }
    function callcodeTest(address _target) external {
        bool success;
        bytes memory ret;
        uint256 b = address(this).balance / 1000;
        bytes memory data;
        assembly {
            let result := callcode(gas(), _target, b, add(data, 0x20), mload(data), 0, 0)
            // Load free memory location
            let ptr := mload(0x40)
            // We allocate memory for the return data by setting the free memory location to
            // current free memory location + data size + 32 bytes for data size value
            mstore(0x40, add(ptr, add(returndatasize(), 0x20)))
            // Store the size
            mstore(ptr, returndatasize())
            // Store the data
            returndatacopy(add(ptr, 0x20), 0, returndatasize())
            // Point the return data to the correct memory location
            ret := ptr
            success := result
        }
        require(success, "callcode failed");
    }
}

contract Target {
    uint256 public count;
    uint256 public amount;
    fallback() external payable {
        count++;
        amount += msg.value; 
    }
}
