// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import {Test, console} from "forge-std/Test.sol";
import {FlashLoan} from "../src/FlashLoan.sol";

import "aaveV3-core/contracts/dependencies/openzeppelin/contracts/IERC20.sol";
import "aaveV3-core/contracts/dependencies/openzeppelin/contracts/SafeERC20.sol";

contract AaveV3Test is Test {
    using SafeERC20 for IERC20;

    FlashLoan public flashLoan;
    IERC20 constant DAI = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    address user = vm.addr(1);

    function setUp() public {
        flashLoan = new FlashLoan();
    }

    function testGetFlashLoan() public {
        uint256 amountDai = 5 * 1e18;
        deal(address(DAI), user, amountDai, true);

        vm.startPrank(user);
        assertEq(DAI.balanceOf(user), amountDai);

        DAI.safeTransfer(address(flashLoan), amountDai);
        console.log("DAI @contract: ", DAI.balanceOf(address(flashLoan)));
        assertEq(DAI.balanceOf(address(flashLoan)), amountDai);

        uint256 loanAmountDai = 500 * 1e18;
        flashLoan.getFlashLoan(address(DAI), loanAmountDai);
        vm.stopPrank();

        console.log("DAI @contract: ", DAI.balanceOf(address(flashLoan)));
    }
}
