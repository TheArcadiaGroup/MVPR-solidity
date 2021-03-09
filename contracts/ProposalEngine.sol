pragma solidity 0.7.5;
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./interfaces/IReputation.sol";
import "./interfaces/IVotingEngine.sol";

contract ProposalEngine {
    using SafeMath for uint256;

    enum ProposalStatus {
        Accepted,
        TransitionVote,
        FullVote,
        Withdrawn,
        Rejected,
        Discussion,
        Pending_Approval
    }

    enum ProposalType {Signaling, Grant, Internal, External}

    struct FundingTranche {
        uint256 fundingTrancheType;
        uint256 amount;
        uint256 reputationAllocation;
    }
    struct Milestone {
        uint256 milestoneType;
        uint256 progressPercentage;
        uint256 result;
        mapping(uint256 => FundingTranche) fundingTranches;
        uint256 fundingTrancheSize;
    }
    struct InternalProposal {
        address proposer;
        uint256 newPolicingRatio;
        uint256 newReputationMintingValue;
        uint256[5] voteConfiguration;
        ProposalStatus status;
        uint256 creationDate;
    }
    InternalProposal[] public internalProposals;
    struct Proposal {
        // Short Name
        string name;
        // Off-chain storage pointer
        string storagePointer;
        // Off-Chain Store Fingerprint (Hash)
        string storageFingerprint;
        // Proposal category
        ProposalType category;
        // Creator of the proposal
        address proposer;
        // array of citations indexes in ProjectExecution
        uint256[] citations;
        // Policing (>=System Policing Ratio)
        // OP (100%-(Policing% + Sum(Citation%))
        // Citations (<= OP Ratio)
        uint256[2] ratios;
        // Member Quorum
        // Reputation Quorum
        // Approve/Reject Threshold
        // Timeout
        // Voter Staking Limits
        uint256[5] voteConfiguration;
        mapping(uint256 => Milestone) milestones;
        uint256 milestoneSize;
        ProposalStatus status;
        uint256 forVotes;
        // Current number of votes in opposition to this proposal
        uint256 againstVotes;
        uint256 creationDate;
        address[] signers;
    }
    mapping(uint256 => Proposal) public proposalsMapping;
    uint256 public numberOfProposals;
    uint256 public minimumStabilityTime;
    uint256 public policingRatio = 50;
    uint256 public reputationAllocationRatio;
    address public reputation;
    address public owner;
    address public votingEngine;
    address public weth;

    event ProposalCreated(
        uint256 proposalIndex,
        address proposer,
        ProposalType category
    );
    event TransitionVote(uint256 proposalType, uint256 proposalIndex);
    event ProposalWithdrawn(uint256 proposalIndex);

    modifier onlyProposalOwner(uint256 proposalId) {
        require(msg.sender == proposalsMapping[proposalId].proposer);
        _;
    }
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    constructor(uint256 _minimumStabilityTime) {
        owner = msg.sender;
        minimumStabilityTime = _minimumStabilityTime;
    }

    function setVotingEngine(address _votingEngine) external onlyOwner {
        votingEngine = _votingEngine;
    }

    function setPolicingRatio(uint256 _policingRatio) external onlyOwner {
        policingRatio = _policingRatio;
    }

    function setReputationAllocationRatio(uint256 _reputationAllocationRatio)
        external
        onlyOwner
    {
        reputationAllocationRatio = _reputationAllocationRatio;
    }

    function setWETH(address _weth) external onlyOwner {
        weth = _weth;
    }

    function callTransitionVote(uint256 proposalType, uint256 proposalIndex)
        external
    {
        require(proposalType <= 1);
        uint256 proposalCreationDate;
        address proposer;
        if (proposalType == 0) {
            InternalProposal storage proposal =
                internalProposals[proposalIndex];
            proposalCreationDate = proposal.creationDate;
            proposer = proposal.proposer;
        } else {
            Proposal storage proposal = proposalsMapping[proposalIndex];
            proposalCreationDate = proposal.creationDate;
            proposer = proposal.proposer;
        }
        require(
            block.timestamp >
                proposalCreationDate + minimumStabilityTime * 1 minutes,
            "A transition vote can only be called after the minimum stability time"
        );
        require(
            proposer == msg.sender,
            "Only proposer can call for a transition vote."
        );
        // OP needs to be KYC'd before calling for a transition vote
        require(
            IReputation(reputation).isMember(proposer),
            "Proposer needs to pass KYC before calling for a vote."
        );

        proposalType == 0
            ? internalProposals[proposalIndex].status = ProposalStatus
                .TransitionVote
            : proposalsMapping[proposalIndex].status = ProposalStatus
            .TransitionVote;
        IVotingEngine(votingEngine).addVote(proposalType, proposalIndex);
        emit TransitionVote(proposalType, proposalIndex);
    }

    function createProposal(
        string memory name,
        string memory storagePointer,
        string memory storageFingerprint,
        uint256 category,
        uint256[] memory citations,
        uint256[2] memory ratios,
        uint256[5] memory voteConfiguration,
        uint256[] memory milestoneTypes,
        uint256[] memory milestoneProgressPercentages,
        uint256 stakedRep
    ) external {
        // The distribution amount for any given milestone must be greater than or equal to the distribution amount of the previous milestone
        // The total sum of all distributions should total the total of all available reputation available for distribution based on the proposal value.

        //     enum ProposalType {Signaling, Grant, Internal, External}
        require(category <= 1, "Only 2 categories are allowed");
        // If member, take reputation, if not take dos & compliance fees
        if (IReputation(reputation).isMember(msg.sender)) {
            require(IReputation(reputation).balanceOf(msg.sender) <= stakedRep);
        }
        // TO DO: Add oracle to get $100 eq in ETH
        // else {
        //     require(weth != address(0), "WETH = 0");
        //     uint wethNeeded;
        //     require(
        //         IERC20(weth).transferFrom(
        //             msg.sender,
        //             IReputation(reputation).compliance(),
        //             wethNeeded
        //         ),
        //         "Couldn't get DOS fee"
        //     );
        // }
        uint256 proposalPolicingRatio = ratios[0];
        uint256 proposalCitationsRatio = ratios[1];
        require(
            proposalPolicingRatio >= policingRatio,
            "Proposed policing ratio must be >= current policing ratio."
        );
        // TO DO: add OP & citations ratios
        ProposalType proposalCategory;
        if (category == 0) proposalCategory = ProposalType.Grant;
        if (category == 1) proposalCategory = ProposalType.Signaling;
        Proposal storage proposal = proposalsMapping[numberOfProposals++];
        proposal.name = name;
        proposal.storagePointer = storagePointer;
        proposal.storageFingerprint = storageFingerprint;
        proposal.category = proposalCategory;
        proposal.proposer = msg.sender;
        proposal.citations = citations;
        proposal.ratios = ratios;
        proposal.voteConfiguration = voteConfiguration;
        proposal.status = ProposalStatus.Discussion;
        proposal.forVotes = 0;
        proposal.againstVotes = 0;
        proposal.creationDate = block.timestamp;
        for (uint256 i = 0; i < milestoneTypes.length; i++) {
            Milestone storage mstone = proposal.milestones[i];
            mstone.progressPercentage = milestoneProgressPercentages[i];
            mstone.result = 2;
            mstone.milestoneType = milestoneTypes[i];
        }
        proposal.milestoneSize = milestoneTypes.length;
        emit ProposalCreated(
            numberOfProposals - 1,
            msg.sender,
            proposalCategory
        );
    }

    function createInternalProposal(
        uint256 newPolicingRatio,
        uint256 newReputationMintingValue,
        uint256[5] calldata voteConfiguration
    ) external {
        internalProposals.push(
            InternalProposal(
                msg.sender,
                newPolicingRatio,
                newReputationMintingValue,
                voteConfiguration,
                ProposalStatus.Pending_Approval,
                block.timestamp
            )
        );
    }

    function withdrawProposal(uint256 proposalIndex) external {
        Proposal storage proposal = proposalsMapping[proposalIndex];
        require(proposal.proposer == msg.sender, "Only OP can withdraw");
        require(proposal.status == ProposalStatus.Discussion);
        proposal.status = ProposalStatus.Withdrawn;
        emit ProposalWithdrawn(proposalIndex);
    }

    function getMilestone(uint256 proposalIndex, uint256 milestoneIndex)
        external
        view
        returns (
            uint256 progressPercentage,
            uint256 result,
            uint256 milestoneType
        )
    {
        progressPercentage = proposalsMapping[proposalIndex].milestones[
            milestoneIndex
        ]
            .progressPercentage;
        result = proposalsMapping[proposalIndex].milestones[milestoneIndex]
            .result;
        milestoneType = proposalsMapping[proposalIndex].milestones[
            milestoneIndex
        ]
            .milestoneType;
    }

    function getProposalMilestoneSize(
        uint256 proposalType,
        uint256 proposalIndex
    ) external view returns (uint256) {
        return proposalsMapping[proposalIndex].milestoneSize;
    }

    function addFundingTranche(
        uint256 proposalIndex,
        uint256 milestoneIndex,
        uint256 fundingTrancheType,
        uint256 amount,
        uint256 reputationAllocation
    ) external {
        Proposal storage proposal = proposalsMapping[proposalIndex];
        Milestone storage milestone = proposal.milestones[milestoneIndex];
        milestone.fundingTranches[
            milestone.fundingTrancheSize
        ] = FundingTranche({
            amount: amount,
            reputationAllocation: reputationAllocation,
            fundingTrancheType: fundingTrancheType
        });
    }

    /**
     * @dev Edits the details of an existing proposal
     * @param proposalIndex Proposal id that details needs to be updated
     * @param _proposalDescHash Proposal description hash having long and short description of proposal.
     */
    function updateProposal(
        uint256 proposalIndex,
        string calldata _proposalTitle,
        string calldata _proposalSD,
        string calldata _proposalDescHash
    ) external onlyProposalOwner(proposalIndex) {
        Proposal storage proposal = proposalsMapping[proposalIndex];
        require(proposal.status == ProposalStatus.Discussion);

        // TO DO
    }

    function getProposalStatus(uint256 proposalType, uint256 proposalIndex)
        external
        view
        returns (ProposalStatus)
    {
        ProposalStatus status;
        proposalType == 0
            ? status = internalProposals[proposalIndex].status
            : status = proposalsMapping[proposalIndex].status;
        return status;
    }

    function getVoteConfiguration(uint256 proposalType, uint256 proposalIndex)
        external
        view
        returns (
            uint256 memberQuorum,
            uint256 reputationQuorum,
            uint256 threshold,
            uint256 timeout,
            uint256 voterStakingLimit
        )
    {
        require(proposalType <= 1);
        uint256[5] memory voteConfiguration;
        if (proposalType == 0) {
            InternalProposal storage proposal =
                internalProposals[proposalIndex];
            voteConfiguration = proposal.voteConfiguration;
        } else {
            Proposal storage proposal = proposalsMapping[proposalIndex];
            voteConfiguration = proposal.voteConfiguration;
        }
        memberQuorum = voteConfiguration[0];
        reputationQuorum = voteConfiguration[1];
        threshold = voteConfiguration[2];
        timeout = voteConfiguration[3];
        voterStakingLimit = voteConfiguration[4];
    }

    function signProposal(uint256 proposalIndex) external {
        // TO DO: Only Compilance can sign proposals
        require(
            IReputation(reputation).isComplianceMember(msg.sender),
            "Only compliance can sign"
        );
        proposalsMapping[proposalIndex].signers.push(msg.sender);
    }

    function setReputation(address _reputation) external {
        // TO DO: Only Compilance can sign proposals
        require(msg.sender == owner, "Only owner");
        reputation = _reputation;
    }

    function getProposalCreationDate(
        uint256 proposalType,
        uint256 proposalIndex
    ) external view returns (uint256 creationDate) {
        proposalType == 0
            ? creationDate = internalProposals[proposalIndex].creationDate
            : creationDate = proposalsMapping[proposalIndex].creationDate;
    }
}
