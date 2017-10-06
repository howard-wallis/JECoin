pragma solidity ^0.4.8;

import './JECoin.sol';
import './BountyFactory.sol';
import './GithubDetails.sol';

contract Coordinator {
	JECoin coin;
	BountyFactory bountyFactory;

	// All usernames known to the system, either with or without a wallet address
	struct Usernames {
		mapping(string => address) accounts;
		mapping(string => bool) registered;
	}
	Usernames private usernames;

	// Username => bounties that would pay them, including usernames whose address is unknown
	mapping(string => address[]) private bounties;

	// Inject the addresses of the deployed dependencies
	function Coordinator(address JECoinAddress, address bountyFactoryAddress) {
		coin = JECoin(JECoinAddress);
		bountyFactory = BountyFactory(bountyFactoryAddress);
	}

	// Register - Associate a username with an address - user sends ether to this in order to register their git name
	function() payable external returns (bool success) {
		username = msg.data; // TODO decode this

		usernames.accounts[username] = msg.sender;
		usernames.registered[username] = true;

		// Check two things:
		// 1. Are there any bounties associated with this username?
		// 2. If so, of those bounties, are any completed and waiting to execute? Execute them.
		address[] bountyAddresses = bounties[username];
		for (uint i = 0; i < bountyAddresses.length; i++) {
			Bounty bounty = Bounty(bountyAddresses[i]);
			bounty.payee = msg.sender;
			executeBounty(bounty);
		}

		// TODO Return any eth sent to this address
	}


	// Update a username
	function changeUsername(string oldUsername, string newUsername) external returns (bool success) {
		if (usernames.accounts[oldUsername] == address(0x0)) {
			return false;
		}
		usernames.accounts[newUsername] = usernames.accounts[oldUsername];
		usernames.accounts[oldUsername] = address(0x0);
		return true;
	}

	// Returns 0x0 if not registered
	function addressOf(string username) constant returns (address a) {
		return usernames.accounts[username];
	}

	// Disassociate an address to a username
	function remove(string username) external {
		usernames.accounts[username] = address(0x0);
		usernames.registered[username] = false;
	}

	// Called by the server when PR is created
	function createBounty(string githubOwner, string githubRepo, uint pullRequest, string pullRequestOpener) external {
		Bounty bounty = bountyFactory.newBounty(string githubOwner, string githubRepo, uint pullRequest, string pullRequestOpener);
		bounties[username] = bounty;
	}

	// Called by the server when PR is merged
	function executeBountyOnMerge(string githubOwner, string githubRepo, uint pullRequest, string pullRequestOpener) external {
		address bountyAddress = getBounty(githubOwner, githubRepo, pullRequest, pullRequestOpener);
		Bounty bounty = Bounty(bountyAddress);
		bounty.finish();
		executeBounty(bounty);
	}

	// Get the address of the bounty for a pull request
	function getBounty(string githubOwner, string githubRepo, uint pullRequest, string pullRequestOpener) external returns (address bountyAddress) {
		address[] bountyAddresses = bounties[pullRequestOpener];
		GithubDetails githubDetails = GithubDetails(githubOwner, githubRepo, pullRequest, pullRequestOpener);
		for (uint i = 0; i < bountyAddresses.length; i++) {
			Bounty bounty = Bounty(bountyAddresses[i]);
			if (githubDetails.match(bounty.githubDetails)) {
				return bountyAddresses[i];
			}
		}
	}

	// Number of JECoins owned by the bounty
	function getBountyBalance(string githubOwner, string githubRepo, uint pullRequest, string pullRequestOpener) external returns (uint JECoinBalance) {
		address bountyAddress = getBounty(githubOwner, githubRepo, pullRequest, pullRequestOpener);
		return coin.balanceOf(bountyAddress);
	}

	// If the bounty is complete, pay it out and delete the bounty
	function executeBounty(Bounty bounty) returns (bool success) {
		if (!bounty.complete || bounty.payee == address(0x0)) {
			return false;
		}
		// Pay the creator of the bounty
		coin.transfer(bounty.payee, bounty.balance());
		
		// Remove the bounty from our store
		address[] usernameBounties = bounties[bounty.githubDetails.pullRequestOpener];
		for (uint i = 0; i < usernameBounties.length; i++) {
			if (usernameBounties[i] == address(bounty)) {
				usernameBounties[i] = address(0x0);
				break;
			}
		}

		// Destroy the bounty
		bounty.kill(address(this));
		return true;
	}
}