// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import "src/abstract/KernelStorage.sol";

contract SubExecutor {
    event preApproved(address indexed _subscriber, uint256 _amount);
    event revokedApproval(address indexed _subscriber);
    event paymentProcessed(address indexed _subscriber, uint256 _amount);

    struct SubStorage {
        uint256 amount;
        uint256 validUntil;
        uint256 validAfter;
        uint256 paymentInterval; // In days
        uint256 paymentLimit;
        address payee;
        address initiator;
        bool erc20TokensValid;
        bool erc721TokensValid;
        address erc20Token;
        address erc721Token;
    }

    struct PaymentRecord {
        uint256 amount;
        uint256 timestamp;
        address payee;
    }

    struct PaymentHistory {
        mapping(address => PaymentRecord[]) paymentRecords;
        mapping(address => SubStorage) subscriptions;
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

    function getPaymentHistoryStorage() internal pure returns (PaymentHistory storage ws) {
        bytes32 storagePosition = bytes32(uint256(keccak256("subscription.paymentHistory")) - 1);
        assembly {
            ws.slot := storagePosition
        }
    }

    function preApprove(
        address _payee,
        uint256 _amount,
        uint256 _paymentInterval,
        uint256 _paymentLimit,
        address erc20TokenAddress,
        address erc721TokenAddress
    ) public {
        SubStorage storage sub = getSubStorage();
        sub.amount = _amount;
        sub.validUntil = block.timestamp + 365 days;
        sub.validAfter = block.timestamp;
        sub.payee = _payee;
        sub.paymentInterval = _paymentInterval;
        sub.paymentLimit = _paymentLimit;
        sub.initiator = msg.sender;

        if (erc20TokenAddress != address(0)) {
            sub.erc20TokensValid = true;
            sub.erc20Token = erc20TokenAddress;
        }

        if (erc721TokenAddress != address(0)) {
            sub.erc721TokensValid = true;
            sub.erc721Token = erc721TokenAddress;
        }

        emit preApproved(msg.sender, _amount);
    }

    function revokeApproval() public {
        SubStorage storage sub = getSubStorage();
        require(msg.sender == sub.initiator, "Only the initiator can revoke the approval");

        PaymentHistory storage ph = getPaymentHistoryStorage();
        delete ph.subscriptions[msg.sender];

        emit revokedApproval(msg.sender);
    }

    function getSubscriptions(address _subscriber) public view returns (SubStorage memory) {
        PaymentHistory storage ph = getPaymentHistoryStorage();
        return ph.subscriptions[_subscriber];
    }

    function getPaymentHistory(address _subscriber) public view returns (PaymentRecord[] memory) {
        PaymentHistory storage ph = getPaymentHistoryStorage();
        return ph.paymentRecords[_subscriber];
    }

    function processPayment() public {
        SubStorage storage sub = getSubStorage();
        PaymentHistory storage ph = getPaymentHistoryStorage();
        require(block.timestamp >= sub.validAfter, "Subscription not yet valid");
        require(block.timestamp <= sub.validUntil, "Subscription expired");
        require(msg.sender == sub.initiator, "Only the initiator can initiate payments");
        require(ph.subscriptions[msg.sender].amount != 0, "Subscription does not exist");

        //Check when the last payment was done
        PaymentRecord[] storage paymentHistory = ph.paymentRecords[msg.sender];
        PaymentRecord storage lastPayment = paymentHistory[paymentHistory.length - 1];
        require(block.timestamp >= lastPayment.timestamp + sub.paymentInterval, "Payment interval not yet reached");

        //Check whether it's a native payment or ERC20 or ERC721
        if (sub.erc20TokensValid) {
            IERC20 token = IERC20(sub.erc20Token);
            token.transferFrom(msg.sender, sub.payee, sub.amount);
        } else if (sub.erc721TokensValid) {
            IERC721 token = IERC721(sub.erc721Token);
            token.transferFrom(msg.sender, sub.payee, sub.amount);
        } else {
            payable(sub.payee).transfer(sub.amount);
        }

        paymentHistory.push(PaymentRecord(sub.amount, block.timestamp, sub.payee));

        emit paymentProcessed(msg.sender, sub.amount);
    }
}
