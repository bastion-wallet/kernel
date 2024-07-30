// SPDX-License-Identifier: MIT
pragma solidity >=0.8.9;

import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import "./interfaces/ISubscriptionModule.sol";
import "./interfaces/IInitiator.sol";
import  "./interfaces/IGnosisSafe.sol";


contract SubscriptionModule is ISubscriptionModule, ReentrancyGuard {

    using SafeERC20 for IERC20;
    event SubscriptionCreated(address indexed _subscriber, address indexed _initiator,  uint256 _amount);
    event SubscriptionModified(address indexed _subscriber, address indexed _initiator, uint256 _amount);
    
    /// @notice Creates a subscription
    /// @param _initiator Address of the initiator
    /// @param _amount Amount to be subscribed
    /// @param _interval Interval of payments in seconds
    /// @param _validUntil Expiration timestamp of the subscription
    /// @param _validAfter Initiation timestamp of the subscription
    /// @param _erc20Token Address of the ERC20 token for payment
    function createSubscription(
        address _initiator,
        uint256 _amount,
        uint256 _interval, // in seconds
        uint256 _validUntil, //timestamp
        uint256 _validAfter, //timestamp
        address _erc20Token
    ) external {
        IInitiator(_initiator).registerSubscription(msg.sender, _amount, _validUntil, _validAfter, _interval, _erc20Token);
        emit SubscriptionCreated(msg.sender, _initiator, _amount);
    }

    /// @notice Modifies an existing subscription
    /// @param _initiator Address of the initiator
    /// @param _amount New amount to be subscribed
    /// @param _interval New interval of payments in seconds
    /// @param _validUntil New expiration timestamp of the subscription
    /// @param _validAfter New initiation timestamp of the subscription
    /// @param _erc20Token Address of the ERC20 token for payment
    function modifySubscription(
        address _initiator,
        uint256 _amount,
        uint256 _interval,
        uint256 _validUntil,
        uint256 _validAfter,
        address _erc20Token
    ) external {
        IInitiator(_initiator).registerSubscription(msg.sender, _amount, _validUntil, _validAfter, _interval, _erc20Token);
        emit SubscriptionModified(msg.sender, _initiator, _amount);
    }

    /// @notice Revokes an existing subscription
    /// @param _initiator Address of the initiator
    function revokeSubscription(address _initiator) external {
        IInitiator(_initiator).removeSubscription(msg.sender);
        emit RevokedApproval(_initiator);
    }


    /// @notice Processes a payment for the subscription
    function processPayment(Subscription memory sub) external nonReentrant {
        require(block.timestamp >= sub.validAfter, "Subscription not yet valid");
        require(block.timestamp <= sub.validUntil, "Subscription expired");
        require(msg.sender == sub.initiator, "Only the initiator can initiate payments");

        //Check whether it's a native payment or ERC20 or ERC721
        if (IInitiator(payable(sub.initiator)).isValidERC20PaymentToken(sub.erc20Token)) {
            _processERC20Payment(sub);
        } else if(sub.erc20Token == address(0)) {
            _processNativePayment(sub);
        }
        else{
            revert("neither valid ERC20 nor native payment");
        }

        emit PaymentProcessed(msg.sender, sub.amount);
    }


    /// @notice Processes an ERC20 payment for the subscription
    function _processERC20Payment(Subscription memory sub) internal {
        IERC20 token = IERC20(sub.erc20Token);
        uint256 balance = token.balanceOf(msg.sender);
        require(balance >= sub.amount, "Insufficient token balance");
        // token.safeTransferFrom(msg.sender, sub.initiator, sub.amount);
        _transfer(IGnosisSafe(msg.sender), sub.erc20Token, payable(sub.initiator) ,sub.amount);
    }

    /// @notice Processes a native payment for the subscription
    function _processNativePayment(Subscription memory sub) internal {
        require(msg.sender.balance >= sub.amount, "Insufficient Ether balance");
        // (bool success, ) = sub.initiator.call{value: sub.amount}("");
        // require(success, "ProcessNativePayment failed.");
        _transfer(IGnosisSafe(msg.sender), address(0), payable(sub.initiator) ,sub.amount);
        
    }

    function _transfer(IGnosisSafe safe, address token, address payable to, uint256 amount) private {
        if (token == address(0)) {
            // solium-disable-next-line security/no-send
            require(safe.execTransactionFromModule(to, amount, "", Enum.Operation.Call), "Could not execute ether transfer");
        } else {
            bytes memory data = abi.encodeWithSignature("transfer(address,uint256)", to, amount);
            require(safe.execTransactionFromModule(token, 0, data, Enum.Operation.Call), "Could not execute token transfer");
        }
    }
}
