// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <=0.8.19;

contract TestExecutor {
    event TestExecutorDoNothing();

    function doNothing() external {
        // do nothing
        emit TestExecutorDoNothing();
    }
}
