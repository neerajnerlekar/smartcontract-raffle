// completely automated lottery smart contract

// Thing it should do
// - enter the lottery with some amount
// - pick a verifiably random winner -> Chainlink Oracle -> VRFRandomness
// - select winner every X minutes -> Chainlink Keepers

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";
import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/interfaces/KeeperCompatibleInterface.sol";

error Raffle__NotEnoughEntryFee();
error Raffle__TransferFailed();
error Raffle__NotOpen();
error Raffle__UpkeepNotNeeded(uint256 currentBalance, uint256 numPlayers, uint256 raffleState);

/** @title A working Raffle contract
 *  @author Neeraj Nerlekar. Mentor - Patrick Collins
 *  @notice This contract is for creating an untamperable decentralized raffle
 *  @dev This implements Chainlink VRF v2 and Chainlink Keepers
 */

contract Raffle is VRFConsumerBaseV2, KeeperCompatibleInterface {
    /* Type Variables */
    enum RaffleState {
        OPEN,
        CALCULATING
    }

    /* State Variables */

    // using i_entranceFee to know that it's an immutable variable which will use less gas
    // creating a getter function at the end for public visibility
    uint256 private immutable i_entranceFee;
    address payable[] private s_players;
    // this is of type VRFCoordinatorV2Interface and the variable name is i_vrfCoordinator
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    bytes32 private immutable i_gasLane;
    uint64 private immutable i_subscriptionId;
    // since we don't want to have the possibility of chain reorg, setting it as a constant 3 block confirmation
    // so not passing it as a parameter in the constructor
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private immutable i_callbackGasLimit;
    // since we want only one random number to be returned, making it a constant and not passing it in the constructor
    uint32 private constant NUM_WORDS = 1;

    /* Lottery Variables */
    address private s_recentWinner;
    // creating a variable of type RaffleState and initializing it in the construstor to "open" state
    RaffleState private s_raffleState;
    uint256 private s_lastTimeStamp;
    uint256 private immutable i_interval;

    /* Events */
    event RaffleEnter(address indexed player);
    event RequestedRaffleWinner(uint256 indexed requestId);
    event WinnerPicked(address indexed winner);

    // since Raffle is extension of VRFConsumerBaseV2, we pass the constructor of VRFConsumerBaseV2 next to the Raffle constructor
    // vrfCoordinatorV2 is the address that fulfills requestRandomness
    // passing vrfCoordinatorV2 address in Raffle constructor to set a contract address to pass it into VRFConsumerBaseV2

    /* Functions */
    constructor(
        address vrfCoordinatorV2,
        uint256 entranceFee,
        bytes32 gasLane,
        uint64 subscriptionId,
        uint32 callbackGasLimit,
        uint256 interval
    ) VRFConsumerBaseV2(vrfCoordinatorV2) {
        i_entranceFee = entranceFee;
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinatorV2);
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        s_raffleState = RaffleState.OPEN;
        s_lastTimeStamp = block.timestamp;
        i_interval = interval;
    }

    function enterRaffle() public payable {
        // gas costly way -> require(msg.value > i_entranceFee, "Not enough ETH!")
        if (msg.value < i_entranceFee) {
            revert Raffle__NotEnoughEntryFee();
        }
        // checking the condition 4 below to ensure the player can only enter in an "open" state
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__NotOpen();
        }
        s_players.push(payable(msg.sender));
        // emit an event when we update a dynamic array or mapping
        // naming syntax -> name events with the function name reversed
        emit RaffleEnter(msg.sender);
    }

    // implementing VRFRandomness. Also using chainlink keepers to call for a random number so that we can pick a winner automatically
    // Chainlink randomness happens in 2 steps so that no one can brute force the random number
    // So, splitting the function pickRandomWinner -> requestRandomWinner and fulfillRandomWords
    // function pickRandomWinner() external {}

    /**
     * @dev This is the function that Chainlink KEeper nodes call
     * they look for the `upkeepNeeded` to return true
     * The following conditions should be met for the upkeep to return true
     * 1. our time interval should have passed
     * 2. the lottery should have at least 1 player, and have ETH in the contract
     * 3. our subscription is funded with LINK
     * 4. the lottery should be in an "open" state
     */

    function checkUpkeep(
        bytes memory /* checkData */
    )
        public
        override
        returns (
            bool upkeepNeeded,
            bytes memory /* performData */
        )
    {
        bool isOpen = (RaffleState.OPEN == s_raffleState);
        bool timePassed = ((block.timestamp - s_lastTimeStamp) > i_interval);
        bool hasPlayers = (s_players.length > 0);
        bool hasBalance = address(this).balance > 0;
        upkeepNeeded = (isOpen && timePassed && hasPlayers && hasBalance);
    }

    // transforming the requestRandomWinner to performUpkeep function, since checkUpkeep is true, it will trigger the performUpkeep
    // function requestRandomWinner() external {
    function performUpkeep(
        bytes calldata /* performData */
    ) external override {
        // validation to know checkUpkeep was returned true, so that no one can randomly call performUpkeep
        (bool upkeepNeeded, ) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Raffle__UpkeepNotNeeded(
                address(this).balance,
                s_players.length,
                uint256(s_raffleState)
            );
        }
        // setting the state to calculating, so no players can enter in this time period
        s_raffleState = RaffleState.CALCULATING;
        // i_vrfCoordinator is our contract address variable for requestRandomness contract
        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane, // for us to use this keyHash -> storing it as a state variable gasLane and passing it in the constructor
            i_subscriptionId,
            REQUEST_CONFIRMATIONS,
            i_callbackGasLimit,
            NUM_WORDS
        );
        emit RequestedRaffleWinner(requestId);
    }

    // Raffle is extension of VRFConsumerBaseV2, which takes 2 input parameters, your subscription requestId & the array of randomWords
    function fulfillRandomWords(
        uint256, /* requestId */
        uint256[] memory randomWords
    ) internal override {
        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable recentWinner = s_players[indexOfWinner];
        s_recentWinner = recentWinner;
        s_raffleState = RaffleState.OPEN;
        // resetting the players array
        s_players = new address payable[](0);
        // resetting the timestamp
        s_lastTimeStamp = block.timestamp;
        (bool success, ) = recentWinner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle__TransferFailed();
        }
        // in order to keep track of list of previous winners, we will emit an event
        emit WinnerPicked(recentWinner);
    }

    /* View / Pure Functions */

    function getEntranceFee() public view returns (uint256) {
        return i_entranceFee;
    }

    function getPlayer(uint256 player) public view returns (address) {
        return s_players[player];
    }

    function getRecentWinner() public view returns (address) {
        return s_recentWinner;
    }

    function getRaffleState() public view returns (RaffleState) {
        return s_raffleState;
    }

    function getNumWords() public pure returns (uint256) {
        return NUM_WORDS;
    }

    function getNumberOfPlayers() public view returns (uint256) {
        return s_players.length;
    }

    function getLatestTimestamp() public view returns (uint256) {
        return s_lastTimeStamp;
    }

    function getRequestConfirmations() public pure returns (uint256) {
        return REQUEST_CONFIRMATIONS;
    }

    function getInterval() public view returns (uint256) {
        return i_interval;
    }
}
