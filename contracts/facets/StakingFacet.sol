// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "../libraries/LibAppStorage.sol";
import "../interfaces/IERC20.sol";
import "../interfaces/IERC721.sol";
import "../interfaces/IERC1155.sol";
import "../interfaces/IERC721Receiver.sol";
import "../interfaces/IERC1155Receiver.sol";

contract StakingFacet is IERC721Receiver, IERC1155Receiver {
    event Staked(
        address indexed user,
        address token,
        uint256 amountOrId,
        uint256 timestamp
    );
    event Unstaked(
        address indexed user,
        address token,
        uint256 amountOrId,
        uint256 timestamp
    );
    event RewardsClaimed(address indexed user, uint256 amount);

    function stakeERC20(uint256 amount) external {
        LibAppStorage.AppStorage storage s = LibAppStorage.appStorage();
        require(amount > 0, "Cannot stake zero");
        require(
            IERC20(s.approvedERC20).allowance(msg.sender, address(this)) >=
                amount,
            "Insufficient allowance"
        );
        require(
            IERC20(s.approvedERC20).transferFrom(
                msg.sender,
                address(this),
                amount
            ),
            "Transfer failed"
        );
        s.stakedERC20[msg.sender] += amount;
        s.stakedTimestamps[msg.sender][s.approvedERC20] = block.timestamp;
        s.totalStaked += amount;
        emit Staked(msg.sender, s.approvedERC20, amount, block.timestamp);
    }

    function unstakeERC20(uint256 amount) external {
        LibAppStorage.AppStorage storage s = LibAppStorage.appStorage();
        address owner = LibAppStorage.owner();
        require(s.stakedERC20[msg.sender] >= amount, "Not enough balance");
        uint256 stakedTime = s.stakedTimestamps[msg.sender][s.approvedERC20];
        uint256 fine = (block.timestamp >= stakedTime + s.lockupPeriod)
            ? 0
            : calculateEarlyWithdrawalFine(amount);
        s.stakedERC20[msg.sender] -= amount;
        s.totalStaked -= amount;
        IERC20(s.approvedERC20).transfer(msg.sender, amount - fine);
        if (fine > 0) {
            IERC20(s.approvedERC20).transfer(owner, fine);
        }
        emit Unstaked(msg.sender, s.approvedERC20, amount, block.timestamp);
    }

    function stakeERC721(uint256 tokenId) external {
        LibAppStorage.AppStorage storage s = LibAppStorage.appStorage();
        IERC721(s.approvedERC721).safeTransferFrom(
            msg.sender,
            address(this),
            tokenId
        );
        s.stakedERC721[msg.sender][tokenId] = true;
        s.stakedTimestamps[msg.sender][s.approvedERC721] = block.timestamp;
        emit Staked(msg.sender, s.approvedERC721, tokenId, block.timestamp);
    }

    function unstakeERC721(uint256 tokenId) external {
        LibAppStorage.AppStorage storage s = LibAppStorage.appStorage();
        require(s.stakedERC721[msg.sender][tokenId], "Token not staked");
        uint256 stakedTime = s.stakedTimestamps[msg.sender][s.approvedERC721];
        require(
            block.timestamp >= stakedTime + s.lockupPeriod,
            "Lockup period not over"
        );
        delete s.stakedERC721[msg.sender][tokenId];
        IERC721(s.approvedERC721).safeTransferFrom(
            address(this),
            msg.sender,
            tokenId
        );
        emit Unstaked(msg.sender, s.approvedERC721, tokenId, block.timestamp);
    }

    function stakeERC1155(uint256 tokenId, uint256 amount) external {
        LibAppStorage.AppStorage storage s = LibAppStorage.appStorage();
        require(amount > 0, "Cannot stake zero");
        IERC1155(s.approvedERC1155).safeTransferFrom(
            msg.sender,
            address(this),
            tokenId,
            amount,
            ""
        );
        s.stakedERC1155[msg.sender][tokenId] += amount;
        s.stakedTimestamps[msg.sender][s.approvedERC1155] = block.timestamp;
        emit Staked(msg.sender, s.approvedERC1155, tokenId, block.timestamp);
    }

    function unstakeERC1155(uint256 tokenId, uint256 amount) external {
        LibAppStorage.AppStorage storage s = LibAppStorage.appStorage();
        address owner = LibAppStorage.owner();

        require(
            s.stakedERC1155[msg.sender][tokenId] >= amount,
            "Not enough balance"
        );

        uint256 stakedTime = s.stakedTimestamps[msg.sender][s.approvedERC1155];

        uint256 fine = 0;
        if (block.timestamp < stakedTime + s.lockupPeriod) {
            fine = calculateEarlyWithdrawalFine(amount);

            require(fine <= amount, "Fine exceeds unstake amount");
        }

        s.stakedERC1155[msg.sender][tokenId] -= amount;

        if (s.totalStaked >= amount) {
            s.totalStaked -= amount;
        }

        uint256 amountToTransfer = amount - fine;

        IERC1155(s.approvedERC1155).safeTransferFrom(
            address(this),
            msg.sender,
            tokenId,
            amountToTransfer,
            ""
        );

        // Transfer fine to owner if applicable
        if (fine > 0) {
            IERC1155(s.approvedERC1155).safeTransferFrom(
                address(this),
                owner,
                tokenId,
                fine,
                ""
            );
        }

        emit Unstaked(msg.sender, s.approvedERC1155, tokenId, block.timestamp);
    }

    function claimRewards(address token, uint256 tokenId) external {
        LibAppStorage.AppStorage storage s = LibAppStorage.appStorage();
        uint256 rewards = calculateRewards(msg.sender, token, tokenId);
        require(rewards > 0, "No rewards available");
        IERC20(s.rewardToken).transfer(msg.sender, rewards);
        s.stakedTimestamps[msg.sender][token] = block.timestamp;
        emit RewardsClaimed(msg.sender, rewards);
    }

    function calculateRewards(
        address user,
        address token,
        uint256 tokenId
    ) public view returns (uint256) {
        LibAppStorage.AppStorage storage s = LibAppStorage.appStorage();
        uint256 stakedTime = s.stakedTimestamps[user][token];
        require(stakedTime > 0, "No stake found");

        if (block.timestamp <= stakedTime + 1 days) return 0;

        uint256 daysStaked = (block.timestamp - stakedTime) / 1 days;

        uint256 reward = 0;
        if (s.stakedERC20[user] > 0) {
            reward = (s.stakedERC20[user] * s.apr * daysStaked) / 36500;
        } else if (token == s.approvedERC721 && s.stakedERC721[user][tokenId]) {
            reward = (10 * s.apr * daysStaked) / 36500;
        } else if (
            token == s.approvedERC1155 && s.stakedERC1155[user][tokenId] > 0
        ) {
            reward =
                (s.stakedERC1155[user][tokenId] * s.apr * daysStaked) /
                36500;
        }

        return reward;
    }

    function calculateEarlyWithdrawalFine(
        uint256 amount
    ) public view returns (uint256) {
        LibAppStorage.AppStorage storage s = LibAppStorage.appStorage();
        return (amount * s.earlyWithdrawalFine) / 100;
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    function supportsInterface(
        bytes4 interfaceId
    ) external pure override returns (bool) {
        return
            interfaceId == type(IERC721Receiver).interfaceId ||
            interfaceId == type(IERC1155Receiver).interfaceId;
    }

    function onERC1155Received(
        address,
        address,
        uint256,
        uint256,
        bytes calldata
    ) external pure override returns (bytes4) {
        return IERC1155Receiver.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    ) external pure override returns (bytes4) {
        return IERC1155Receiver.onERC1155BatchReceived.selector;
    }
}
