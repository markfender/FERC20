import { assert, web3, artifacts } from "hardhat";
import { getBalances, increaseTime } from "./utils";
import { IEventWinner } from "./types";

const truffleAssert = require('truffle-assertions');

// todo: do not duplicate randomness request


describe("Lottery", () => {
	const toBN = web3.utils.toBN;

	const Lottery = artifacts.require("Lottery");
	const LinkTokenMock = artifacts.require("test/LinkTokenMock");
	const CoordinatorMock = artifacts.require("test/CoordinatorMock");

	const lotteryPeriodInSeconds = 120; // 2 minutes
	const timeAfterLotteryHasFinished = lotteryPeriodInSeconds * 2;
	const ticketCost = toBN(2).mul(toBN(1e18)); // 2 eth
	const lotteryTicketsLimit = 3; // 3 tickets

	let accounts: string[];
	let owner: string;
	let linkTokenMockInstance: any; // todo: Replace with proper types
	let coordinatorMockInstance: any;
	let lotteryInstance: any;

	beforeEach(async () => {
		accounts = await web3.eth.getAccounts();
		owner = accounts[0];

		// Create LINK mock
		linkTokenMockInstance = await LinkTokenMock.new(
			owner,
			toBN(1e18),
			{from: owner}
		);

		// Create VRFCoordinator Mock
		coordinatorMockInstance = await CoordinatorMock.new(
			linkTokenMockInstance.address, // LINK token mock
			{from: owner}
		);

		// Create Lottery instance
		lotteryInstance = await Lottery.new(
			coordinatorMockInstance.address,
			linkTokenMockInstance.address,
			ticketCost, //_lotteryTicketPrice in wei
			lotteryPeriodInSeconds, // _lotteryPeriod seconds
			lotteryTicketsLimit, // _lotteryTicketsLimit num of tickets
			{from: owner}
		);

		await linkTokenMockInstance.transfer(
			lotteryInstance.address,
			toBN(1e18), // 1 LINK token
			{from: owner}
		);
	});

	describe("buyLotteryTicket (for Eth)", () => {
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

	describe("finishLottery", () => {
		it("If no one joined the lottery the lottery creator should be the winner", async () => {
			increaseTime(web3, timeAfterLotteryHasFinished); // increase time to finish lottey

			await lotteryInstance.methods["finishLottery()"]({from: accounts[1]});

			// Check if RandomnessRequest event was fired
			const hasRandomnessRequest =
				(await coordinatorMockInstance.getPastEvents())
					.map((item: any) => item.event).includes("RandomnessRequest");

			const resultCallBack = await coordinatorMockInstance.callBackWithRandomness(
				"0x", 0, lotteryInstance.address,
				{from: owner}
			);

			const callBackTransactionResult = await truffleAssert.createTransactionResult(lotteryInstance, resultCallBack.tx);

			assert.ok(hasRandomnessRequest);
			truffleAssert.eventEmitted(callBackTransactionResult, "LotteryIsFinished", (eventData: IEventWinner) => {
				return eventData["winner"] == owner;
			});
		});

		it("Lottery should choose random winner correctly", async () => {
			for(let i = 1; i <= lotteryTicketsLimit; i++)
				await lotteryInstance.methods["pickLotteryTicket()"]({from: accounts[i], value: ticketCost});
			
			increaseTime(web3, timeAfterLotteryHasFinished);

			const accountsBalancesBefore = await getBalances(web3, accounts);

			await lotteryInstance.methods["finishLottery()"]({from: owner});
			// Check if RandomnessRequest event was fired
			const hasRandomnessRequest =
				(await coordinatorMockInstance.getPastEvents())
					.map((item: any) => item.event).includes("RandomnessRequest");

			const resultCallBack = await coordinatorMockInstance.callBackWithRandomness(
				"0x", 0, lotteryInstance.address, // 0 is a mock randomness result
				{from: owner}
			);
			const callBackTransactionResult = await truffleAssert.createTransactionResult(lotteryInstance, resultCallBack.tx);
			
			const accountsBalancesAfter = await getBalances(web3, accounts);
			//chech who is the winner according to the balance change
			let winnerAccount: string = "";
			// Start from i = 1, to exclude the lottery creator
			for(let i = 1; i< accounts.length; i++) {
				if(parseInt(accountsBalancesAfter[i]) - parseInt(accountsBalancesBefore[i]) > 0) {
					winnerAccount = accounts[i];
					break;
				}
			}

			assert.ok(hasRandomnessRequest);
			truffleAssert.eventEmitted(callBackTransactionResult, "LotteryIsFinished", (eventData: IEventWinner) => {
				return eventData["winner"] == winnerAccount && owner != winnerAccount;
			});
		});

		it("Lottery should not be finished until the specified time come", async () => {
			await truffleAssert.reverts(
				lotteryInstance.methods["finishLottery()"]({from: accounts[1]}),
				"Lottery is not finished"
			);
		});
	});

	describe("restartLottery", () => {
		it("It should burn old lottery tickets on restart", async () => {
			for(let i = 1; i <= lotteryTicketsLimit; i++)
				await lotteryInstance.methods["pickLotteryTicket()"]({from: accounts[i], value: ticketCost});

			const ticketBalanceBeforeLotterIsFinished = await lotteryInstance.balanceOf(accounts[1]);

			increaseTime(web3, timeAfterLotteryHasFinished);
			// Finish lottery and create events
			await lotteryInstance.methods["finishLottery()"]({from: owner});
			// Imitate randomness callback
			await coordinatorMockInstance.callBackWithRandomness(
				"0x", 0, lotteryInstance.address, // 0 is a mock randomness result
				{from: owner}
			);
			
			// Restart lottery
			await lotteryInstance.restartLottery(
				ticketCost, //_lotteryTicketPrice in wei
				lotteryPeriodInSeconds, // _lotteryPeriod seconds
				lotteryTicketsLimit, // _lotteryTicketsLimit num of tickets
				{from: owner}
			);

			const ticketBalanceAfterLotterIsFinished = await lotteryInstance.balanceOf(accounts[1]);
			assert.ok(
				ticketBalanceBeforeLotterIsFinished.toNumber() === 1 &&
				ticketBalanceAfterLotterIsFinished.toNumber() === 0
			)
		});
	});

	describe("destroy", () => {
		it("Should be able to call destroy function successfully by Owner", async () => {
			increaseTime(web3, timeAfterLotteryHasFinished); // increase time to finish lottery

			await lotteryInstance.methods["finishLottery()"]({from: owner});

			// Fire randomness callback
			await coordinatorMockInstance.callBackWithRandomness(
				"0x", 0, lotteryInstance.address,
				{from: owner}
			);

			const linkBalanceBefore = await linkTokenMockInstance.balanceOf(owner);

			await lotteryInstance.destroy({from: owner});
			const lotteryCodeAfterSelfdestruct = await web3.eth.getCode(lotteryInstance.address);
		
			const linkBalanceAfter = await linkTokenMockInstance.balanceOf(owner);
			assert.equal(lotteryCodeAfterSelfdestruct, "0x");
			assert.ok(linkBalanceAfter > linkBalanceBefore);
		});

		it("Should fail destroy function call after Owner call durnig the lottery", async () => {
			await truffleAssert.reverts(
				lotteryInstance.destroy({from: owner}),
				"Impossible to destroy contract until the lottery is not finished"
			);
		});

		it("Should fail destroy function call after none Owner call", async () => {
			await truffleAssert.reverts(
				lotteryInstance.destroy({from: accounts[3]}),
				"Ownable: caller is not the owner"
			);
		});
	});
});
