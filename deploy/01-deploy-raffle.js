const { network, ethers } = require("hardhat")
const { developmentChains, networkConfig } = require("../helper.hardhat.config")
const { verify } = require("../utils/verify")

const VRF_SUB_FUND_AMOUNT = ethers.utils.parseEther("30")

module.exports = async function ({ getNamedAccounts, deployments }) {
    const { deploy, log } = deployments
    const { deployer } = await getNamedAccounts()
    const chainId = network.config.chainId
    let vrfCoordinatorV2Address, subcriptionId

    if (developmentChains.includes(network.name)) {
        const vrfcoordinatorV2Mock = await ethers.getContract("VRFCoordinatorV2Mock")
        vrfCoordinatorV2Address = vrfcoordinatorV2Mock.address
        const transcationResponse = await vrfcoordinatorV2Mock.createSubscription()
        const transcationReceipt = await transcationResponse.wait(1)
        // event is emitted in the transactionReceipt with the subcriptionId. So, creating a variable above for the same.
        subcriptionId = transcationReceipt.events[0].args.subId
        // once you have the subscriptionId, we need to fund it.
        // Usually, you'd need the link token on a real network
        // the current iteration of the mock, allows you to fund it without the link token
        await vrfcoordinatorV2Mock.fundSubscription(subcriptionId, VRF_SUB_FUND_AMOUNT)
    } else {
        vrfCoordinatorV2Address = networkConfig[chainId]["vrfCoordinatorV2"]
        subcriptionId = networkConfig[chainId]["subscriptionId"]
    }

    const entranceFee = networkConfig[chainId]["entranceFee"]
    const gasLane = networkConfig[chainId]["gasLane"]
    // on development chains, it little difficult to create subscription.
    // but you can call createSubscription on a mock contract. Creating it above.
    const callbackGasLimit = networkConfig[chainId]["callbackGasLimit"]
    const interval = networkConfig[chainId]["interval"]

    const args = [
        vrfCoordinatorV2Address,
        entranceFee,
        gasLane,
        subcriptionId,
        callbackGasLimit,
        interval,
    ]

    const raffle = await deploy("Raffle", {
        from: deployer,
        args: args,
        log: true,
        waitConfirmations: network.config.blockConfirmations || 1,
    })

    if (!developmentChains.includes(network.name) && process.env.ETHERSCAN_API_KEY) {
        log("Verifying......")
        await verify(raffle.address, args)
    }

    log("---------------------------------------------------------------------------")
}

module.exports.tags = ["all", "raffle"]
