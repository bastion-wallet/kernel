// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "src/factory/KernelFactory.sol";
import "src/factory/ECDSAKernelFactory.sol";
import "src/Kernel.sol";
import "src/validator/ECDSAValidator.sol";
import "src/executor/BatchActions.sol";
import "src/utils/Exec.sol";
import "src/factory/EIP1967Proxy.sol";
// test artifacts
import "src/test/TestValidator.sol";
import "src/test/TestERC721.sol";
// test utils
import "forge-std/Test.sol";
import "forge-std/console.sol";

import {ERC4337Utils} from "./ERC4337Utils.sol";

using ERC4337Utils for EntryPoint;

contract KernelTest is Test {
    Kernel kernel;
    KernelFactory factory;
    ECDSAKernelFactory ecdsaFactory;
    EntryPoint entryPoint;
    ECDSAValidator validator;
    BatchActions batchActions;
    address owner;
    uint256 ownerKey;
    address newOwner;
    uint256 newOwnerKey;
    address payable beneficiary;

    function setUp() public {
        (owner, ownerKey) = makeAddrAndKey("owner");
        (newOwner, newOwnerKey) = makeAddrAndKey("newOwner");
        entryPoint = new EntryPoint();
        factory = new KernelFactory(entryPoint);

        validator = new ECDSAValidator();
        ecdsaFactory = new ECDSAKernelFactory(factory, validator, entryPoint);
        batchActions = new BatchActions();
        kernel = Kernel(payable(ecdsaFactory.createAccount(owner, 0)));
        vm.deal(address(kernel), 1e30);
        beneficiary = payable(address(makeAddr("beneficiary")));

        uint48 _validAfter = uint48(block.timestamp);
        vm.prank(owner);
        kernel.setExecution(
            bytes4(0xa4c79eee),
            address(batchActions),
            validator,
            1893456000,
            _validAfter,
            abi.encodePacked(owner)
        );
    }

    function test_initialize_twice() external {
        vm.expectRevert();
        kernel.initialize(validator, abi.encodePacked(owner));
    }

    function test_initialize() public {
        Kernel newKernel = Kernel(
            payable(
                address(
                    new EIP1967Proxy(
                        address(factory.nextTemplate()),
                        abi.encodeWithSelector(
                            KernelStorage.initialize.selector,
                            validator,
                            abi.encodePacked(owner)
                        )
                    )
                )
            )
        );
        ECDSAValidatorStorage memory storage_ = ECDSAValidatorStorage(
            validator.ecdsaValidatorStorage(address(newKernel))
        );
        assertEq(storage_.owner, owner);
    }

    function test_erc721_receive() external {
        Kernel kernel2 = Kernel(
            payable(address(ecdsaFactory.createAccount(owner, 1)))
        );
        TestERC721 nft = new TestERC721();
        nft.safeMint(address(kernel2), 1);
        assertEq(nft.ownerOf(1), address(kernel2));
    }

    function test_validate_signature() external {
        Kernel kernel2 = Kernel(
            payable(address(ecdsaFactory.createAccount(owner, 1)))
        );
        bytes32 hash = keccak256(abi.encodePacked("hello world"));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(ownerKey, hash);
        assertEq(
            kernel2.isValidSignature(hash, abi.encodePacked(r, s, v)),
            Kernel.isValidSignature.selector
        );
    }

    function test_set_default_validator() external {
        address oldValidator = address(
            KernelStorage(address(kernel)).getDefaultValidator()
        );
        console.log("oldValidator", oldValidator);
        console.log(
            ECDSAValidatorStorage(
                validator.ecdsaValidatorStorage(address(kernel))
            ).owner
        );
        TestValidator newValidator = new TestValidator();
        bytes memory empty;
        UserOperation memory op = entryPoint.fillUserOp(
            address(kernel),
            abi.encodeWithSelector(
                KernelStorage.setDefaultValidator.selector,
                address(newValidator),
                empty
            )
        );
        op.signature = abi.encodePacked(
            bytes4(0x00000000),
            entryPoint.signUserOpHash(vm, ownerKey, op)
        );
        UserOperation[] memory ops = new UserOperation[](1);
        ops[0] = op;
        entryPoint.handleOps(ops, beneficiary);
        assertEq(
            address(KernelStorage(address(kernel)).getDefaultValidator()),
            address(newValidator)
        );

        // console.log(
        //     ECDSAValidatorStorage(validator.ecdsaValidatorStorage(address(kernel))).owner
        // );
    }

    function test_disable_mode() external {
        bytes memory empty;
        UserOperation memory op = entryPoint.fillUserOp(
            address(kernel),
            abi.encodeWithSelector(
                KernelStorage.disableMode.selector,
                bytes4(0x00000001),
                address(0),
                empty
            )
        );
        op.signature = abi.encodePacked(
            bytes4(0x00000000),
            entryPoint.signUserOpHash(vm, ownerKey, op)
        );
        UserOperation[] memory ops = new UserOperation[](1);
        ops[0] = op;
        entryPoint.handleOps(ops, beneficiary);
        assertEq(
            uint256(bytes32(KernelStorage(address(kernel)).getDisabledMode())),
            1 << 224
        );
    }

    function test_set_owner() external {
        Kernel kernel2 = Kernel(
            payable(address(ecdsaFactory.createAccount(owner, 1)))
        );
        console.log("newOwner", newOwner);
        vm.prank(owner);
        kernel2.setOwner(newOwner);
        address _newOwner = kernel2.getOwner();
        assertEq(_newOwner, newOwner);
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
        op.signature = abi.encodePacked(
            bytes4(0x00000000),
            entryPoint.signUserOpHash(vm, ownerKey, op)
        );
        UserOperation[] memory ops = new UserOperation[](1);
        ops[0] = op;
        entryPoint.handleOps(ops, beneficiary);
        ExecutionDetail memory execution = KernelStorage(address(kernel))
            .getExecution(bytes4(0xdeadbeef));
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

    function test_set_execution_batch_actions() external {
        // uint48 _validAfter = uint48(block.timestamp);
        // vm.prank(owner);
        // kernel.setExecution(bytes4(0xa4c79eee), address(batchActions), validator, 1893456000, _validAfter, abi.encodePacked(owner));

        ExecutionDetail memory execution = KernelStorage(address(kernel))
            .getExecution(bytes4(0xa4c79eee));
        assertEq(execution.executor, address(batchActions));
        console.log("validUntil", execution.validUntil);
        assertEq(uint256(execution.validUntil), uint256(1893456000));

        TestERC721 nft = new TestERC721();

        bytes memory data0 = abi.encodeWithSelector(
            TestERC721.safeMint.selector,
            address(kernel),
            uint256(1)
        );
        bytes memory data1 = abi.encodeWithSelector(
            TestERC721.safeMint.selector,
            address(kernel),
            uint256(2)
        );

        UserOperation memory op = entryPoint.fillUserOp(
            address(kernel),
            abi.encodeWithSelector(
                BatchActions.executeBatch.selector,
                [address(nft), address(nft)],
                [uint256(0), uint256(0)],
                [data0, data1],
                Operation.DelegateCall
            )
        );
        op.signature = abi.encodePacked(
            bytes4(0x00000000),
            entryPoint.signUserOpHash(vm, ownerKey, op)
        );
        UserOperation[] memory ops = new UserOperation[](1);
        ops[0] = op;
        entryPoint.handleOps(ops, beneficiary);
        console.log("balanceee", nft.balanceOf(address(kernel)));
        // assertEq(nft.ownerOf(1), address(owner));
        // assertEq(nft.ownerOf(2), address(owner));
    }
}

contract CallCodeTester {
    uint256 public slot1;
    uint256 public slot2;

    receive() external payable {}

    function callcodeTest(address _target) external {
        bool success;
        bytes memory ret;
        uint256 b = address(this).balance / 1000;
        bytes memory data;
        assembly {
            let result := callcode(
                gas(),
                _target,
                b,
                add(data, 0x20),
                mload(data),
                0,
                0
            )
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
