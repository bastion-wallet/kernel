// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import "../interfaces/ISubExecutor.sol";
import "../interfaces/IInitiator.sol";

contract Initiator is IInitiator, Ownable, ReentrancyGuard {

    using SafeERC20 for IERC20;
    mapping(address => ISubExecutor.SubStorage) public subscriptionBySubscriber;
    address[] public subscribers;
    mapping(address => bool) public whitelistedAddresses;

    function whitelistTokenForPayment(address _tokenAddress) external onlyOwner {
        require(!whitelistedAddresses[_tokenAddress], "Address is already whitelisted");
        whitelistedAddresses[_tokenAddress] = true;

        emit AddressAdded(_tokenAddress);
    }

    function removeTokenForPayment(address _tokenAddress) external onlyOwner {
        require(whitelistedAddresses[_tokenAddress], "Address is not whitelisted");
        delete whitelistedAddresses[_tokenAddress];

        emit AddressRemoved(_tokenAddress);
    }

    function isValidERC20PaymentToken(address _tokenAddress) public view returns (bool) {
        return whitelistedAddresses[_tokenAddress];
    }

    /// @notice Registers a new subscription for a subscriber
    /// @param _subscriber Address of the subscriber
    /// @param _amount The amount for the subscription
    /// @param _validUntil The timestamp until which the subscription is valid
    /// @param _validAfter Initiation timestamp of the subscription
    /// @param _paymentInterval The interval at which payments should be made
    /// @param _erc20Token The ERC20 token address used for payment (address(0) for ETH)
    function registerSubscription(
        address _subscriber,
        uint256 _amount,
        uint256 _validUntil,
        uint256 _validAfter,
        uint256 _paymentInterval,
        address _erc20Token
    ) public {
        require(_amount > 0, "Subscription amount is 0");
        require(_paymentInterval > 0, "Payment interval is 0");
        require(msg.sender == _subscriber, "Only the subscriber can register a subscription");
        require(_subscriber.code.length > 0, "Subscriber is not a contract");
        require(_validAfter >= block.timestamp, "Sub cannot be valid after a time in the past");

        ISubExecutor.SubStorage memory sub = ISubExecutor.SubStorage({
            amount: _amount,
            validUntil: _validUntil,
            validAfter: _validAfter,
            paymentInterval: _paymentInterval,
            subscriber: _subscriber,
            initiator: address(this),
            erc20TokensValid: _erc20Token == address(0) ? false : true,
            erc20Token: _erc20Token
        });
        subscriptionBySubscriber[_subscriber] = sub;
        subscribers.push(_subscriber);
    }

    /// @notice Removes a subscription for a subscriber
    /// @param _subscriber Address of the subscriber
    function removeSubscription(address _subscriber) public {
        require(msg.sender == _subscriber, "Only the subscriber can remove a subscription");
        delete subscriptionBySubscriber[_subscriber];
    }

    /// @notice Retrieves the subscription details for a given subscriber
    /// @param _subscriber Address of the subscriber
    /// @return The subscription details
    function getSubscription(address _subscriber) public view returns (ISubExecutor.SubStorage memory) {
        ISubExecutor.SubStorage memory subscription = subscriptionBySubscriber[_subscriber];
        return subscription;
    }

    /// @notice Returns the list of all subscribers
    /// @return A list of addresses of subscribers
    function getSubscribers() public view returns (address[] memory) {
        return subscribers;
    }

    /// @notice Initiates a payment for a given subscriber
    /// @param _subscriber Address of the subscriber
    /// @dev This function ensures that the subscription is active and the payment interval has been reached
    function initiatePayment(address _subscriber) public nonReentrant {
        ISubExecutor.SubStorage storage subscription = subscriptionBySubscriber[_subscriber];
        require(subscription.validUntil > block.timestamp, "Subscription is not active");
        require(subscription.validAfter <= block.timestamp, "Subscription is not active");
        require(subscription.amount > 0, "Subscription amount is 0");
        require(subscription.paymentInterval > 0, "Payment interval is 0");

        ISubExecutor(subscription.subscriber).processPayment();
    }

    /// @notice Withdraws all Ether held by the contract to the owner's address
    /// @dev This function can only be called by the contract owner
    function withdrawETH() public onlyOwner {
        (bool success, ) = owner().call{value: address(this).balance}("");
        require(success, "WithdrawETH failed.");
    }

    /// @notice Withdraws all of a specific ERC20 token held by the contract to the owner's address
    /// @param _token The ERC20 token address
    /// @dev This function can only be called by the contract owner
    function withdrawERC20(address _token) public onlyOwner {
        IERC20 token = IERC20(_token);
        token.safeTransfer(owner(), token.balanceOf(address(this)));
    }

    receive() external payable {}
}
