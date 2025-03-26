// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {LibDiamond} from "../libraries/LibDiamond.sol";

library LibAppStorage {


    struct AppStorage {
        mapping(address => uint256) stakedERC20;
        mapping(address => mapping(uint256 => bool)) stakedERC721;
        mapping(address => mapping(uint256 => uint256)) stakedERC1155;
        mapping(address => mapping(address => uint256)) stakedTimestamps;
        uint256 totalStaked;
        uint256 apr;
        uint256 lockupPeriod;
        uint256 earlyWithdrawalFine;
        address rewardToken;
        address approvedERC20;
        address approvedERC721;
        address approvedERC1155;
    }

    function owner() internal view returns (address owner_) {
        owner_ = LibDiamond.contractOwner();
    }

    function appStorage() internal pure returns (AppStorage storage ds) {
        assembly {
              ds.slot := 0
        }
    }
}
