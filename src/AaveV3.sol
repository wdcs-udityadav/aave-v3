// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "aaveV3-core/contracts/protocol/configuration/PoolAddressesProviderRegistry.sol";
import "aaveV3-core/contracts/protocol/configuration/PoolAddressesProvider.sol";
import "aaveV3-core/contracts/protocol/pool/Pool.sol";
import "aaveV3-core/contracts/dependencies/openzeppelin/contracts/IERC20.sol";
import "aaveV3-core/contracts/dependencies/openzeppelin/contracts/SafeERC20.sol";
import {DataTypes} from "aaveV3-core/contracts/protocol/libraries/types/DataTypes.sol";

import "forge-std/console.sol";

contract AaveV3 {
    using SafeERC20 for IERC20;

    PoolAddressesProviderRegistry constant providerRegistry =
        PoolAddressesProviderRegistry(0xbaA999AC55EAce41CcAE355c77809e68Bb345170);
    PoolAddressesProvider public provider;
    Pool public immutable pool;

    constructor() {
        address[] memory addressProvider = providerRegistry.getAddressesProvidersList();
        provider = PoolAddressesProvider(addressProvider[0]);
        pool = Pool(provider.getPool());
    }

    function supply(address _asset, uint256 _amount, address _behalfOf) external {
        uint16 refCode = 0;
        IERC20(_asset).safeTransferFrom(_behalfOf, address(this), _amount);
        IERC20(_asset).safeApprove(address(pool), _amount);
        pool.supply(_asset, _amount, _behalfOf, refCode);
    }

    function supplySelf(address _asset, uint256 _amount) external {
        uint16 refCode = 0;
        // IERC20(_asset).safeTransferFrom(msg.sender, address(this), _amount);
        IERC20(_asset).safeApprove(address(pool), _amount);
        pool.supply(_asset, _amount, msg.sender, refCode);
    }

    // function getUserAccountData(address _user) external view returns (uint256, uint256, uint256, uint256) {
    //     (uint256 totalCollateralETH, uint256 totalDebtETH, uint256 availableBorrowsETH,,, uint256 healthFactor) =
    //         pool.getUserAccountData(_user);
    //     return (totalCollateralETH, availableBorrowsETH, totalDebtETH, healthFactor);
    // }

    function getReserveData(address _asset) public view returns (address, address) {
        DataTypes.ReserveData memory reserveData = pool.getReserveData(_asset);
        return (reserveData.aTokenAddress, reserveData.variableDebtTokenAddress);
    }

    function withdraw(address _asset, address _aToken, uint256 _aTokenBalance, uint256 _amount, address _to) external {
        IERC20(_aToken).safeTransferFrom(_to, address(this), _aTokenBalance);
        IERC20(_aToken).safeApprove(address(pool), _aTokenBalance);

        pool.withdraw(_asset, _amount, _to);
    }

    function borrow(address _asset, uint256 _amount) external {
        uint256 interestRateMode = 2;
        uint16 referralCode = 0;
        pool.borrow(_asset, _amount, interestRateMode, referralCode, address(this));
    }

    // function borrow(address aToken, uint256 atokensDeposited,address _asset, uint256 _amount, address _behalfOf) external {
    //     uint256 interestRateMode = 2;
    //     uint16 refCode = 0;

    //     IERC20(aToken).safeTransferFrom(_behalfOf, address(this), atokensDeposited);
    //     IERC20(aToken).safeApprove( address(pool), atokensDeposited);

    //     pool.borrow(_asset, _amount, interestRateMode, refCode, _behalfOf);
    // }

    // function repay(address _asset, uint256 _amount, address _behalfOf) external {
    //     uint256 rateMode = 2;
    //     IERC20(_asset).safeApprove(address(pool), _amount);
    //     pool.repay(_asset, _amount, rateMode, _behalfOf);
    // }

    // function liquidationCall(address _collateralAsset, address _debtAsset, address _user) external {
    //     uint256 _debtToCover = uint256(-1);
    //     bool _receiveAToken = false;
    //     pool.liquidationCall(_collateralAsset, _debtAsset, _user, _debtToCover, _receiveAToken);
    // }
}
