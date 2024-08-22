// SPDX-License-Identifier: MIT
pragma solidity >=0.8.9;

import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "./Initiator.sol";
import "./interfaces/ISubscriptionModule.sol";
import "./interfaces/IInitiator.sol";
import  "./interfaces/IGnosisSafe.sol";


contract SubscriptionModule is ISubscriptionModule, ReentrancyGuard, Ownable {

    using SafeERC20 for IERC20;
    address[] public initiators;

    uint256 public constant SERVICE_FEE_PERCENT = 20; // 2% service fee, 1000 MAX BPS
    address public feeReceiverAddress;
    //mapping of user to created by initiators
    mapping(address => address[]) public initiatorByUser;

    constructor(address _feeReceiver) {
        feeReceiverAddress = _feeReceiver;
    }

    function setFeeReceiver(address _feeReceiver) external onlyOwner {
        feeReceiverAddress = _feeReceiver;
    }

    //function to register intitator
    function registerInitiator() external {
        IInitiator _initiator = new Initiator(address(this), msg.sender); 
        address initiatorAddr = address(_initiator);
        initiators.push(initiatorAddr);
        initiatorByUser[msg.sender].push(initiatorAddr);
        emit InitiatorRegistered(initiatorAddr, msg.sender);
    }

    function getAllInitiatorsOfUser(address _creator) external view returns(address[] memory) {
        return initiatorByUser[_creator];
    }
    
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
        uint256 balance = token.balanceOf(sub.subscriber);
        require(balance >= sub.amount, "Insufficient token balance");
        _transfer(IGnosisSafe(sub.subscriber), sub.erc20Token, payable(sub.initiator) ,sub.amount);
    }

    /// @notice Processes a native payment for the subscription
    function _processNativePayment(Subscription memory sub) internal {
        require(sub.subscriber.balance >= sub.amount, "Insufficient Ether balance");
        _transfer(IGnosisSafe(sub.subscriber), address(0), payable(sub.initiator) ,sub.amount);   
    }

    function _transfer(IGnosisSafe safe, address token, address payable to, uint256 amount) private {
        uint256 feeAmount = SERVICE_FEE_PERCENT/1000 * amount;
        uint256 amountToPay = amount - feeAmount;
        if (token == address(0)) {
            // solium-disable-next-line security/no-send
            require(safe.execTransactionFromModule(to, amountToPay, "", Enum.Operation.Call), "Could not execute ether transfer");
            
            //fee deduction
            require(safe.execTransactionFromModule(feeReceiverAddress, feeAmount, "", Enum.Operation.Call), "Could not execute ether transfer");
        } else {
            bytes memory data = abi.encodeWithSignature("transfer(address,uint256)", to, amountToPay);
            require(safe.execTransactionFromModule(token, 0, data, Enum.Operation.Call), "Could not execute token transfer");
            //fee deduction
            bytes memory data2 = abi.encodeWithSignature("transfer(address,uint256)", feeReceiverAddress, feeAmount);
            require(safe.execTransactionFromModule(token, 0, data2, Enum.Operation.Call), "Could not execute token transfer");
        }
    }
}
