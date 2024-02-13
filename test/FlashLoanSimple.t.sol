// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import {Test, console} from "forge-std/Test.sol";
import {FlashLoanSimple} from "../src/FlashLoanSimple.sol";

import "aaveV3-core/contracts/dependencies/openzeppelin/contracts/IERC20.sol";
import "aaveV3-core/contracts/dependencies/openzeppelin/contracts/SafeERC20.sol";

contract AaveV3Test is Test {
    using SafeERC20 for IERC20;

    FlashLoanSimple public flashLoanSimple;
    IERC20 constant DAI = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    address user = vm.addr(1);

    function setUp() public {
        flashLoanSimple = new FlashLoanSimple();
    }

    function testGetSimpleFlashLoan() public {
        uint256 amount = 1000 * 1e18;
        deal(address(DAI), user, amount, true);

        vm.startPrank(user);
        assertEq(DAI.balanceOf(user), amount);
        DAI.safeTransfer(address(flashLoanSimple), amount);
        assertEq(DAI.balanceOf(address(flashLoanSimple)), amount);

        uint256 loanAmount = 500 * 1e18;
        flashLoanSimple.getSimpleFlashLoan(address(DAI), loanAmount);
        vm.stopPrank();
    }
}
