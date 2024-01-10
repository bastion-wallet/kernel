// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import "../interfaces/ISubExecutor.sol";

contract Initiator is Ownable, ReentrancyGuard {
    // TODO - return active/inactive subscriptions
    mapping(address => ISubExecutor.SubStorage[]) public subscriptionsBySubscriber;
    address[] public subscribers;

    function registerSubscription(
        address _subscriber,
        uint256 _amount,
        uint256 _paymentInterval,
        uint256 _paymentLimit,
        address _erc20Token
    ) public {
        require(_amount > 0, "Subscription amount is 0");
        require(_paymentInterval > 0, "Payment interval is 0");
        require(_paymentLimit > 0, "Payment limit is 0");
        require(msg.sender == _subscriber, "Only the subscriber can register a subscription");

        ISubExecutor.SubStorage memory sub = ISubExecutor.SubStorage({
            amount: _amount,
            validUntil: block.timestamp + _paymentInterval,
            validAfter: block.timestamp,
            paymentInterval: _paymentInterval,
            paymentLimit: _paymentLimit,
            subscriber: _subscriber,
            initiator: address(this),
            erc20TokensValid: _erc20Token == address(0) ? false : true,
            erc20Token: _erc20Token
        });
        subscriptionsBySubscriber[_subscriber].push(sub);
    }

    function removeSubscription(address _subscriber) public {
        require(msg.sender == _subscriber, "Only the subscriber can remove a subscription");
        ISubExecutor.SubStorage[] storage subscriptions = subscriptionsBySubscriber[_subscriber];
        for (uint256 i = 0; i < subscriptions.length; i++) {
            if (subscriptions[i].subscriber == _subscriber) {
                delete subscriptions[i];
            }
        }
    }

    function getSubscriptions(address _subscriber) public view returns (ISubExecutor.SubStorage[] memory) {
        ISubExecutor.SubStorage[] memory subscriptions = subscriptionsBySubscriber[_subscriber];
        return subscriptions;
    }

    // Function that calls processPayment from sub executor and initiates a payment
    function initiatePayment() public nonReentrant {
        for (uint256 i = 0; i < subscribers.length; i++) {
            ISubExecutor.SubStorage[] storage subscriptions = subscriptionsBySubscriber[subscribers[i]];
            require(subscriptions[i].validUntil > block.timestamp, "Subscription is not active");
            require(subscriptions[i].validAfter < block.timestamp, "Subscription is not active");
            require(subscriptions[i].amount > 0, "Subscription amount is 0");
            require(subscriptions[i].paymentInterval > 0, "Payment interval is 0");
            require(subscriptions[i].paymentLimit > 0, "Payment limit is 0");
            require(subscriptions[i].erc20TokensValid, "ERC20 tokens are not valid");

            // uint256 paymentAmount = subscriptions[i].amount;
            // Not yet sure how to apply the payment limit
            // if (subscriptions[i].paymentLimit < paymentAmount) {
            //     paymentAmount = subscriptions[i].paymentLimit;
            // }

            uint256 lastPaid = ISubExecutor(subscriptions[i].subscriber).getLastPaidTimestamp(address(this));
            require(lastPaid + subscriptions[i].paymentInterval > block.timestamp, "Payment interval not yet reached");

            ISubExecutor(subscriptions[i].subscriber).processPayment();
            // subscriptions[i].paymentLimit -= paymentAmount;
        }
    }
}
