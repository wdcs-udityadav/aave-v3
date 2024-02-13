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

    function getUserAccountData(address _user) external view returns (uint256, uint256, uint256, uint256) {
        (uint256 totalCollateralBase, uint256 totalDebtBase, uint256 availableBorrowsBase,,, uint256 healthFactor) =
            pool.getUserAccountData(_user);
        return (totalCollateralBase, totalDebtBase, availableBorrowsBase, healthFactor);
    }

    function getReserveData(address _asset) public view returns (address, address, address) {
        DataTypes.ReserveData memory reserveData = pool.getReserveData(_asset);
        return (reserveData.aTokenAddress, reserveData.stableDebtTokenAddress, reserveData.variableDebtTokenAddress);
    }

    function supply(address _asset, uint256 _amount, address _behalfOf) external {
        uint16 refCode = 0;
        IERC20(_asset).safeTransferFrom(_behalfOf, address(this), _amount);
        IERC20(_asset).safeApprove(address(pool), _amount);
        pool.supply(_asset, _amount, _behalfOf, refCode);
    }

    function withdraw(address _asset, address _aToken, uint256 _aTokenBalance, uint256 _amount, address _to) external {
        IERC20(_aToken).safeTransferFrom(_to, address(this), _aTokenBalance);
        IERC20(_aToken).safeApprove(address(pool), _aTokenBalance);

        pool.withdraw(_asset, _amount, _to);
    }

    function borrow(address _asset, uint256 _amount, address _behalfOf) external {
        uint256 interestRateMode = 2;
        uint16 referralCode = 0;
        pool.borrow(_asset, _amount, interestRateMode, referralCode, _behalfOf);
    }

    function repay(address _asset, uint256 _amount, address _behalfOf) external {
        uint256 rateMode = 2;
        IERC20(_asset).safeApprove(address(pool), _amount);
        pool.repay(_asset, _amount, rateMode, _behalfOf);
    }

    function liquidationCall(
        address _collateralAsset,
        address _debtAsset,
        address _user,
        address _liquidator,
        uint256 _debtToCover
    ) external {
        bool _receiveAToken = false;
        IERC20(_collateralAsset).safeTransferFrom(_liquidator, address(this), _debtToCover);
        IERC20(_collateralAsset).safeApprove(address(pool), _debtToCover);
        pool.liquidationCall(_collateralAsset, _debtAsset, _user, _debtToCover, _receiveAToken);
    }
}
