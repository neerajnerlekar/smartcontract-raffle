// completely automated lottery smart contract

// Thing it should do
// - enter the lottery with some amount
// - pick a verifiably random winner -> Chainlink Oracle -> VRFRandomness
// - select winner every X minutes -> Chainlink Keepers

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

error Raffle__NotEnoughEntryFee();

contract Raffle {
    /* State Variables */
    uint256 private immutable i_entranceFee;
    address payable[] private s_players;

    constructor(uint256 entranceFee) {
        i_entranceFee = entranceFee;
    }

    function enterRaffle() public payable {
        if (msg.value < i_entranceFee) {
            revert Raffle__NotEnoughEntryFee();
        }
    }

    // function pickRandomWinner() {}

    function getEntranceFee() public view returns (uint256) {
        return i_entranceFee;
    }

    function getPlayer(uint256 player) public view returns (address) {
        return s_players[player];
    }
}
