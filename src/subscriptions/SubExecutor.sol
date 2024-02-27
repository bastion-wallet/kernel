// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import "../abstract/KernelStorage.sol";
import "../interfaces/IInitiator.sol";

contract SubExecutor is ReentrancyGuard {
    using SafeERC20 for IERC20;

    event revokedApproval(address indexed _subscriber);
    event paymentProcessed(address indexed _subscriber, uint256 _amount);
    event subscriptionCreated(address indexed _initiator, address indexed _subscriber, uint256 _amount);
    event subscriptionModified(address indexed _initiator, address indexed _subscriber, uint256 _amount);

    /// @notice Internal function to retrieve the kernel storage
    /// @return ws The wallet kernel storage
    function getKernelStorage() internal pure returns (WalletKernelStorage storage ws) {
        bytes32 storagePosition = bytes32(uint256(keccak256("zerodev.kernel")) - 1);
        assembly {
            ws.slot := storagePosition
        }
    }

    /// @notice Modifier to ensure the caller is the entry point, the contract itself, or the owner
    modifier onlyFromEntryPointOrOwnerOrSelf() {
        address owner = getKernelStorage().owner;
        address entryPoint = 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789;
        require(
            msg.sender == address(entryPoint) || msg.sender == address(this) || msg.sender == owner,
            "account: not from entrypoint or owner or self"
        );
        _;
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
    ) external onlyFromEntryPointOrOwnerOrSelf {
        getKernelStorage().subscriptions[_initiator] = SubStorage({
            amount: _amount,
            validUntil: _validUntil,
            validAfter: _validAfter,
            paymentInterval: _interval,
            subscriber: address(this),
            initiator: _initiator,
            erc20Token: _erc20Token,
            erc20TokensValid: _erc20Token == address(0) ? false : true
        });
        IInitiator(_initiator).registerSubscription(
            address(this), _amount, _validUntil, _validAfter, _interval, _erc20Token
        );

        emit subscriptionCreated(msg.sender, _initiator, _amount);
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
    ) external onlyFromEntryPointOrOwnerOrSelf {
        getKernelStorage().subscriptions[_initiator] = SubStorage({
            amount: _amount,
            validUntil: _validUntil,
            validAfter: _validAfter,
            paymentInterval: _interval,
            subscriber: address(this),
            initiator: _initiator,
            erc20Token: _erc20Token,
            erc20TokensValid: _erc20Token == address(0) ? false : true
        });

        IInitiator(_initiator).registerSubscription(
            address(this), _amount, _validUntil, _validAfter, _interval, _erc20Token
        );

        emit subscriptionModified(msg.sender, _initiator, _amount);
    }

    /// @notice Revokes an existing subscription
    /// @param _initiator Address of the initiator
    function revokeSubscription(address _initiator) external onlyFromEntryPointOrOwnerOrSelf {
        delete getKernelStorage().subscriptions[_initiator];
        IInitiator(_initiator).removeSubscription(address(this));
        emit revokedApproval(_initiator);
    }

    /// @notice Retrieves the subscription details
    /// @param _initiator Address of the initiator
    /// @return The subscription details
    function getSubscription(address _initiator) external view returns (SubStorage memory) {
        return getKernelStorage().subscriptions[_initiator];
    }

    /// @notice Retrieves the payment history for a given initiator
    /// @param _initiator Address of the initiator
    /// @return An array of payment records
    function getPaymentHistory(address _initiator) external view returns (PaymentRecord[] memory) {
        return getKernelStorage().paymentRecords[_initiator];
    }

    /// @notice Processes a payment for the subscription
    function processPayment() external nonReentrant {
        SubStorage storage sub = getKernelStorage().subscriptions[msg.sender];
        require(block.timestamp >= sub.validAfter, "Subscription not yet valid");
        require(block.timestamp <= sub.validUntil, "Subscription expired");
        require(msg.sender == sub.initiator, "Only the initiator can initiate payments");

        //Check when the last payment was done
        PaymentRecord[] storage paymentHistory = getKernelStorage().paymentRecords[msg.sender];
        if (paymentHistory.length > 0) {
            PaymentRecord storage lastPayment = paymentHistory[paymentHistory.length - 1];
            require(block.timestamp >= lastPayment.timestamp + sub.paymentInterval, "Payment interval not yet reached");
        } else {
            require(block.timestamp >= sub.validAfter + sub.paymentInterval, "Payment interval not yet reached");
        }

        getKernelStorage().paymentRecords[msg.sender].push(PaymentRecord(sub.amount, block.timestamp, sub.subscriber));

        //Check whether it's a native payment or ERC20 or ERC721
        if (IInitiator(payable(sub.initiator)).isValidERC20PaymentToken(sub.erc20Token)) {
            _processERC20Payment(sub);
        } else if (sub.erc20Token == address(0)) {
            _processNativePayment(sub);
        } else {
            revert("neither valid ERC20 nor native payment");
        }

        emit paymentProcessed(msg.sender, sub.amount);
    }

    /// @notice Gets the last payment timestamp for an initiator
    /// @param _initiator Address of the initiator
    /// @return The timestamp of the last payment
    function getLastPaidTimestamp(address _initiator) external view returns (uint256) {
        PaymentRecord[] storage paymentHistory = getKernelStorage().paymentRecords[_initiator];
        if (paymentHistory.length == 0) {
            return 0;
        }
        PaymentRecord storage lastPayment = paymentHistory[paymentHistory.length - 1];
        return lastPayment.timestamp;
    }

    /// @notice Processes an ERC20 payment for the subscription
    function _processERC20Payment(SubStorage storage sub) internal {
        IERC20 token = IERC20(sub.erc20Token);
        uint256 balance = token.balanceOf(address(this));
        require(balance >= sub.amount, "Insufficient token balance");
        token.safeTransfer(sub.initiator, sub.amount);
    }

    /// @notice Processes a native payment for the subscription
    function _processNativePayment(SubStorage storage sub) internal {
        require(address(this).balance >= sub.amount, "Insufficient Ether balance");
        (bool success,) = sub.initiator.call{value: sub.amount}("");
        require(success, "ProcessNativePayment failed.");
    }
}
