// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import "../interfaces/ISubExecutor.sol";

contract Initiator is Ownable, ReentrancyGuard {
    IERC20 public paymentToken;

    constructor(address _paymentToken) {
        paymentToken = IERC20(_paymentToken);
    }

    mapping(address => ISubExecutor.SubStorage) public subscriptions;

    // Function that calls processPayment from sub executor and initiates a payment
    function initiatePayment() public nonReentrant {
        ISubExecutor.SubStorage storage sub = subscriptions[msg.sender];
        require(sub.validUntil > block.timestamp, "Subscription is not active");
        require(sub.validAfter < block.timestamp, "Subscription is not active");
        require(sub.amount > 0, "Subscription amount is 0");
        require(sub.payee != address(0), "Payee is not set");
        require(sub.paymentInterval > 0, "Payment interval is 0");
        require(sub.paymentLimit > 0, "Payment limit is 0");
        require(sub.erc20TokensValid, "ERC20 tokens are not valid");

        uint256 paymentAmount = sub.amount;
        if (sub.paymentLimit < paymentAmount) {
            paymentAmount = sub.paymentLimit;
        }

        paymentToken.transferFrom(msg.sender, sub.payee, paymentAmount);
        sub.paymentLimit -= paymentAmount;
        sub.validUntil += sub.paymentInterval;
    }
}
