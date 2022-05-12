import { assert, web3, artifacts } from "hardhat";
import { getBalances, increaseTime } from "./utils";


describe("FERC20", () => {
	const toBN = web3.utils.toBN;

	const FERC20 = artifacts.require("FERC20");

	let accounts: string[];
	let accounts_token_balances: number[];
    let contract_0: any;
	let contract_1: any;

	beforeEach(async () => {
		accounts = await web3.eth.getAccounts();
		accounts_token_balances = [100, 150];
		// Create 0 level contract
		contract_0 = await FERC20.new(
			[accounts[0]],
            [],
			{from: accounts[0]}
		);

		// Add delegated member to the 0 level contract
		await contract_0.addVoting([1, accounts[0], accounts_token_balances[0]], {from: accounts[0]});
		await contract_0.vote(0, true, {from: accounts[0]});
		await contract_0.processVoting(0, {from: accounts[0]});

		// Create 1 level contract
		contract_1 = await FERC20.new(
			[accounts[0]],
            [
				[contract_0.address, 60]
			],
			{from: accounts[0]}
		);

		// Verify parent contract to for the level 0 contract
		await contract_0.addVoting([6, contract_1.address, 0], {from: accounts[0]});
		await contract_0.vote(0, true, {from: accounts[0]});
		await contract_0.processVoting(0, {from: accounts[0]});

		// Add member to the 0 level contract
		await contract_0.addVoting([0, accounts[1], accounts_token_balances[1]], {from: accounts[0]});
		await contract_0.vote(0, true, {from: accounts[0]});
		await contract_0.processVoting(0, {from: accounts[0]});
	});

	
	describe("Tree interaction", () => {
		it("getBalance", async function() {
			const balanceAccount0Contract0 = await contract_0.balanceOf(accounts[0]);
			const balanceAccount1Contract0 = await contract_0.balanceOf(accounts[1]);

			assert.equal(balanceAccount0Contract0, 100);
			assert.equal(balanceAccount1Contract0, 150);
		});

		it("getMemberShare", async function () {
			const getMemberShare = await contract_0.getMemberShare(
				accounts[0],
				{from: accounts[0]}
			);

			assert.equal(getMemberShare, 4000);
		});
		
		it("getMemberAmountShare", async function () {
			const getMemberShare = await contract_0.getMemberAmountShare(
				accounts[0],
				50,
				{from: accounts[0]}
			);

			assert.equal(getMemberShare, 2000);
		});

		it("getMemberShare", async function () {
			const getMemberShare = await contract_0.getMemberShare(
				accounts[0],
				{from: accounts[0]}
			);

			assert.equal(getMemberShare, 4000);
		});

		it("getBalancePath", async function () {
			const getShareData = await contract_0.getBalancePath(
				[accounts[0], contract_0.address, contract_1.address],
				{from: accounts[0]}
			);

			assert.equal(getShareData, 240000);
		});

		it("getBalancePath", async function () {
			const getShareData = await contract_0.getAmountPath(
				[accounts[0], contract_0.address, contract_1.address],
				50,
				{from: accounts[0]}
			);

			assert.equal(getShareData, 120000);
		});

		it("getPathToContract", async function () {
			const getShareData = await contract_0.getPathToContract(
				[contract_1.address],
				{from: accounts[0]}
			);

			assert.equal(
				getShareData.toString(),
				[contract_0.address, contract_1.address].toString()
			);
		});

		it("pathTransfer", async function () {
			await contract_0.pathTransfer(
				[accounts[0], contract_0.address, contract_1.address],
				50,
				{from: accounts[0]}
			);

			/*
			assert.equal(
				getShareData.toString(),
				[contract_0.address, contract_1.address].toString()
			);
			*/
		});
    });
    /*
		it("Payer should get lotteryTicket successfuly", async () => {
			const lotteryTicketsBalanceBefore = await lotteryInstance.balanceOf(accounts[1]);
  
			await lotteryInstance.methods["pickLotteryTicket()"]({from: accounts[1], value: ticketCost});
			const lotteryTicketsBalanceAfter = await lotteryInstance.balanceOf(accounts[1]);

			assert.ok(lotteryTicketsBalanceAfter.eq(
				lotteryTicketsBalanceBefore.add(toBN(1))
			));
		});

		it("Payer should get lotteryTicket and change successfuly", async () => {
			const accountBalanceBefore = toBN(await web3.eth.getBalance(accounts[1]));
			const ethToSend = ticketCost.mul(toBN(2)); // Send twice more than a ticket cost

			const getLotteryTicketCall = await lotteryInstance.methods["pickLotteryTicket()"]({from: accounts[1], value: ethToSend});
			const gasUsed = toBN(getLotteryTicketCall.receipt.gasUsed);
			const currentGasPrice = toBN((await web3.eth.getTransaction(getLotteryTicketCall.tx)).gasPrice);
			
			const lotteryTicketsBalanceAfter = await lotteryInstance.balanceOf(accounts[1]);
			const accountBalanceAfter = toBN(await web3.eth.getBalance(accounts[1]));

			assert.ok(
				accountBalanceAfter.eq(
					accountBalanceBefore.sub(
						gasUsed.mul(currentGasPrice)
					).sub(ticketCost)
				)
			);
			assert.ok(lotteryTicketsBalanceAfter.eq(toBN(1)));
		});
	});
*/

});
