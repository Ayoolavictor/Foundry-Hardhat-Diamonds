// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../contracts/facets/AdminFacet.sol";
import "../contracts/facets/StakingFacet.sol";
import "../contracts/facets/DiamondCutFacet.sol";
import "../contracts/libraries/LibAppStorage.sol";
import "../contracts/interfaces/IDiamondCut.sol";
import "../contracts/Diamond.sol";
import "./helpers/MockERC20.sol";
import "./helpers/MockERC721.sol";
import "./helpers/MockERC1155.sol";

contract StakingTest is Test, IDiamondCut {
    AdminFacet adminFacet;
    StakingFacet stakingFacet;
    MockERC20 rewardToken;
    MockERC20 erc20;
    MockERC721 erc721;
    MockERC1155 erc1155;
    address owner;
    address user;
    Diamond diamond;
    DiamondCutFacet dCutFacet;

    function setUp() public {
        owner = address(this);
        user = address(0x123);

        rewardToken = new MockERC20(owner);
        erc20 = new MockERC20(owner);
        erc721 = new MockERC721(owner);
        erc1155 = new MockERC1155(owner);

        dCutFacet = new DiamondCutFacet();
        diamond = new Diamond(owner, address(dCutFacet));

        // Deploy AdminFacet and attach it to the Diamond
        adminFacet = new AdminFacet();
        stakingFacet = new StakingFacet();

        FacetCut[] memory cut = new FacetCut[](2);

        cut[0] = FacetCut({
            facetAddress: address(adminFacet),
            action: FacetCutAction.Add,
            functionSelectors: new bytes4[](14)
        });
        cut[0].functionSelectors[0] = 0x8bdf67f2; // depositRewards(uint256)
        cut[0].functionSelectors[1] = 0x854303cf; // setAPR(uint256)
        cut[0].functionSelectors[2] = 0x41cbceb1; // setApprovedERC1155(address)
        cut[0].functionSelectors[3] = 0x314b6256; // setApprovedERC20(address)
        cut[0].functionSelectors[4] = 0x575fa71b; // setApprovedERC721(address)
        cut[0].functionSelectors[5] = 0x449a4c13; // setEarlyWithdrawalFine(uint256)
        cut[0].functionSelectors[6] = 0xc771c390; // setLockupPeriod(uint256)
        cut[0].functionSelectors[7] = 0x8aee8127; // setRewardToken(address)
        cut[0].functionSelectors[8] = 0xc89d5b8b; // getAPR()
        cut[0].functionSelectors[9] = 0x412abed4; // getApprovedERC1155()
        cut[0].functionSelectors[10] = 0x646f30bc; // getApprovedERC20()
        cut[0].functionSelectors[11] = 0x4bdcfa8d; // getApprovedERC721()
        cut[0].functionSelectors[12] = 0x7aff33c6; // getEarlyWithdrawalFine()
        cut[0].functionSelectors[13] = 0xb54d321d; // getLockupPeriod()

        cut[1] = FacetCut({
            facetAddress: address(stakingFacet),
            action: FacetCutAction.Add,
            functionSelectors: new bytes4[](13)
        });
        cut[1].functionSelectors[0] = 0x85686af1; // calculateEarlyWithdrawalFine(uint256)
        cut[1].functionSelectors[1] = 0x8b4d7577; // calculateRewards(address,address,uint256)
        cut[1].functionSelectors[2] = 0x9a99b4f0; // claimRewards(address,uint256)
        cut[1].functionSelectors[3] = 0x6fafa1e9; // stakeERC1155(uint256,uint256)
        cut[1].functionSelectors[4] = 0xcc7ef509; // stakeERC20(uint256)
        cut[1].functionSelectors[5] = 0x43fc018e; // stakeERC721(uint256)
        cut[1].functionSelectors[6] = 0x634e575c; // unstakeERC1155(uint256,uint256)
        cut[1].functionSelectors[7] = 0x7dfae334; // unstakeERC20(uint256)
        cut[1].functionSelectors[8] = 0x2291d991; // unstakeERC721(uint256)
        cut[1].functionSelectors[9] = 0x150b7a02; // onERC721Received(address,address,uint256,bytes)
        cut[1].functionSelectors[10] = 0xf23a6e61; // onERC1155Received(address,address,uint256,uint256,bytes)
        cut[1].functionSelectors[11] = 0xbc197c81; // onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)
        cut[1].functionSelectors[12] = 0x01ffc9a7; // supportsInterface(bytes4)

        IDiamondCut(address(diamond)).diamondCut(cut, address(0x0), "");
        adminFacet = AdminFacet(address(diamond));
        stakingFacet = StakingFacet(address(diamond));

        vm.startPrank(owner);
        adminFacet.setApprovedERC20(address(erc20));
        adminFacet.setApprovedERC721(address(erc721));
        adminFacet.setApprovedERC1155(address(erc1155));
        adminFacet.setEarlyWithdrawalFine(10);
        adminFacet.setAPR(1000);
        adminFacet.setRewardToken(address(rewardToken));
        adminFacet.setLockupPeriod(1 days);
        rewardToken.mint(address(adminFacet), 10000 ether);
        vm.stopPrank();
    }

    function testSetLockupPeriod() public {
        adminFacet.setLockupPeriod(7 days);
        assertEq(
            adminFacet.getLockupPeriod(),
            7 days,
            "Lockup period not set correctly"
        );
    }

    function testSetLockupPeriodUnauthorized() public {
        vm.prank(user);
        vm.expectRevert("Only admin can set lockup period");
        adminFacet.setLockupPeriod(7 days);
    }

    function testSetEarlyWithdrawalFine() public {
        adminFacet.setEarlyWithdrawalFine(15);
        assertEq(
            adminFacet.getEarlyWithdrawalFine(),
            15,
            "Early withdrawal fine not set correctly"
        );
    }

    function testSetEarlyWithdrawalFineUnauthorized() public {
        vm.prank(user);
        vm.expectRevert("Only admin can set fine");
        adminFacet.setEarlyWithdrawalFine(15);
    }

    function testSetAPR() public {
        adminFacet.setAPR(1500);
        assertEq(adminFacet.getAPR(), 1500, "APR not set correctly");
    }

    function testSetAPRUnauthorized() public {
        vm.prank(user);
        vm.expectRevert("Only admin can set APR");
        adminFacet.setAPR(1500);
    }

    function testSetApprovedERC20() public {
        address testToken = address(0x456);
        adminFacet.setApprovedERC20(testToken);
        assertEq(
            adminFacet.getApprovedERC20(),
            testToken,
            "Approved ERC20 not set correctly"
        );
    }

    function testSetApprovedERC20Unauthorized() public {
        vm.prank(user);
        vm.expectRevert("Only admin can set approved ERC20");
        adminFacet.setApprovedERC20(address(0x456));
    }

    function testSetApprovedERC721() public {
        address testToken = address(0x789);
        adminFacet.setApprovedERC721(testToken);
        assertEq(
            adminFacet.getApprovedERC721(),
            testToken,
            "Approved ERC721 not set correctly"
        );
    }

    function testSetApprovedERC721Unauthorized() public {
        vm.prank(user);
        vm.expectRevert("Only admin can set approved ERC721");
        adminFacet.setApprovedERC721(address(0x789));
    }

    function testSetApprovedERC1155() public {
        address testToken = address(0xABC);
        adminFacet.setApprovedERC1155(testToken);
        assertEq(
            adminFacet.getApprovedERC1155(),
            testToken,
            "Approved ERC1155 not set correctly"
        );
    }

    function testSetApprovedERC1155Unauthorized() public {
        vm.prank(user);
        vm.expectRevert("Only admin can set approved ERC1155");
        adminFacet.setApprovedERC1155(address(0xABC));
    }

    function testSetRewardToken() public {
        address testRewardToken = address(rewardToken);
        adminFacet.setRewardToken(testRewardToken);
    }

    function testSetRewardTokenUnauthorized() public {
        vm.prank(user);
        vm.expectRevert("Only admin can set reward token");
        adminFacet.setRewardToken(address(rewardToken));
    }

    function testDepositRewards() public {
        rewardToken.mint(owner, 1000 ether);

        adminFacet.setRewardToken(address(rewardToken));

        rewardToken.approve(address(adminFacet), 1000 ether);

        adminFacet.depositRewards(1000 ether);
    }

    function testDepositRewardsUnauthorized() public {
        rewardToken.mint(user, 1000 ether);

        vm.prank(user);
        vm.expectRevert("Only admin can deposit rewards");
        adminFacet.depositRewards(1000 ether);
    }

    function testGetters() public {
        adminFacet.setLockupPeriod(7 days);
        adminFacet.setEarlyWithdrawalFine(10);
        adminFacet.setAPR(1000);

        assertEq(
            adminFacet.getLockupPeriod(),
            7 days,
            "Getter for lockup period failed"
        );
        assertEq(
            adminFacet.getEarlyWithdrawalFine(),
            10,
            "Getter for early withdrawal fine failed"
        );
        assertEq(adminFacet.getAPR(), 1000, "Getter for APR failed");
    }

    function testUnsupportedInterfaceCheck() public view {
        assertTrue(
            stakingFacet.supportsInterface(type(IERC721Receiver).interfaceId),
            "Should support ERC721 interface"
        );
        assertTrue(
            stakingFacet.supportsInterface(type(IERC1155Receiver).interfaceId),
            "Should support ERC1155 interface"
        );
        assertFalse(
            stakingFacet.supportsInterface(0x12345678),
            "Should not support random interface"
        );
    }

    function testUnstakeERC20BeforeLockupPeriod() public {
        vm.startPrank(owner);
        erc20.mint(user, 100 ether);
        vm.stopPrank();

        vm.startPrank(user);
        erc20.approve(address(stakingFacet), 100 ether);
        stakingFacet.stakeERC20(100 ether);

        uint256 balanceBefore = erc20.balanceOf(user);
        uint256 fineAmount = stakingFacet.calculateEarlyWithdrawalFine(
            100 ether
        );

        stakingFacet.unstakeERC20(100 ether);

        uint256 balanceAfter = erc20.balanceOf(user);
        assertEq(
            balanceAfter,
            balanceBefore + 100 ether - fineAmount,
            "Early withdrawal fine not applied correctly"
        );
        vm.stopPrank();
    }

    function testUnstakeERC721BeforeLockupPeriod() public {
        vm.startPrank(owner);
        erc721.safeMint(user, 1);
        vm.stopPrank();

        vm.startPrank(user);
        erc721.setApprovalForAll(address(stakingFacet), true);
        stakingFacet.stakeERC721(1);

        vm.expectRevert("Lockup period not over");
        stakingFacet.unstakeERC721(1);
        vm.stopPrank();
    }

    function testUnstakeInvalidERC721() public {
        vm.expectRevert("Token not staked");
        vm.prank(user);
        stakingFacet.unstakeERC721(1);
    }

    function testStakeZeroERC20() public {
        vm.expectRevert("Cannot stake zero");
        vm.prank(user);
        stakingFacet.stakeERC20(0);
    }

    function testStakeZeroERC1155() public {
        vm.expectRevert("Cannot stake zero");
        vm.prank(user);
        stakingFacet.stakeERC1155(1, 0);
    }

    function testCalculateRewardsNoStake() public {
        vm.expectRevert("No stake found");
        stakingFacet.calculateRewards(user, address(erc20), 0);
    }

    function testCalculateRewardsImmediately() public {
        // Stake ERC20 tokens
        vm.startPrank(owner);
        erc20.mint(user, 100 ether);
        vm.stopPrank();

        vm.startPrank(user);
        erc20.approve(address(stakingFacet), 100 ether);
        stakingFacet.stakeERC20(100 ether);
        vm.stopPrank();

        uint256 rewards = stakingFacet.calculateRewards(
            user,
            address(erc20),
            0
        );
        assertEq(rewards, 0, "Rewards should be zero if claimed immediately");
    }

    function testERC721Received() public view {
        bytes4 result = stakingFacet.onERC721Received(
            address(0),
            address(0),
            1,
            ""
        );
        assertEq(
            result,
            IERC721Receiver.onERC721Received.selector,
            "Incorrect ERC721 received selector"
        );
    }

    function testERC1155Received() public view {
        bytes4 result = stakingFacet.onERC1155Received(
            address(0),
            address(0),
            1,
            1,
            ""
        );
        assertEq(
            result,
            IERC1155Receiver.onERC1155Received.selector,
            "Incorrect ERC1155 received selector"
        );
    }

    function testERC1155BatchReceived() public view {
        uint256[] memory ids = new uint256[](1);
        ids[0] = 1;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;

        bytes4 result = stakingFacet.onERC1155BatchReceived(
            address(0),
            address(0),
            ids,
            amounts,
            ""
        );
        assertEq(
            result,
            IERC1155Receiver.onERC1155BatchReceived.selector,
            "Incorrect ERC1155 batch received selector"
        );
    }

    function testClaimRewardsERC20() public {
        vm.startPrank(owner);
        erc20.mint(user, 100 ether);
        vm.stopPrank();

        vm.startPrank(user);
        erc20.approve(address(stakingFacet), 100 ether);
        stakingFacet.stakeERC20(100 ether);
        vm.stopPrank();

        vm.warp(block.timestamp + 10 days);

        uint256 expectedRewards = stakingFacet.calculateRewards(
            user,
            address(erc20),
            0
        );

        vm.startPrank(owner);
        rewardToken.mint(address(adminFacet), expectedRewards);
        vm.stopPrank();

        vm.startPrank(user);
        stakingFacet.claimRewards(address(erc20), 0);

        assertGt(
            rewardToken.balanceOf(user),
            0,
            "User should have received rewards"
        );
        assertLt(
            rewardToken.balanceOf(user),
            expectedRewards + 1,
            "Rewards calculation seems incorrect"
        );
        vm.stopPrank();
    }

    function testClaimRewardsERC721() public {
        vm.startPrank(owner);
        erc721.safeMint(user, 1);
        vm.stopPrank();

        vm.startPrank(user);
        erc721.setApprovalForAll(address(stakingFacet), true);
        stakingFacet.stakeERC721(1);

        vm.warp(block.timestamp + 10 days);

        uint256 expectedRewards = stakingFacet.calculateRewards(
            user,
            address(erc721),
            1
        );
        vm.stopPrank();

        vm.startPrank(owner);
        rewardToken.mint(address(adminFacet), expectedRewards);
        vm.stopPrank();

        vm.startPrank(user);
        stakingFacet.claimRewards(address(erc721), 1);

        assertGt(
            rewardToken.balanceOf(user),
            0,
            "User should have received rewards"
        );
        assertLt(
            rewardToken.balanceOf(user),
            expectedRewards + 1,
            "Rewards calculation seems incorrect"
        );
        vm.stopPrank();
    }

    function testClaimRewardsERC1155() public {
        vm.startPrank(owner);
        erc1155.mint(user, 1, 10, "");
        vm.stopPrank();

        vm.startPrank(user);
        erc1155.setApprovalForAll(address(stakingFacet), true);
        stakingFacet.stakeERC1155(1, 10);
        vm.stopPrank();

        vm.warp(block.timestamp + 10 days);

        uint256 expectedRewards = stakingFacet.calculateRewards(
            user,
            address(erc1155),
            1
        );

        vm.startPrank(owner);
        rewardToken.mint(address(adminFacet), expectedRewards);
        vm.stopPrank();

        vm.startPrank(user);
        stakingFacet.claimRewards(address(erc1155), 1);

        assertGt(
            rewardToken.balanceOf(user),
            0,
            "User should have received rewards"
        );
        assertLt(
            rewardToken.balanceOf(user),
            expectedRewards + 1,
            "Rewards calculation seems incorrect"
        );
        vm.stopPrank();
    }

    function testCalculateEarlyWithdrawalFine() public {
        adminFacet.setEarlyWithdrawalFine(10);

        uint256 smallAmount = 100 ether;
        uint256 largeAmount = 1000 ether;

        uint256 smallFine = stakingFacet.calculateEarlyWithdrawalFine(
            smallAmount
        );
        assertEq(
            smallFine,
            10 ether,
            "Fine calculation incorrect for small amount"
        );

        uint256 largeFine = stakingFacet.calculateEarlyWithdrawalFine(
            largeAmount
        );
        assertEq(
            largeFine,
            100 ether,
            "Fine calculation incorrect for large amount"
        );

        adminFacet.setEarlyWithdrawalFine(5);
        uint256 smallerFine = stakingFacet.calculateEarlyWithdrawalFine(
            smallAmount
        );
        assertEq(
            smallerFine,
            5 ether,
            "Fine calculation incorrect after changing fine percentage"
        );
    }

    function testCannotClaimRewardsWithoutStake() public {
        vm.expectRevert("No stake found");
        vm.prank(user);
        stakingFacet.claimRewards(address(erc20), 0);
    }

    function testCannotClaimRewardsBeforeStakingPeriod() public {
        vm.startPrank(owner);
        erc20.mint(user, 100 ether);
        vm.stopPrank();

        vm.startPrank(user);
        erc20.approve(address(stakingFacet), 100 ether);
        stakingFacet.stakeERC20(100 ether);
        vm.stopPrank();

        vm.expectRevert("No rewards available");
        vm.prank(user);
        stakingFacet.claimRewards(address(erc20), 0);
    }

    function testUnstakeERC20InsufficientBalance() public {
        vm.startPrank(owner);
        erc20.mint(user, 100 ether);
        vm.stopPrank();

        vm.startPrank(user);
        erc20.approve(address(stakingFacet), 100 ether);
        stakingFacet.stakeERC20(50 ether);

        vm.expectRevert("Not enough balance");
        stakingFacet.unstakeERC20(100 ether);
        vm.stopPrank();
    }

    function testUnstakeERC1155InsufficientBalance() public {
        vm.startPrank(owner);
        erc1155.mint(user, 1, 10, "");
        vm.stopPrank();

        vm.startPrank(user);
        erc1155.setApprovalForAll(address(stakingFacet), true);
        stakingFacet.stakeERC1155(1, 10);

        vm.expectRevert("Not enough balance");
        stakingFacet.unstakeERC1155(1, 20);
        vm.stopPrank();
    }

    function testUnstakeERC20AfterLockupPeriod() public {
        vm.startPrank(owner);
        erc20.mint(user, 100 ether);
        vm.stopPrank();

        vm.startPrank(user);
        erc20.approve(address(stakingFacet), 100 ether);
        stakingFacet.stakeERC20(100 ether);

        vm.warp(block.timestamp + 2 days);

        uint256 balanceBefore = erc20.balanceOf(user);
        stakingFacet.unstakeERC20(100 ether);
        uint256 balanceAfter = erc20.balanceOf(user);

        assertEq(
            balanceAfter,
            balanceBefore + 100 ether,
            "Full amount should be returned after lockup"
        );
        vm.stopPrank();
    }

    function testUnstakeERC1155AfterLockupPeriod() public {
        vm.startPrank(owner);
        erc1155.mint(user, 1, 10, "");
        vm.stopPrank();

        vm.startPrank(user);
        erc1155.setApprovalForAll(address(stakingFacet), true);
        stakingFacet.stakeERC1155(1, 10);

        vm.warp(block.timestamp + 2 days);

        uint256 initialUserBalance = erc1155.balanceOf(user, 1);

        stakingFacet.unstakeERC1155(1, 10);

        uint256 finalUserBalance = erc1155.balanceOf(user, 1);
        assertEq(
            finalUserBalance,
            initialUserBalance + 10,
            "User should receive full amount after lockup period"
        );
        vm.stopPrank();
    }

    function testClaimRewardsWithDifferentStakeDurations() public {
        vm.startPrank(owner);
        erc20.mint(user, 100 ether);
        vm.stopPrank();

        vm.startPrank(user);
        erc20.approve(address(stakingFacet), 100 ether);
        stakingFacet.stakeERC20(100 ether);
        vm.stopPrank();

        uint256[] memory stakeDurations = new uint256[](3);
        stakeDurations[0] = 5 days;
        stakeDurations[1] = 15 days;
        stakeDurations[2] = 30 days;

        for (uint i = 0; i < stakeDurations.length; i++) {
            vm.startPrank(owner);
            vm.warp(block.timestamp + stakeDurations[i]);
            uint256 expectedRewards = stakingFacet.calculateRewards(
                user,
                address(erc20),
                0
            );
            rewardToken.mint(address(adminFacet), expectedRewards);
            vm.stopPrank();

            vm.startPrank(user);
            uint256 balanceBefore = rewardToken.balanceOf(user);
            stakingFacet.claimRewards(address(erc20), 0);
            uint256 balanceAfter = rewardToken.balanceOf(user);

            assertGt(
                balanceAfter,
                balanceBefore,
                "Rewards should increase with longer staking duration"
            );
            vm.stopPrank();
        }
    }

    function diamondCut(
        FacetCut[] calldata _diamondCut,
        address _init,
        bytes calldata _calldata
    ) external override {}
}
