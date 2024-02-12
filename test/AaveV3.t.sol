// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import {Test, console} from "forge-std/Test.sol";
import {AaveV3} from "../src/AaveV3.sol";

import "aaveV3-core/contracts/protocol/configuration/PoolAddressesProviderRegistry.sol";
import "aaveV3-core/contracts/protocol/configuration/PoolAddressesProvider.sol";
import "aaveV3-core/contracts/protocol/pool/Pool.sol";

import "aaveV3-core/contracts/dependencies/openzeppelin/contracts/IERC20.sol";
import "aaveV3-core/contracts/dependencies/openzeppelin/contracts/SafeERC20.sol";

contract AaveV3Test is Test {
    using SafeERC20 for IERC20;

    AaveV3 public aaveV3;
    IERC20 constant DAI = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    address user = vm.addr(1);

    function setUp() public {
        aaveV3 = new AaveV3();
    }

    function testGetProvider() public view {
        console.log("provider: ", address(aaveV3.provider()));
    }

    function testGetPool() public view {
        console.log("pool: ", address(aaveV3.pool()));
    }

    function testSupply() public {
        uint256 amount = 10000 * 1e18;
        deal(address(DAI), user, amount, true);

        vm.startPrank(user);
        assertEq(DAI.balanceOf(user), amount);
        DAI.safeApprove(address(aaveV3), amount);
        aaveV3.supply(address(DAI), amount, user);
        assertEq(DAI.balanceOf(user), 0);
        vm.stopPrank();
    }

    function testSupplySelf() public {
        uint256 amount = 10000 * 1e18;
        deal(address(DAI), address(this), amount, true);
        console.log("DAI contract bal: ", DAI.balanceOf(address(this)) / 1e18);

        DAI.safeTransfer(address(aaveV3), amount);
        aaveV3.supplySelf(address(DAI), amount);

        (address aToken,) = aaveV3.getReserveData(address(this));
        console.log("aToken contract balance: ", IERC20(aToken).balanceOf(address(this)) / 1e18);
        console.log("DAI user balance: ", DAI.balanceOf(address(this)) / 1e18);
    }

    function testWithdraw() public {
        testSupply();

        vm.startPrank(user);
        (address aToken,) = aaveV3.getReserveData(address(DAI));
        uint256 aTokenBalance = IERC20(aToken).balanceOf(user);
        console.log("aToken user balance: ", aTokenBalance);
        console.log("DAI user balance: ", DAI.balanceOf(user));

        IERC20(aToken).safeApprove(address(aaveV3), aTokenBalance);
        aaveV3.withdraw(address(DAI), aToken, aTokenBalance, type(uint256).max, user);

        console.log("aToken user balance: ", IERC20(aToken).balanceOf(user));
        console.log("DAI user balance: ", DAI.balanceOf(user));
        vm.stopPrank();
    }

    function testBorrow() public {
        testSupply();
        uint256 debtAmount = 2 * 1e18;
        aaveV3.borrow(0x514910771AF9Ca656af840dff83E8264EcF986CA, debtAmount);
    }

    // function testBorrow() public {
    //     uint256 amountDeposited = 10000 * 1e18;
    //     testDeposit();
    //     console.log("******borrow*******");

    //     uint256 debtToken = 50 * 1e18;

    //     vm.startPrank(user);
    //     (address aToken, address variableDebtTokenAddress) = aaveV3.getReserveData(address(DAI));
    //     assertEq(IERC20(aToken).balanceOf(user), amountDeposited);
    //     assertEq(IERC20(variableDebtTokenAddress).balanceOf(user), 0);

    //     (uint256 totalCollateralETH,uint256  availableBorrowsETH, uint256 totalDebtETH,) = aaveV3.getUserAccountData(user);
    //     console.log("initital totalCollateralETH: ", totalCollateralETH);
    //     console.log("initital availableBorrowsETH: ", availableBorrowsETH);
    //     console.log("initital totalDebtETH: ", totalDebtETH);

    //     LendingPoolAddressesProviderRegistry  providerRegistry =
    //     LendingPoolAddressesProviderRegistry(0x52D306e36E3B6B02c153d0266ff0f85d18BCD413);

    //     address[] memory addressProvider = providerRegistry.getAddressesProvidersList();
    //     LendingPoolAddressesProvider  provider = LendingPoolAddressesProvider(addressProvider[0]);
    //     LendingPool pool = LendingPool(provider.getLendingPool());

    //     pool.setUserUseReserveAsCollateral(address(DAI), true);

    //     IERC20(aToken).safeApprove(address(aaveV3), amountDeposited);

    //     // ICreditDelegationToken(variableDebtTokenAddress).approveDelegation(address(aaveV3), debtToken);
    //     // assertEq(ICreditDelegationToken(variableDebtTokenAddress).borrowAllowance(user, address(aaveV3)), debtToken);

    //     aaveV3.borrow(aToken, amountDeposited,address(DAI), debtToken, user);

    //     (,, uint256 totalDebtETH_,) = aaveV3.getUserAccountData(user);
    //     console.log("final totalDebtETH: ", totalDebtETH_);

    //     assertEq(IERC20(variableDebtTokenAddress).balanceOf(user), debtToken);
    //     assertEq(DAI.balanceOf(address(aaveV3)), debtToken);

    //     vm.stopPrank();
    // }

    // function testRepay() public {
    //     testBorrow();

    //     console.log("******repayment*******");
    //     uint256 debtAmount = 50 * 1e18;
    //     uint256 repayAmount = 51 * 1e18;
    //     vm.startPrank(user);
    //     (, address variableDebtTokenAddress) = aaveV3.getReserveData(address(DAI));

    //     (,, uint256 totalDebtETH,) = aaveV3.getUserAccountData(user);
    //     console.log("inital totalDebtETH: ", totalDebtETH);

    //     assertEq(IERC20(variableDebtTokenAddress).balanceOf(user), debtAmount);
    //     aaveV3.repay(address(DAI), repayAmount, user);

    //     (,, uint256 totalDebtETH_,) = aaveV3.getUserAccountData(user);
    //     console.log("final totalDebtETH: ", totalDebtETH_);
    //     assertEq(IERC20(variableDebtTokenAddress).balanceOf(user), 0);

    //     vm.stopPrank();
    // }

    // function testFailLiquidationCall() public {
    //     testBorrow();
    //     vm.startPrank(user);
    //     aaveV3.liquidationCall(address(DAI), address(DAI), user);
    //     vm.stopPrank();
    // }
}
