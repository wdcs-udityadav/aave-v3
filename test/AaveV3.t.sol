// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import {Test, console} from "forge-std/Test.sol";
import {AaveV3} from "../src/AaveV3.sol";

import "aaveV3-core/contracts/protocol/configuration/PoolAddressesProviderRegistry.sol";
import "aaveV3-core/contracts/protocol/configuration/PoolAddressesProvider.sol";
import "aaveV3-core/contracts/protocol/pool/Pool.sol";
import "aave-v3-core/contracts/interfaces/ICreditDelegationToken.sol";
import "aaveV3-core/contracts/dependencies/openzeppelin/contracts/IERC20.sol";
import "aaveV3-core/contracts/dependencies/openzeppelin/contracts/SafeERC20.sol";
import "aaveV3-periphery/contracts/rewards/RewardsController.sol";

contract AaveV3Test is Test {
    using SafeERC20 for IERC20;

    bytes32 public DOMAIN_SEPARATOR;
    bytes public constant EIP712_REVISION = bytes("1");
    bytes32 internal constant EIP712_DOMAIN =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

    bytes32 public constant PERMIT_TYPEHASH =
        keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");

    function calculateDomainSeparator(string memory _name) private view returns (bytes32) {
        return keccak256(
            abi.encode(EIP712_DOMAIN, keccak256(bytes(_name)), keccak256(EIP712_REVISION), block.chainid, address(this))
        );
    }

    struct Permit {
        address owner;
        address spender;
        uint256 value;
        uint256 nonce;
        uint256 deadline;
    }

    function getStructHash(Permit memory _permit) internal pure returns (bytes32) {
        return keccak256(
            abi.encode(PERMIT_TYPEHASH, _permit.owner, _permit.spender, _permit.value, _permit.nonce, _permit.deadline)
        );
    }

    function getTypedDataHash(Permit memory _permit) public view returns (bytes32) {
        return keccak256(abi.encodePacked("\x19\x01", DOMAIN_SEPARATOR, getStructHash(_permit)));
    }

    RewardsController constant rewards = RewardsController(0x8164Cc65827dcFe994AB23944CBC90e0aa80bFcb);

    PoolAddressesProviderRegistry constant providerRegistry =
        PoolAddressesProviderRegistry(0xbaA999AC55EAce41CcAE355c77809e68Bb345170);

    address[] addressProvider = providerRegistry.getAddressesProvidersList();
    PoolAddressesProvider provider = PoolAddressesProvider(addressProvider[0]);
    Pool pool = Pool(provider.getPool());

    AaveV3 public aaveV3;
    IERC20 constant DAI = IERC20(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    address user = vm.addr(1);

    function setUp() public {
        aaveV3 = new AaveV3();
        DOMAIN_SEPARATOR = calculateDomainSeparator(DAI.name());
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

    function testWithdraw() public {
        testSupply();

        vm.startPrank(user);
        (address aToken,,) = aaveV3.getReserveData(address(DAI));
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
        uint256 amountDeposited = 10000 * 1e18;
        testSupply();

        console.log("******borrow*******");
        uint256 debtAmount = 500 * 1e18;

        vm.startPrank(user);
        (address aToken,, address variableDebtTokenAddress) = aaveV3.getReserveData(address(DAI));
        assertEq(IERC20(aToken).balanceOf(user), amountDeposited);
        assertEq(IERC20(variableDebtTokenAddress).balanceOf(user), 0);

        (, uint256 totalDebtBase, uint256 availableBorrowsBase,) = aaveV3.getUserAccountData(user);
        console.log("initial totalDebtBase: ", totalDebtBase);
        console.log("initial availableBorrowsBase: ", availableBorrowsBase);

        ICreditDelegationToken(variableDebtTokenAddress).approveDelegation(address(aaveV3), debtAmount);
        assertEq(ICreditDelegationToken(variableDebtTokenAddress).borrowAllowance(user, address(aaveV3)), debtAmount);

        aaveV3.borrow(address(DAI), debtAmount, user);

        (, uint256 totalDebtBase_,,) = aaveV3.getUserAccountData(user);
        console.log("final totalDebtBase: ", totalDebtBase_);

        assertEq(IERC20(variableDebtTokenAddress).balanceOf(user), debtAmount);
        assertEq(DAI.balanceOf(address(aaveV3)), debtAmount);

        vm.stopPrank();
    }

    function testRepay() public {
        testBorrow();

        console.log("******repayment*******");
        uint256 debtAmount = 500 * 1e18;
        uint256 repayAmount = 501 * 1e18;

        vm.startPrank(user);
        (,, address variableDebtTokenAddress) = aaveV3.getReserveData(address(DAI));

        (, uint256 totalDebtBase,,) = aaveV3.getUserAccountData(user);
        console.log("inital totalDebtBase: ", totalDebtBase);

        assertEq(IERC20(variableDebtTokenAddress).balanceOf(user), debtAmount);
        aaveV3.repay(address(DAI), repayAmount, user);

        (, uint256 totalDebtBase_,,) = aaveV3.getUserAccountData(user);

        console.log("final totalDebtBase: ", totalDebtBase_);
        assertEq(IERC20(variableDebtTokenAddress).balanceOf(user), 0);

        vm.stopPrank();
    }

    function testRepayWithATokens() public {
        testBorrow();
        uint256 amountDeposited = 10000 * 1e18;
        uint256 debtAmount = 500 * 1e18;
        uint256 repayAmount = 500 * 1e18;

        console.log("******repayment*******");
        vm.startPrank(user);
        (address aToken,, address variableDebtTokenAddress) = aaveV3.getReserveData(address(DAI));
        uint256 aTokenBalance = IERC20(aToken).balanceOf(user);
        assertEq(aTokenBalance, amountDeposited);
        assertEq(IERC20(variableDebtTokenAddress).balanceOf(user), debtAmount);

        (, uint256 totalDebtBase,,) = aaveV3.getUserAccountData(user);
        console.log("inital totalDebtBase: ", totalDebtBase);

        uint256 interestRateMode = 2;
        pool.repayWithATokens(address(DAI), repayAmount, interestRateMode);

        (, uint256 totalDebtBase_,,) = aaveV3.getUserAccountData(user);
        assertEq(IERC20(aToken).balanceOf(user), aTokenBalance - repayAmount);
        assertEq(IERC20(variableDebtTokenAddress).balanceOf(user), 0);
        console.log("final totalDebtBase: ", totalDebtBase_);
        vm.stopPrank();
    }

    function testFailLiquidationCall() public {
        testBorrow();

        address liquidator = vm.addr(2);
        uint256 amount = 10000 * 1e18;
        deal(address(DAI), liquidator, amount, true);
        assertEq(DAI.balanceOf(liquidator), amount);

        vm.startPrank(liquidator);
        DAI.safeApprove(address(aaveV3), amount);
        aaveV3.liquidationCall(address(DAI), address(DAI), user, liquidator, amount);
        vm.stopPrank();
    }

    function testGetRewardsByAsset() public view {
        (address aToken,,) = aaveV3.getReserveData(address(DAI));
        address[] memory rewardList = aaveV3.getRewardsByAsset(aToken);
        console.log("length: ", rewardList.length);
    }

    function testClaimAllRewardsToSelf() public {
        testSupply();

        (address aToken,,) = aaveV3.getReserveData(address(DAI));
        address[] memory assets = new address[](1);
        assets[0] = aToken;

        vm.startPrank(user);
        (address[] memory rewardsList, uint256[] memory claimedAmounts) = rewards.claimAllRewardsToSelf(assets);
        console.log("rewardsList length: ", rewardsList.length);
        console.log("claimedAmounts length: ", claimedAmounts.length);
        vm.stopPrank();
    }

    function testSupplyWithPermit() public {
        uint256 signerPk = 123;
        address signer = vm.addr(signerPk);
        uint256 amount = 1000 * 1e18;
        deal(address(DAI), signer, amount, true);

        Permit memory _permit = Permit({
            owner: signer,
            spender: address(aaveV3),
            value: amount,
            nonce: DAI.nonces(address(signer)),
            deadline: block.timestamp + 60
        });

        vm.startPrank(signer);
        bytes32 digest = getTypedDataHash(_permit);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPk, digest);
        vm.stopPrank();

        vm.startPrank(user);
        aaveV3.supplyWithPermit(address(DAI), amount, signer, 0, block.timestamp + 60, v, r, s);
        vm.stopPrank();
    }
}
