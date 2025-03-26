// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import "../libraries/LibAppStorage.sol";
import "../interfaces/IERC20.sol";

contract AdminFacet {
    function setLockupPeriod(uint256 _lockupPeriod) external {
        LibAppStorage.AppStorage storage s = LibAppStorage.appStorage();
        address owner = LibAppStorage.owner();
        require(msg.sender == owner, "Only admin can set lockup period");
        s.lockupPeriod = _lockupPeriod;
    }

    function setEarlyWithdrawalFine(uint256 _fine) external {
        LibAppStorage.AppStorage storage s = LibAppStorage.appStorage();
        address owner = LibAppStorage.owner();
        require(msg.sender == owner, "Only admin can set fine");
        s.earlyWithdrawalFine = _fine;
    }

    function setAPR(uint256 _apr) external {
        LibAppStorage.AppStorage storage s = LibAppStorage.appStorage();
        address owner = LibAppStorage.owner();
        require(msg.sender == owner, "Only admin can set APR");
        s.apr = _apr;
    }

    function setApprovedERC20(address _token) external {
        LibAppStorage.AppStorage storage s = LibAppStorage.appStorage();
        address owner = LibAppStorage.owner();
        require(msg.sender == owner, "Only admin can set approved ERC20");
        s.approvedERC20 = _token;
    }

    function setApprovedERC721(address _token) external {
        LibAppStorage.AppStorage storage s = LibAppStorage.appStorage();
        address owner = LibAppStorage.owner();
        require(msg.sender == owner, "Only admin can set approved ERC721");
        s.approvedERC721 = _token;
    }

    function setApprovedERC1155(address _token) external {
        LibAppStorage.AppStorage storage s = LibAppStorage.appStorage();
        address owner = LibAppStorage.owner();
        require(msg.sender == owner, "Only admin can set approved ERC1155");
        s.approvedERC1155 = _token;
    }

    function setRewardToken(address _rewardToken) external {
        LibAppStorage.AppStorage storage s = LibAppStorage.appStorage();
        address owner = LibAppStorage.owner();
        require(msg.sender == owner, "Only admin can set reward token");
        s.rewardToken = _rewardToken;
    }

    function getLockupPeriod() external view returns (uint256) {
        return LibAppStorage.appStorage().lockupPeriod;
    }

    function getEarlyWithdrawalFine() external view returns (uint256) {
        return LibAppStorage.appStorage().earlyWithdrawalFine;
    }

    function getAPR() external view returns (uint256) {
        return LibAppStorage.appStorage().apr;
    }

    function getApprovedERC20() external view returns (address) {
        return LibAppStorage.appStorage().approvedERC20;
    }

    function getApprovedERC721() external view returns (address) {
        return LibAppStorage.appStorage().approvedERC721;
    }

    function getApprovedERC1155() external view returns (address) {
        return LibAppStorage.appStorage().approvedERC1155;
    }

    function depositRewards(uint256 amount) external {
        LibAppStorage.AppStorage storage s = LibAppStorage.appStorage();
        address owner = LibAppStorage.owner();
        require(msg.sender == owner, "Only admin can deposit rewards");
        require(
            IERC20(s.rewardToken).transferFrom(
                msg.sender,
                address(this),
                amount
            ),
            "Transfer failed"
        );
    }
}
