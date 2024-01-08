// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

interface IAddressBook {
    function getOwners() external view returns(address[] memory);
}
