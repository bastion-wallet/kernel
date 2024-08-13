// SPDX-License-Identifier: MIT
pragma solidity >=0.8.9;

interface ISubscriptionModule {

    event SubscriptionCreated(address indexed _subscriber, address indexed _initiator,  uint256 _amount);
    event SubscriptionModified(address indexed _subscriber, address indexed _initiator, uint256 _amount);
    event PreApproved(address indexed _subscriber, uint256 _amount);
    event RevokedApproval(address indexed _subscriber);
    event PaymentProcessed(address indexed _subscriber, uint256 _amount);
    event InitiatorRegistered(address indexed _initiator, address indexed _creator);

    struct Subscription {
        uint256 amount;
        uint256 validUntil;
        uint256 validAfter;
        uint256 paymentInterval; // In days
        address subscriber;
        address initiator;
        bool erc20TokensValid;
        address erc20Token;
    }

    struct PaymentRecord {
        uint256 amount;
        uint256 timestamp;
        address payee;
    }

    // function preApprove(
    //     address _payee,
    //     uint256 _amount,
    //     uint256 _paymentInterval,
    //     uint256 _paymentLimit,
    //     address _erc20TokenAddress
    // ) external;

    function registerInitiator() external;

    function createSubscription(
        address _initiator,
        uint256 _amount,
        uint256 _interval, // in seconds
        uint256 _validUntil, //timestamp
        uint256 _paymentLimit,
        address _erc20Token
    ) external;

    function modifySubscription(
        address _initiator,
        uint256 _amount,
        uint256 _interval,
        uint256 _validUntil,
        uint256 _paymentLimit,
        address _erc20Token
    ) external;

    function revokeSubscription(address _initiator) external;

    function processPayment(Subscription memory sub) external;
}
