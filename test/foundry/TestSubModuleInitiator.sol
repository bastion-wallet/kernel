// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import "openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import "../../src/modules/SubscriptionModule.sol";
import "../../src/modules/interfaces/IInitiator.sol";
import "../../src/modules/Initiator.sol";
import "./MockERC20.sol";

contract SubscriptionModuleTest is Test {
    SubscriptionModule public subscriptionModule;
    Initiator public initiator;
    address subscriber;
    uint256 subscriberKey;
    address mockToken;

    function setUp() public {
        (subscriber, subscriberKey) = makeAddrAndKey("subscriber");
        console.log("subscriber %s", subscriber);
        subscriptionModule = new SubscriptionModule();
        initiator = new Initiator(address(subscriptionModule));
        initiator.setSubscriptionModuleAddress(address(subscriptionModule));
        mockToken = address(makeMockToken());
        console.log("mockToken %s", mockToken);
        initiator.whitelistTokenForPayment(mockToken);
    }

    function test_registerInitiator() public {
        vm.startPrank(subscriber);
        subscriptionModule.registerInitiator();
        address payable initiatorAddr = payable(subscriptionModule.initiators(0));
        address _subModuleAddr = Initiator(initiatorAddr).subscriptionModuleAddress();
        address[] memory allInitiators = subscriptionModule.getAllInitiatorsOfUser(subscriber);

        assertEq(_subModuleAddr, address(subscriptionModule));
        assertEq(allInitiators[0], initiatorAddr);
    }

    function test_createSubscription() public {
        vm.startPrank(subscriber);
        // address mockToken = address(makeMockToken());
        subscriptionModule.createSubscription(address(initiator), 100, 10, block.timestamp  + 1 days, block.timestamp, mockToken);
       (uint256 amount,
        uint256 validUntil,
        uint256 validAfter,
        uint256 paymentInterval, // In days
        address _subscriber,
        address initiatorAddr,
        bool erc20TokensValid,
        address erc20Token ) = initiator.subscriptionBySubscriber(subscriber);
        console.log("amount %s", amount);
        assertEq(amount, 100);
        assertEq(validUntil, block.timestamp + 1 days);
        assertEq(validAfter, block.timestamp);
        assertEq(subscriber, _subscriber);
        assertEq(initiatorAddr, address(initiator));
        assertEq(erc20Token, mockToken);
    }

    function test_modifySubscription() public {
        vm.startPrank(subscriber);

        // address mockToken =address(makeMockToken()); 
        subscriptionModule.createSubscription(address(initiator), 100, 10, block.timestamp  + 1 days, block.timestamp, mockToken);

        subscriptionModule.modifySubscription(address(initiator), 200, 10, block.timestamp + 1 days, block.timestamp,  mockToken);

          (uint256 amount,
        uint256 validUntil,
        uint256 validAfter,
        uint256 paymentInterval, // In days
        address _subscriber,
        address initiatorAddr,
        bool erc20TokensValid,
        address erc20Token ) = initiator.subscriptionBySubscriber(subscriber);

        assertEq(amount, 200);
        assertEq(validUntil, block.timestamp + 1 days);
        assertEq(validAfter, block.timestamp);
        assertEq(subscriber, _subscriber);
        assertEq(initiatorAddr, address(initiator) );
        assertEq(erc20Token, mockToken);
    }

    function test_revokeSubscription() public {
        vm.startPrank(subscriber);
        // address mockToken =address(makeMockToken()); 

        subscriptionModule.createSubscription(address(initiator), 100, 10, block.timestamp  + 1 days, block.timestamp, mockToken);

        subscriptionModule.revokeSubscription(address(initiator));
        (uint256 amount,
        uint256 validUntil,
        uint256 validAfter,
        uint256 paymentInterval, // In days
        address subscriber,
        address initiatorAddr,
        bool erc20TokensValid,
        address erc20Token ) = initiator.subscriptionBySubscriber(subscriber);
        assertEq(validUntil, 0);
        assertEq(validAfter, 0);
        assertEq(subscriber, address(0));
        assertEq(initiatorAddr, address(0));
        assertEq(erc20Token, address(0));
    }

    // function test_processPayment() public {
    //     vm.startPrank(subscriber);
    //     // address mockToken = address(makeMockToken());
    //     subscriptionModule.createSubscription(address(initiator), 100, 10, block.timestamp  + 1 days, block.timestamp, mockToken);

    //     // Assuming mockToken is a mock ERC20 token
    //     MockERC20(mockToken).mint(subscriber, 1000);
    //     uint256 balance = MockERC20(mockToken).balanceOf(subscriber);
    //     console.log("balance %s", balance);

    //     MockERC20(mockToken).approve(address(subscriptionModule), 100);

    //     // Assuming the initiator has enough balance to pay for the subscription
    //     // uint256 expectedValidUntil = block.timestamp + 1;
    //     // uint256 expectedAmount = 100;
    //     // uint256 expectedSubscriber = subscriber;

    //     // MockERC20(mockToken).mint(subscriber, 1000);
    //     vm.warp(block.timestamp + 10);
    //     console.log("mocktoken balance  %s %s", address(mockToken), MockERC20(mockToken).balanceOf(subscriber));
    //     initiator.initiatePayment(subscriber);
    //     uint256 lastPayment = initiator.getLastPaidTimestamp(subscriber);
    //     console.log("lastPayment %s", lastPayment);

    //     // Check the expected values
    //     // assertEq(subscriptionModule.subscriptions(0).validUntil, expectedValidUntil);
    //     // assertEq(subscriptionModule.subscriptions(0).amount, expectedAmount);
    //     // assertEq(subscriptionModule.subscriptions(0).subscriber, expectedSubscriber);
    // }

    function makeMockToken() public returns (IERC20) {
        MockERC20 MockToken = new MockERC20();
        MockToken.mint(address(this), 100);
        console.log("minting for subsc: %s ", subscriber);
        MockToken.mint(subscriber, 1000);
        return MockToken;
    }
}


