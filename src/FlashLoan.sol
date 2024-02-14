// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "aaveV3-core/contracts/flashloan/base/FlashLoanReceiverBase.sol";
import "aaveV3-core/contracts/protocol/configuration/PoolAddressesProviderRegistry.sol";
import "aaveV3-core/contracts/protocol/configuration/PoolAddressesProvider.sol";
import "aaveV3-core/contracts/protocol/pool/Pool.sol";
import "aaveV3-core/contracts/dependencies/openzeppelin/contracts/IERC20.sol";
import "aaveV3-core/contracts/dependencies/openzeppelin/contracts/SafeERC20.sol";

import "forge-std/console.sol";

contract FlashLoan is FlashLoanReceiverBase {
    using SafeERC20 for IERC20;

    PoolAddressesProviderRegistry constant providerRegistry =
        PoolAddressesProviderRegistry(0xbaA999AC55EAce41CcAE355c77809e68Bb345170);

    address[] addressProvider = providerRegistry.getAddressesProvidersList();
    PoolAddressesProvider public provider = PoolAddressesProvider(addressProvider[0]);
    Pool pool = Pool(provider.getPool());

    constructor() FlashLoanReceiverBase(provider) {}

    function getFlashLoan(address _asset, uint256 _amount) external {
        require(IERC20(_asset).balanceOf(address(this)) > 0, "balance must be > 0");

        uint16 referralCode = 0;
        bytes memory params = "";

        address[] memory assets = new address[](1);
        assets[0] = _asset;

        uint256[] memory amounts = new uint256[](1);
        amounts[0] = _amount;

        uint256[] memory interestRateModes = new uint256[](1);
        interestRateModes[0] = 0;

        pool.flashLoan(address(this), assets, amounts, interestRateModes, address(this), params, referralCode);
    }

    function executeOperation(
        address[] calldata assets,
        uint256[] calldata amounts,
        uint256[] calldata premiums,
        address initiator,
        bytes calldata params
    ) external returns (bool) {
        console.log("dai initial balance: ", IERC20(assets[0]).balanceOf(address(this)));

        for (uint256 i = 0; i < assets.length; i++) {
            console.log("borrowed: ", amounts[i]);
            console.log("premium: ", premiums[i]);

            uint256 amountToPay = amounts[i] + premiums[i];
            IERC20(assets[i]).safeApprove(address(pool), amountToPay);
        }
        return true;
    }
}
