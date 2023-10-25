// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0 <=0.8.19;

contract TestCounter {
    uint256 public counter;

    function increment() public {
        counter += 1;
    }
}
