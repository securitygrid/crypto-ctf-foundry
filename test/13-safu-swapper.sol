// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

// utilities
import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
// core contracts
import {IUniswapV2Factory} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Router02} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import {IUniswapV2Pair} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import {IWETH} from "@uniswap/v2-periphery/contracts/interfaces/IWETH.sol";
import {Token} from "src/other/Token.sol";
import {SafuUtils} from "src/safu-swapper/SafuUtils.sol";
import {SafuPool} from "src/safu-swapper/SafuPool.sol";
import {Exploit} from "src/safu-swapper/Exploit.sol";


contract Testing is Test {

    address attacker = makeAddr('attacker');
    address o1 = makeAddr('o1');
    address o2 = makeAddr('o2');
    address admin = makeAddr('admin'); // should not be used
    address adminUser = makeAddr('adminUser'); // should not be used

    IUniswapV2Factory uniFactory;
    IUniswapV2Router02 uniRouter;
    IUniswapV2Pair uniPair; // DAI-USDC trading pair
    IWETH weth;
    Token usdc;
    Token safu;
    Token dai;
    SafuUtils safuUtils;
    SafuPool safuPool;

    /// preliminary state
    function setUp() public {

        // funding accounts
        vm.deal(admin, 10_000 ether);
        vm.deal(attacker, 10_000 ether);
        vm.deal(adminUser, 10_000 ether);

        // deploying token contracts
        vm.prank(admin);
        usdc = new Token('USDC','USDC');

        address[] memory addresses = new address[](2);
        uint256[] memory amounts = new uint256[](2);

        addresses[0]=admin; addresses[1]=adminUser;
        amounts[0]=1_000_000e18; amounts[1]=100_000e18;
        vm.prank(admin);
        usdc.mintPerUser(addresses,amounts);

        vm.prank(admin);
        dai = new Token('DAI','DAI');

        vm.prank(admin);
        dai.mint(admin,1_000_000e18);

        vm.prank(admin);
        safu = new Token('SAFU','SAFU');

        vm.prank(admin);
        safu.mint(adminUser,200_000e18);

        // deploying uniswap contracts
        weth = IWETH(
            deployCode("src/other/uniswap-build/WETH9.json")
        );
        uniFactory = IUniswapV2Factory(
            deployCode(
                "src/other/uniswap-build/UniswapV2Factory.json",
                abi.encode(admin)
            )
        );
        uniRouter = IUniswapV2Router02(
            deployCode(
                "src/other/uniswap-build/UniswapV2Router02.json",
                abi.encode(address(uniFactory),address(weth))
            )
        );

        // --adding initial liquidity for DAI-USDC
        vm.prank(admin);
        usdc.approve(address(uniRouter),type(uint).max);
        vm.prank(admin);
        dai.approve(address(uniRouter),type(uint).max);

        vm.prank(admin);
        uniRouter.addLiquidity( // creates pair
            address(usdc),address(dai),
            1_000_000e18,1_000_000e18,
            0,0,
            admin,block.timestamp
        );

        uniPair = IUniswapV2Pair(uniFactory.getPair(address(usdc),address(dai)));

        // initializing core contracts
        vm.prank(admin);
        safuUtils = new SafuUtils();

        vm.prank(admin);
        safuPool = new SafuPool(
            address(safu),
            address(usdc),
            address(safuUtils)
        );

        // --adding initial liquidity to pool
        vm.prank(adminUser);
        usdc.approve(address(safuPool),type(uint).max);
        vm.prank(adminUser);
        safu.approve(address(safuPool),type(uint).max);
        vm.prank(adminUser);
        safuPool.addLiquidity(200_000e18,100_000e18);

    }

    /// solves the challenge
    function testChallengeExploit() public {
        vm.startPrank(attacker,attacker);

        // implement solution here
        Exploit exp = new Exploit(
            address(uniPair), 
            address(usdc), 
            address(safu), 
            address(safuPool)
        );
        exp.start(900_000e18);
        emit log_named_decimal_uint("usdc=", usdc.balanceOf(attacker), 18);

        vm.stopPrank();
        validation();
    }

    /// expected final state
    function validation() public {

        // attacker drains >= 90% of funds
        assertGe(usdc.balanceOf(attacker),90_000e18);
        assertLe(usdc.balanceOf(address(safuPool)),10_000e18);

    }

}