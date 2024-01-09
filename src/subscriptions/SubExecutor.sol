// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import "../abstract/KernelStorage.sol";
import "../interfaces/IInitiator.sol";

contract SubExecutor is ReentrancyGuard {
    // TODO - return active/inactive subscriptions
    event preApproval(address indexed _subscriber, uint256 _amount);
    event revokedApproval(address indexed _subscriber);
    event paymentProcessed(address indexed _subscriber, uint256 _amount);
    event subscriptionCreated(address indexed _initiator, address indexed _subscriber, uint256 _amount);

    modifier onlyOwner() {
        require(msg.sender == getKernelStorage().owner, "Only the owner can call this function");
        _;
    }

    // Function to get the wallet kernel storage
    function getKernelStorage() internal pure returns (WalletKernelStorage storage ws) {
        bytes32 storagePosition = bytes32(uint256(keccak256("zerodev.kernel")) - 1);
        assembly {
            ws.slot := storagePosition
        }
    }

    function getSubStorage() internal pure returns (SubStorage storage ws) {
        bytes32 storagePosition = bytes32(uint256(keccak256("subscription.storage")) - 1);
        assembly {
            ws.slot := storagePosition
        }
    }

    function getPaymentRecordStorage() internal pure returns (PaymentRecord storage ws) {
        bytes32 storagePosition = bytes32(uint256(keccak256("subscription.paymentRecord")) - 1);
        assembly {
            ws.slot := storagePosition
        }
    }

    function getPaymentHistoryStorage() internal pure returns (PaymentHistory storage ws) {
        bytes32 storagePosition = bytes32(uint256(keccak256("subscription.paymentHistory")) - 1);
        assembly {
            ws.slot := storagePosition
        }
    }

    function getSubscriptionsStorage() internal pure returns (Subscriptions storage ws) {
        bytes32 storagePosition = bytes32(uint256(keccak256("subscription.subscriptions")) - 1);
        assembly {
            ws.slot := storagePosition
        }
    }

    // Modifier to check if the function is called by the entry point, the contract itself or the owner
    modifier onlyFromEntryPointOrOwnerOrSelf() {
        address owner = getKernelStorage().owner;
        address entryPoint = 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789;
        require(
            msg.sender == address(entryPoint) || msg.sender == address(this) || msg.sender == owner,
            "account: not from entrypoint or owner or self"
        );
        _;
    }

    function createSubscription(
        address _initiator,
        uint256 _amount,
        uint256 _interval,
        uint256 _paymentLimit,
        address _erc20Token
    ) external onlyFromEntryPointOrOwnerOrSelf {
        require(_amount > 0, "Subscription amount is 0");
        getKernelStorage().subscriptions[_initiator] = SubStorage({
            amount: _amount,
            validUntil: block.timestamp + 365 days,
            validAfter: block.timestamp,
            paymentInterval: _interval * 1 days,
            paymentLimit: _paymentLimit,
            subscriber: address(this),
            initiator: _initiator,
            erc20Token: _erc20Token,
            erc20TokensValid: _erc20Token == address(0) ? false : true
        });
        Initiator(_initiator).registerSubscription(address(this), _amount, _interval, _amount, address(0));

        emit subscriptionCreated(msg.sender, _initiator, _amount);
    }

    function modifySubscription(
        address _initiator,
        uint256 _amount,
        uint256 _interval,
        uint256 _paymentLimit,
        address _erc20Token
    ) external onlyFromEntryPointOrOwnerOrSelf {
        getKernelStorage().subscriptions[_initiator] = SubStorage({
            amount: _amount,
            validUntil: block.timestamp + 365 days,
            validAfter: block.timestamp,
            paymentInterval: _interval * 1 days,
            paymentLimit: _paymentLimit,
            subscriber: address(this),
            initiator: _initiator,
            erc20Token: _erc20Token,
            erc20TokensValid: _erc20Token == address(0) ? false : true
        });

        Initiator(_initiator).registerSubscription(address(this), _amount, _interval, _amount, address(0));

        emit subscriptionCreated(msg.sender, _initiator, _amount);
    }

    function revokeSubscription(address _initiator) external onlyFromEntryPointOrOwnerOrSelf {
        delete getKernelStorage().subscriptions[_initiator];

        Initiator(_initiator).removeSubscription(address(this));

        emit revokedApproval(_initiator);
    }

    function getSubscription(address _initiator) external view returns (SubStorage memory) {
        return getKernelStorage().subscriptions[_initiator];
    }

    function getPaymentHistory(address _initiator) external view returns (PaymentRecord[] memory) {
        return getKernelStorage().paymentRecords[_initiator];
    }

    function updateAllowance(uint256 _amount) external {
        getKernelStorage().subscriptions[msg.sender].paymentLimit = _amount;
    }

    function processPayment() external nonReentrant {
        SubStorage storage sub = getKernelStorage().subscriptions[msg.sender];
        require(block.timestamp >= sub.validAfter, "Subscription not yet valid");
        require(block.timestamp <= sub.validUntil, "Subscription expired");
        require(msg.sender == sub.initiator, "Only the initiator can initiate payments");

        //Check when the last payment was done
        PaymentRecord[] storage paymentHistory = getKernelStorage().paymentRecords[msg.sender];
        PaymentRecord storage lastPayment = paymentHistory[paymentHistory.length - 1];
        require(
            paymentHistory.length == 0 || block.timestamp >= lastPayment.timestamp + sub.paymentInterval,
            "Payment interval not yet reached"
        );

        getKernelStorage().paymentRecords[msg.sender].push(PaymentRecord(sub.amount, block.timestamp, sub.subscriber));

        //Check whether it's a native payment or ERC20 or ERC721
        if (sub.erc20TokensValid) {
            _processERC20Payment(sub);
        } else {
            _processNativePayment(sub);
        }

        emit paymentProcessed(msg.sender, sub.amount);
    }

    function getLastPaidTimestamp(address _initiator) external view returns (uint256) {
        PaymentRecord[] storage paymentHistory = getKernelStorage().paymentRecords[_initiator];
        if (paymentHistory.length == 0) {
            return 0;
        }
        PaymentRecord storage lastPayment = paymentHistory[paymentHistory.length - 1];
        return lastPayment.timestamp;
    }

    function _processERC20Payment(SubStorage storage sub) internal {
        IERC20 token = IERC20(sub.erc20Token);
        uint256 balance = token.balanceOf(address(this));
        require(balance >= sub.amount, "Insufficient token balance");
        token.transferFrom(msg.sender, sub.subscriber, sub.amount);
    }

    function _processNativePayment(SubStorage storage sub) internal {
        require(address(this).balance >= sub.amount, "Insufficient Ether balance");
        payable(sub.subscriber).transfer(sub.amount);
    }

    //Function to remove ERC20tokens from the contract sent by mistake
    function withdrawERC20Tokens(address _tokenAddress) external {
        IERC20 token = IERC20(_tokenAddress);
        //Check the balance of the caller and return the tokens
        token.transfer(msg.sender, token.balanceOf(msg.sender));
    }
}
