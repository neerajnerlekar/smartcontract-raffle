// completely automated lottery smart contract

// Thing it should do
// - enter the lottery with some amount
// - pick a verifiably random winner -> Chainlink Oracle -> VRFRandomness
// - select winner every X minutes -> Chainlink Keepers

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

error Raffle__NotEnoughEntryFee();

contract Raffle is VRFConsumerBaseV2 {
    /* State Variables */

    // using i_entranceFee to know that it's an immutable variable which will use less gas
    // creating a getter function at the end for public visibility
    uint256 private immutable i_entranceFee;
    address payable[] private s_players;

    /* Events */
    event RaffleEnter(address indexed player);

    // since Raffle is extension of VRFConsumerBaseV2, we pass the constructor of VRFConsumerBaseV2 next to the Raffle constructor
    // vrfCoordinatorV2 is the address that fulfills requestRandomness
    // passing vrfCoordinatorV2 address in Raffle constructor to set a contract address to pass it into VRFConsumerBaseV2
    constructor(address vrfCoordinatorV2, uint256 entranceFee) VRFConsumerBaseV2(vrfCoordinatorV2) {
        i_entranceFee = entranceFee;
    }

    function enterRaffle() public payable {
        // gas costly way -> require(msg.value > i_entranceFee, "Not enough ETH!")
        if (msg.value < i_entranceFee) {
            revert Raffle__NotEnoughEntryFee();
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

    function requestRandomWinner() external {}

    // Raffle is extension of VRFConsumerBaseV2, which takes 2 input parameters, your subscription requestId & the array of randomWords
    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords)
        internal
        override
    {}

    /* View / Pure Functions */

    function getEntranceFee() public view returns (uint256) {
        return i_entranceFee;
    }

    function getPlayer(uint256 player) public view returns (address) {
        return s_players[player];
    }
}
