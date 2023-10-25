// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <=0.8.19;

contract EIP1967Proxy {
    /**
     * @dev Storage slot with the address of the current implementation.
     * This is the keccak-256 hash of "eip1967.proxy.implementation" subtracted by 1, and is
     * validated in the constructor.
     */
    bytes32 internal constant _IMPLEMENTATION_SLOT = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
    
    /**
     * @dev An upgrade function sees `msg.value > 0` that may be lost.
     */
    error ERC1967NonPayable();
    
    constructor(address _logic, bytes memory _data) payable {
        require(_logic != address(0), "EIP1967Proxy: implementation is the zero address");
        require(_logic.code.length > 0, "EIP1967Proxy: implementation is the EOA");
        bytes32 slot = _IMPLEMENTATION_SLOT;
        assembly {
            sstore(slot, _logic)
        }
        if (_data.length > 0) {
            (bool success,) = _logic.delegatecall(_data);
            require(success, "EIP1967Proxy: constructor call failed");
        } else {
            _checkNonPayable();
        }
    }

    fallback() external payable {
        address implementation = _implementation();
        assembly {
            // Copy msg.data. We take full control of memory in this inline assembly
            // block because it will not return to Solidity code. We overwrite the
            // Solidity scratch pad at memory position 0.
            calldatacopy(0, 0, calldatasize())

            // Call the implementation.
            // out and outsize are 0 because we don't know the size yet.
            let result := delegatecall(gas(), implementation, 0, calldatasize(), 0, 0)

            // Copy the returned data.
            returndatacopy(0, 0, returndatasize())

            switch result
            // delegatecall returns 0 on error.
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }

    function _implementation() internal view returns (address impl) {
        bytes32 slot = _IMPLEMENTATION_SLOT;
        assembly {
            impl := sload(slot)
        }
    }

    /**
     * @dev Reverts if `msg.value` is not zero. It can be used to avoid `msg.value` stuck in the contract
     * if an upgrade doesn't perform an initialization call.
     */
    function _checkNonPayable() private {
        if (msg.value > 0) {
            revert ERC1967NonPayable();
        }
    }
    
}
