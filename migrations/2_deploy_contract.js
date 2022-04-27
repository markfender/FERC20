const FERC20 = artifacts.require("FERC20");

module.exports = async function (deployer) {
	/*const lotteryPeriodInSeconds = 240; // 4 minutes
	const ticketCost = 1000000000; // 1 gwei
	const lotteryTicketsLimit = 3;
	const VRFCoordinatorAddress = "0xdD3782915140c8f3b190B5D67eAc6dc5760C46E9"; // VRF Coordinator
	const LINKTokenAddress = "0xa36085F69e2889c224210F603D836748e7dC0088"; // LINK Token contract address*/

	await deployer.deploy(FERC20);
	const instanceFractalToken = await FERC20.deployed();
};