// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "aaveV3-core/contracts/flashloan/base/FlashLoanSimpleReceiverBase.sol";
import "aaveV3-core/contracts/protocol/configuration/PoolAddressesProviderRegistry.sol";
import "aaveV3-core/contracts/protocol/configuration/PoolAddressesProvider.sol";
import "aaveV3-core/contracts/protocol/pool/Pool.sol";
import "aaveV3-core/contracts/dependencies/openzeppelin/contracts/IERC20.sol";
import "aaveV3-core/contracts/dependencies/openzeppelin/contracts/SafeERC20.sol";

contract FlashLoanSimple is FlashLoanSimpleReceiverBase {
    using SafeERC20 for IERC20;

    PoolAddressesProviderRegistry constant providerRegistry =
        PoolAddressesProviderRegistry(0xbaA999AC55EAce41CcAE355c77809e68Bb345170);

    address[] addressProvider = providerRegistry.getAddressesProvidersList();
    PoolAddressesProvider public provider = PoolAddressesProvider(addressProvider[0]);
    Pool pool = Pool(provider.getPool());

    constructor() FlashLoanSimpleReceiverBase(provider) {}

    function getSimpleFlashLoan(address _asset, uint256 _amount) external {
        require(IERC20(_asset).balanceOf(address(this)) > 0, "balance must be > 0");

        uint16 referralCode = 0;
        bytes memory params = "";

        pool.flashLoanSimple(address(this), _asset, _amount, params, referralCode);
    }

    function executeOperation(address asset, uint256 amount, uint256 premium, address initiator, bytes calldata params)
        external
        returns (bool)
    {
        uint256 amountToPay = amount + premium;
        IERC20(asset).safeApprove(address(pool), amountToPay);
        return true;
    }
}
