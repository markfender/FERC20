const path = require('path');
const envPath = path.join(__dirname, './.env');
require('dotenv').config({ path: envPath });

const HDWalletProvider = require("@truffle/hdwallet-provider");
const {
  INFURA_KEY,
  INFURA_KEY_KOVAN,
  MNEMONIC,
  ETHERSCAN_API_KEY,
  PRIVATE_KEY,
  PRIVATE_KEY_TESTNET,
  GANACHE_PRIVATE_KEY
} = process.env;

module.exports = {
  networks: {
    // Useful for testing. The `development` name is special - truffle uses it by default
    // if it's defined here and no other network is specified at the command line.
    // You should run a client (like ganache-cli, geth or parity) in a separate terminal
    // tab if you use this network and you must also set the `host`, `port` and `network_id`
    // options below to some value.
    //
    development: {
      host: "127.0.0.1",     // Localhost (default: none)
      port: 7545,            // Standard Ethereum port (default: none)
      chainId: 1337,
      network_id: "*",       // Any network (default: none)
      accounts: [GANACHE_PRIVATE_KEY]
    },
    rinkeby: {
      provider: () => new HDWalletProvider([PRIVATE_KEY_TESTNET], `wss://rinkeby.infura.io/ws/v3/${INFURA_KEY}`),
      network_id: 4,       // Ropsten's id
      gas: 10000000,        // Ropsten has a lower block limit than mainnet   // # of confs to wait between deployments. (default: 0)
      timeoutBlocks: 200,
      gasPrice: 20000000000,
      networkCheckTimeout: 1000000,  // # of blocks before a deployment times out  (minimum/default: 50)
      skipDryRun: true,
      websockets: true    
    },
    kovan: {//https://kovan.infura.io/v3/060ec0a9731741aca884f2cab7fbc681
      provider: () => new HDWalletProvider([PRIVATE_KEY_TESTNET], `wss://kovan.infura.io/ws/v3/${INFURA_KEY_KOVAN}`),
      network_id: 42,       // Ropsten's id
      gas: 10000000,        // Ropsten has a lower block limit than mainnet   // # of confs to wait between deployments. (default: 0)
      timeoutBlocks: 200,
      gasPrice: 20000000000,
      networkCheckTimeout: 1000000,  // # of blocks before a deployment times out  (minimum/default: 50)
      skipDryRun: true,
      websockets: true    
    }
  },
  compilers: {
    solc: {
      version: "0.8.10",    // Fetch exact version from solc-bin (default: truffle's version)
      // docker: true,        // Use "0.5.1" you've installed locally with docker (default: false)
      settings: {          // See the solidity docs for advice about optimization and evmVersion
        optimizer: {
          enabled: true,
          runs: 200
        }
      //  evmVersion: "byzantium"
      }
    }
  },
  plugins: [
    "truffle-plugin-verify",
    "solidity-coverage"
  ],
  api_keys: {
    etherscan: ETHERSCAN_API_KEY
  }
}
