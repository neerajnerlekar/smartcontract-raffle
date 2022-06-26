const { developmentChains } = require("../helper.hardhat.config")

const BASE_FEE = ethers.utils.parseEther("0.25") //premium to get a random number.
// In chainlink price_feed, we don't pay this premium because, other projects are sponsoring to pay the premium.
const GAS_PRICE_LINK = 1e9 // link per gas. Calculated base on the gas price of the chain.
// chainlink nodes pay the gas fees to give us randomness.

module.exports = async function ({ getNamedAccounts, deployments }) {
    const { deploy, log } = deployments
    const { deployer } = await getNamedAccounts()
    const chainId = network.config.chainId
    const args = [BASE_FEE, GAS_PRICE_LINK]

    if (developmentChains.includes(network.name)) {
        log("Local network detected! Deploying mocks....")
        // deploy a mock vrfcoordinator
        await deploy("VRFCoordinatorV2Mock", {
            from: deployer,
            log: true,
            args: args,
        })
        log("Mocks Deployed!")
        log("---------------------------------------------------------------------------")
    }
}

module.exports.tags = ["all", "mocks"]
