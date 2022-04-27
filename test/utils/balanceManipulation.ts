export const getBalances = async (web3: any, accounts: string[]) => {
	return await Promise.all(
		accounts.map(async (account) => web3.eth.getBalance(account))
	)
}
