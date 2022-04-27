export const increaseTime = (web3: any, seconds: number) => {
	web3.currentProvider.send({
		jsonrpc: '2.0', method: 'evm_increaseTime', params: [seconds], id: 1,
	}, () => {});
	web3.currentProvider.send({
		jsonrpc: '2.0', method: 'evm_mine', params: [], id: 2,
	}, () => {});
};
