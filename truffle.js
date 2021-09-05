

module.exports = {
  networks: {
    development: {
      host: "localhost",
      port: 7545,
      network_id: "*" // Match any network id
    },
  	ropsten: {
	  host: "127.0.0.1",
      port: 8545,
      network_id: 3,
      gas: 4700000
    }
  },
  compilers: {
    solc: {
      version: "0.8.0",
	  optimizer: {
		enabled: true,
		runs: 100,
	  }
    }
  }
};
