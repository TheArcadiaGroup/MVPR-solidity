const { ethers } = require("hardhat");
const { use, expect } = require("chai");
const { solidity } = require("ethereum-waffle");

use(solidity);
let owner;
let addr1;
let addr2;
let addrs;
describe("MVPR", function () {
    let myContract;
    let proposalEngineInstance;
    beforeEach(async function () {
        [owner, addr1, addr2, ...addrs] = await ethers.getSigners();
    })

    describe("Reputation", function () {
        it("Should deploy Reputation", async function () {
            const YourContract = await ethers.getContractFactory("Reputation");

            myContract = await YourContract.deploy(owner.address, owner.address, owner.address);
        });
        it("Should add member", async function () {
            const YourContract = await ethers.getContractFactory("Reputation");

            myContract = await YourContract.deploy(owner.address, owner.address, owner.address);
            myContract.addMember(addr1.address);
            expect(await myContract.isMember(addr1.address)).to.be.true;
        });
        it("Should detect non member", async function () {
            const YourContract = await ethers.getContractFactory("Reputation");

            myContract = await YourContract.deploy(owner.address, owner.address, owner.address);
            expect(await myContract.isMember(addr1.address)).to.be.false;
        });
        it("Should mint reputation", async function () {
            const YourContract = await ethers.getContractFactory("Reputation");

            myContract = await YourContract.deploy(owner.address, owner.address, owner.address);
            await myContract.mint(addr1.address, '10');
            expect(await myContract.balanceOf(addr1.address)).to.be.eq(10);
        });
        it("Should burn reputation", async function () {
            const YourContract = await ethers.getContractFactory("Reputation");

            myContract = await YourContract.deploy(owner.address, owner.address, owner.address);
            await myContract.mint(addr1.address, '10');
            expect(await myContract.balanceOf(addr1.address)).to.be.eq(10);
            await myContract.burn(addr1.address, '5');
            expect(await myContract.balanceOf(addr1.address)).to.be.eq(5);
        });
        it("Should grant authorization", async function () {
            // TO DO
        });
        it("Should revoke authorization", async function () {
            // TO DO
        });
    });

    describe("ProposalEngine", function () {
        it("Should deploy ProposalEngine", async function () {
            const proposalEngineContract = await ethers.getContractFactory("ProposalEngine");

            proposalEngineInstance = await proposalEngineContract.deploy(1);
        });
        it("Should create internal proposal", async function () {
            const proposalEngineContract = await ethers.getContractFactory("ProposalEngine");

            proposalEngineInstance = await proposalEngineContract.deploy(1);
            const Reputation = await ethers.getContractFactory("Reputation");

            reputationContract = await Reputation.deploy(owner.address, owner.address, owner.address);
            await reputationContract.mint(addr1.address, '10');
            await reputationContract.mint(owner.address, '10');

            await proposalEngineInstance.setReputation(reputationContract.address);
            const votingEngineFactory = await ethers.getContractFactory("VotingEngine");
            const votingEngine = await votingEngineFactory.deploy(reputationContract.address, proposalEngineInstance.address);
            await proposalEngineInstance.setVotingEngine(votingEngine.address);

            // Policing (>=System Policing Ratio)
            // OP (100%-(Policing% + Sum(Citation%))
            // Citations (<= OP Ratio)
            let newPolicingRatio = 60;
            let newReputationMintingValue = 50;
            let memberQuorum = 2;
            let reputationQuorum = 15;
            let threshold = 50;
            let timeout = 20;
            let voterStakingLimit = 30;
            let voteConfiguration = [memberQuorum, reputationQuorum, threshold, timeout, voterStakingLimit];
            await proposalEngineInstance.connect(addr1).createInternalProposal(newPolicingRatio, newReputationMintingValue, voteConfiguration);
            console.log(await proposalEngineInstance.internalProposals(0));
            ethers.provider.send("evm_increaseTime", [61]);
            await reputationContract.addMember(addr1.address);
            await proposalEngineInstance.connect(addr1).callTransitionVote(0, 0);
            await votingEngine.submitTransitionVote(0, 10, true);
            await votingEngine.connect(addr1).submitTransitionVote(0, 7, false);
            ethers.provider.send("evm_increaseTime", [2000000]);
            await votingEngine.calculateVote(0);

        });
        it("Should create external proposal", async function () {
            const proposalEngineContract = await ethers.getContractFactory("ProposalEngine");

            proposalEngineInstance = await proposalEngineContract.deploy(1);
            const Reputation = await ethers.getContractFactory("Reputation");

            reputationContract = await Reputation.deploy(owner.address, owner.address, owner.address);
            await reputationContract.mint(addr1.address, '10');
            await reputationContract.mint(owner.address, '10');

            await proposalEngineInstance.setReputation(reputationContract.address);
            const votingEngineFactory = await ethers.getContractFactory("VotingEngine");
            const votingEngine = await votingEngineFactory.deploy(reputationContract.address, proposalEngineInstance.address);
            await proposalEngineInstance.setVotingEngine(votingEngine.address);

            let name = 'My First Proposal';
            let storagePointer = 'Storage pointer';
            let storageFingerprint = 'Storage fingerprint';
            let category = 0;
            // Policing (>=System Policing Ratio)
            // OP (100%-(Policing% + Sum(Citation%))
            // Citations (<= OP Ratio)
            let policingRatio = 50;
            let citationsRatio = 20;
            let citations = [1, 2, 3];
            let ratios = [policingRatio, citationsRatio];
            let memberQuorum = 2;
            let reputationQuorum = 15;
            let threshold = 50;
            let timeout = 20;
            let voterStakingLimit = 30;
            let voteConfiguration = [memberQuorum, reputationQuorum, threshold, timeout, voterStakingLimit];
            let milestoneTypes = [99, 98];
            let milestoneProgressPercentages = [50, 50];
            let stakedRep = 0;
            await proposalEngineInstance.connect(addr1).createProposal(name, storagePointer, storageFingerprint, category, citations, ratios, voteConfiguration, milestoneTypes, milestoneProgressPercentages, stakedRep);
            console.log(await proposalEngineInstance.proposalsMapping(0));
            console.log(await proposalEngineInstance.getMilestone(0, 0));
            ethers.provider.send("evm_increaseTime", [61]);
            await reputationContract.addMember(addr1.address);
            await proposalEngineInstance.connect(addr1).callTransitionVote(1, 0);
            await votingEngine.submitTransitionVote(0, 10, true);
            await votingEngine.connect(addr1).submitTransitionVote(0, 7, false);
            ethers.provider.send("evm_increaseTime", [2000000]);
            console.log(await votingEngine.calculateVote(0));
        });

    });
});
