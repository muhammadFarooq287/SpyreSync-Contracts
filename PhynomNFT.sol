// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts@4.7.2/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts@4.7.2/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts@4.7.2/access/Ownable.sol";

contract PhynomNFT is ERC721URIStorage,Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private idCounter;

    constructor() ERC721("PhynomNFT", "PNFT") {
    }

    function createToken(string memory tokenURI) public returns (uint) {
        idCounter.increment();
        uint256 newId = idCounter.current();

        _mint(msg.sender, newId);
        _setTokenURI(newId, tokenURI);
        return newId;
    }
}
