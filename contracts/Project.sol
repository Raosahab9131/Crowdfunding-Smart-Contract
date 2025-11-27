// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/**
 * @title CrowdfundingPlatform
 * @notice A decentralized platform for creating, funding, and managing crowdfunding campaigns.
 */
contract CrowdfundingPlatform {

    address public admin;
    uint256 public campaignCount;

    struct Campaign {
        uint256 id;
        address creator;
        string title;
        string description;
        uint256 goal;           // Funding goal in wei
        uint256 raised;         // Total amount raised
        uint256 deadline;       // Timestamp of campaign end
        bool completed;
        bool successful;
        mapping(address => uint256) contributions; // User contributions
    }

    mapping(uint256 => Campaign) private campaigns;
    mapping(address => uint256[]) private userCampaigns;

    event CampaignCreated(uint256 indexed id, address indexed creator, string title, uint256 goal, uint256 deadline);
    event ContributionMade(uint256 indexed id, address indexed contributor, uint256 amount);
    event CampaignSuccessful(uint256 indexed id, uint256 totalRaised);
    event CampaignFailed(uint256 indexed id);
    event RefundClaimed(uint256 indexed id, address indexed contributor, uint256 amount);
    event AdminChanged(address indexed oldAdmin, address indexed newAdmin);

    modifier onlyAdmin() {
        require(msg.sender == admin, "CrowdfundingPlatform: NOT_ADMIN");
        _;
    }

    modifier campaignExists(uint256 id) {
        require(id > 0 && id <= campaignCount, "CrowdfundingPlatform: CAMPAIGN_NOT_FOUND");
        _;
    }

    constructor() {
        admin = msg.sender;
    }

    /// @notice Create a new crowdfunding campaign
    function createCampaign(string calldata title, string calldata description, uint256 goal, uint256 duration) external returns (uint256) {
        require(bytes(title).length > 0, "CrowdfundingPlatform: EMPTY_TITLE");
        require(goal > 0, "CrowdfundingPlatform: INVALID_GOAL");
        require(duration > 0, "CrowdfundingPlatform: INVALID_DURATION");

        campaignCount++;
        Campaign storage c = campaigns[campaignCount];
        c.id = campaignCount;
        c.creator = msg.sender;
        c.title = title;
        c.description = description;
        c.goal = goal;
        c.deadline = block.timestamp + duration;
        c.completed = false;
        c.successful = false;

        userCampaigns[msg.sender].push(campaignCount);

        emit CampaignCreated(campaignCount, msg.sender, title, goal, c.deadline);
        return campaignCount;
    }

    /// @notice Contribute to a campaign
    function contribute(uint256 campaignId) external payable campaignExists(campaignId) {
        Campaign storage c = campaigns[campaignId];
        require(block.timestamp < c.deadline, "CrowdfundingPlatform: CAMPAIGN_ENDED");
        require(msg.value > 0, "CrowdfundingPlatform: ZERO_CONTRIBUTION");
        require(!c.completed, "CrowdfundingPlatform: CAMPAIGN_COMPLETED");

        c.contributions[msg.sender] += msg.value;
        c.raised += msg.value;

        emit ContributionMade(campaignId, msg.sender, msg.value);

        // Automatically mark campaign successful if goal is reached
        if (c.raised >= c.goal) {
            c.completed = true;
            c.successful = true;
            payable(c.creator).transfer(c.raised);
            emit CampaignSuccessful(campaignId, c.raised);
        }
    }

    /// @notice Finalize a campaign after deadline (admin can finalize failed campaigns)
    function finalizeCampaign(uint256 campaignId) external campaignExists(campaignId) {
        Campaign storage c = campaigns[campaignId];
        require(block.timestamp >= c.deadline, "CrowdfundingPlatform: CAMPAIGN_NOT_ENDED");
        require(!c.completed, "CrowdfundingPlatform: CAMPAIGN_ALREADY_COMPLETED");

        if (c.raised >= c.goal) {
            c.successful = true;
            payable(c.creator).transfer(c.raised);
            emit CampaignSuccessful(campaignId, c.raised);
        } else {
            c.successful = false;
            emit CampaignFailed(campaignId);
        }

        c.completed = true;
    }

    /// @notice Claim a refund for failed campaign
    function claimRefund(uint256 campaignId) external campaignExists(campaignId) {
        Campaign storage c = campaigns[campaignId];
        require(c.completed && !c.successful, "CrowdfundingPlatform: REFUND_NOT_AVAILABLE");
        uint256 contributed = c.contributions[msg.sender];
        require(contributed > 0, "CrowdfundingPlatform: NO_CONTRIBUTION");

        c.contributions[msg.sender] = 0;
        payable(msg.sender).transfer(contributed);

        emit RefundClaimed(campaignId, msg.sender, contributed);
    }

    /// @notice Get campaign details
    function getCampaign(uint256 campaignId) external view campaignExists(campaignId) returns (
        uint256 id,
        address creator,
        string memory title,
        string memory description,
        uint256 goal,
        uint256 raised,
        uint256 deadline,
        bool completed,
        bool successful
    ) {
        Campaign storage c = campaigns[campaignId];
        return (c.id, c.creator, c.title, c.description, c.goal, c.raised, c.deadline, c.completed, c.successful);
    }

    /// @notice Get user campaigns
    function getUserCampaigns(address user) external view returns (uint256[] memory) {
        return userCampaigns[user];
    }

    /// @notice Change admin
    function changeAdmin(address newAdmin) external onlyAdmin {
        require(newAdmin != address(0), "CrowdfundingPlatform: ZERO_ADMIN");
        emit AdminChanged(admin, newAdmin);
        admin = newAdmin;
    }
}
