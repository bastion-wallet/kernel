// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import "../abstract/KernelStorage.sol";
import "../interfaces/IInitiator.sol";

contract SubExecutor is ReentrancyGuard {
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
        SubStorage storage sub = getSubStorage();
        sub.amount = _amount;
        sub.validUntil = block.timestamp + 365 days;
        sub.validAfter = block.timestamp;
        sub.subscriber = address(this);
        sub.paymentInterval = _interval * 1 days;
        sub.paymentLimit = _paymentLimit;
        sub.initiator = _initiator;
        sub.erc20Token = _erc20Token;
        sub.erc20TokensValid = _erc20Token == address(0) ? false : true;

        Subscriptions storage subs = getSubscriptionsStorage();
        subs.subscriptions[_initiator] = sub;

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
        Subscriptions storage subs = getSubscriptionsStorage();
        SubStorage storage sub = subs.subscriptions[_initiator];

        require(sub.initiator == _initiator, "Subscription does not exist");
        sub.amount = _amount;
        sub.validUntil = block.timestamp + 365 days;
        sub.validAfter = block.timestamp;
        sub.paymentInterval = _interval * 1 days;
        sub.paymentLimit = _paymentLimit;
        sub.erc20Token = _erc20Token;
        sub.erc20TokensValid = _erc20Token == address(0) ? false : true;

        Initiator(_initiator).registerSubscription(address(this), _amount, _interval, _amount, address(0));

        emit subscriptionCreated(msg.sender, _initiator, _amount);
    }

    function revokeSubscription(address _initiator, uint256 _amount, uint256 _interval)
        external
        onlyFromEntryPointOrOwnerOrSelf
    {
        require(_amount > 0, "Subscription amount is 0");
        require(_interval > 0, "Payment interval is 0");

        Subscriptions storage subs = getSubscriptionsStorage();
        delete subs.subscriptions[_initiator];

        Initiator(_initiator).removeSubscription(address(this));

        emit revokedApproval(_initiator);
    }

    function getSubscription(address _initiator) external view returns (SubStorage memory) {
        Subscriptions storage subs = getSubscriptionsStorage();
        return subs.subscriptions[_initiator];
    }

    function getPaymentHistory(address _initiator) external view returns (PaymentRecord[] memory) {
        PaymentHistory storage ph = getPaymentHistoryStorage();
        return ph.paymentRecords[_initiator];
    }

    function updateAllowance(uint256 _amount) external {
        SubStorage storage sub = getSubStorage();
        require(msg.sender == sub.initiator, "Only the initiator can update the allowance");
        sub.amount = _amount;
    }

    function processPayment() external nonReentrant {
        SubStorage storage sub = getSubStorage();
        PaymentHistory storage ph = getPaymentHistoryStorage();
        require(block.timestamp >= sub.validAfter, "Subscription not yet valid");
        require(block.timestamp <= sub.validUntil, "Subscription expired");
        require(msg.sender == sub.initiator, "Only the initiator can initiate payments");

        //Check when the last payment was done
        PaymentRecord[] storage paymentHistory = ph.paymentRecords[msg.sender];
        PaymentRecord storage lastPayment = paymentHistory[paymentHistory.length - 1];
        require(
            paymentHistory.length == 0 || block.timestamp >= lastPayment.timestamp + sub.paymentInterval,
            "Payment interval not yet reached"
        );

        paymentHistory.push(PaymentRecord(sub.amount, block.timestamp, sub.subscriber));

        //Check whether it's a native payment or ERC20 or ERC721
        if (sub.erc20TokensValid) {
            _processERC20Payment(sub);
        } else {
            _processNativePayment(sub);
        }

        emit paymentProcessed(msg.sender, sub.amount);
    }

    function getLastPaidTimestamp(address _initiator) external view returns (uint256) {
        PaymentHistory storage ph = getPaymentHistoryStorage();
        PaymentRecord[] storage paymentHistory = ph.paymentRecords[_initiator];
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
