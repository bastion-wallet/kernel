// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "../utils/Exec.sol";

contract BatchActions {
    function executeBatch(address[] calldata to, uint256[] calldata value, bytes[] calldata data, Operation operation)
        external
    {
        require(to.length == value.length && to.length == data.length, "Array lengths do not match");
        for(uint i = 0; i < to.length; i++) {
            require(to[i] != address(0), "Invalid address in 'to' array");
        }

        for (uint256 i = 0; i < to.length; i++) {
            if (operation == Operation.Call) {
                (bool success, bytes memory ret) = Exec.call(to[i], value[i], data[i]);
                if (!success) {
                    assembly {
                        revert(add(ret, 32), mload(ret))
                    }
                }
            } else {
                (bool success, bytes memory ret) = Exec.delegateCall(to[i], data[i]);
                if (!success) {
                    assembly {
                        revert(add(ret, 32), mload(ret))
                    }
                }
            }
        }
    }

    function approveAndTransfer20Batch(address[] memory tokenAddress, uint256[] memory amount, address[] memory to)
        external
    {
        for (uint256 i = 0; i < tokenAddress.length; i++) {
            IERC20(tokenAddress[i]).approve(to[i], amount[i]);
            IERC20(tokenAddress[i]).transfer(to[i], amount[i]);
        }
    }
}
