// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

interface ISubExecutor {
    event preApproved(address indexed _subscriber, uint256 _amount);
    event revokedApproval(address indexed _subscriber);
    event paymentProcessed(address indexed _subscriber, uint256 _amount);

    struct SubStorage {
        uint256 amount;
        uint256 validUntil;
        uint256 validAfter;
        uint256 paymentInterval; // In days
        uint256 paymentLimit;
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

    function preApprove(
        address _payee,
        uint256 _amount,
        uint256 _paymentInterval,
        uint256 _paymentLimit,
        address erc20TokenAddress
    ) external;

    function createSubscription(address _subscriber, uint256 _amount, uint256 _interval) external;

    function revokeSubscription(address _subscriber, uint256 _amount, uint256 _interval) external;

    function getSubscriptions(address _subscriber) external view returns (SubStorage memory);

    function getPaymentHistory(address _subscriber) external view returns (PaymentRecord[] memory);

    function processPayment() external;

    function withdrawERC20Tokens(address _tokenAddress) external;

    function getLastPaidTimestamp(address _initiator) external view returns (uint256);
}
