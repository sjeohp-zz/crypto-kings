var ConvertLib = artifacts.require("ConvertLib.sol");
var CrownsMarket = artifacts.require("CrownsMarket.sol");

module.exports = function(deployer) {
  deployer.deploy(ConvertLib);
  deployer.link(ConvertLib, CrownsMarket);
  deployer.deploy(CrownsMarket);
};
