// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";

contract CrownsMarket is Ownable, ERC721Enumerable {
    string public standard = 'Crowns';
	string public baseTokenURI;

	uint8 private maxTitleLength;
	uint8 private maxTitles;

	uint256 private crownSharePct;
	uint256 private jokerSharePct;

	mapping (uint => string[]) public crownTitles;
	mapping (uint => uint256) public inscriptionThreshold;
	mapping (uint => uint256) public lastPrices;

    struct Offer {
        bool isForSale;
        uint crownIndex;
        address seller;
        uint minValue; 
        address onlySellTo;
    }

    struct Bid {
        bool hasBid;
        uint crownIndex;
        address bidder;
        uint value;
    }

    mapping (uint => Offer) public crownsOfferedForSale;
    mapping (uint => Bid) public crownBids;
    mapping (address => uint) public pendingWithdrawals;

    event Assign(address indexed to, uint crownIndex);
    event CrownTransfer(address indexed from, address indexed to, uint crownIndex);
    event CrownOffered(uint indexed crownIndex, uint minValue, address indexed toAddress);
    event CrownBidEntered(uint indexed crownIndex, uint value, address indexed fromAddress);
    event CrownBidWithdrawn(uint indexed crownIndex, uint value, address indexed fromAddress);
    event CrownBought(uint indexed crownIndex, uint value, address indexed fromAddress, address indexed toAddress);
    event CrownNoLongerForSale(uint indexed crownIndex);
	event InscriptionThresholdUpdate(uint indexed crownIndex, uint256 threshold);

    constructor() ERC721("Crowns", "C") {
		baseTokenURI = "";

		maxTitleLength = 50;
		maxTitles = 50;
		crownSharePct = 3;
		jokerSharePct = 1;

		crownTitles[0].push('King of Spades');
		crownTitles[1].push('King of Clubs');
		crownTitles[2].push('King of Diamonds');
		crownTitles[3].push('King of Hearts');
		crownTitles[4].push('Queen of Spades');
		crownTitles[5].push('Queen of Clubs');
		crownTitles[6].push('Queen of Diamonds');
		crownTitles[7].push('Queen of Hearts');
		crownTitles[8].push('Jack of Spades');
		crownTitles[9].push('Jack of Clubs');
		crownTitles[10].push('Jack of Diamonds');
		crownTitles[11].push('Jack of Hearts');

        uint256 threshold = 1000000000;
		setInitialInscriptionThreshold(threshold);
		for (uint i = 0; i < totalSupply(); i++) {
			_mint(owner(), i);
            crownsOfferedForSale[i] = Offer(false, i, owner(), 0, address(0));
        }
    }

    function setBaseURI(string memory baseURI) public onlyOwner {
        baseTokenURI = baseURI;
    }

	function setInitialInscriptionThreshold(uint256 threshold) private onlyOwner {
		for (uint i = 0; i < totalSupply(); i++) {
			inscriptionThreshold[i] = threshold;
			emit InscriptionThresholdUpdate(i, threshold);
		}
	}

    function offerCrownForSale(uint crownIndex, uint minSalePriceInWei) public {
        require(crownIndex < totalSupply(), "Invalid index");
        require(ownerOf(crownIndex) == msg.sender, "Not the holder");
        crownsOfferedForSale[crownIndex] = Offer(true, crownIndex, msg.sender, minSalePriceInWei, address(0));
        emit CrownOffered(crownIndex, minSalePriceInWei, address(0));
    }

    function offerCrownForSaleToAddress(uint crownIndex, uint minSalePriceInWei, address toAddress) public {
        require(crownIndex < totalSupply(), "Invalid index");
        require(ownerOf(crownIndex) == msg.sender, "Not the holder");
        crownsOfferedForSale[crownIndex] = Offer(true, crownIndex, msg.sender, minSalePriceInWei, toAddress);
        emit CrownOffered(crownIndex, minSalePriceInWei, toAddress);
    }

	function crownNoLongerForSale(uint crownIndex) public {
        require(crownIndex < totalSupply(), "Invalid index");
        require(ownerOf(crownIndex) == msg.sender, "Not the holder");
        crownsOfferedForSale[crownIndex] = Offer(false, crownIndex, msg.sender, 0, address(0));
        emit CrownNoLongerForSale(crownIndex);
    }

    // Add an inscripton. Inscription price doubles.
	function inscribe(uint crownIndex, string memory title) public {
        require(crownIndex < totalSupply(), "Invalid index");
        require(ownerOf(crownIndex) == msg.sender, "Not the holder");
		require(lastPrices[crownIndex] >= inscriptionThreshold[crownIndex], "Purchased price was too low");
		bytes memory bs = bytes(title);
		require(bs.length <= maxTitleLength, "Title too long");
		require(crownTitles[crownIndex].length < maxTitles, "Too many titles");
		crownTitles[crownIndex].push(title);
		while (inscriptionThreshold[crownIndex] <= lastPrices[crownIndex]) {
			inscriptionThreshold[crownIndex] *= 2;
		}
	}

    // Try to buy a crown. If the price offered is high enough the holder cannot refuse.
    function buyCrown(uint crownIndex) payable public {
        require(crownIndex < totalSupply(), "Invalid index");
        require(ownerOf(crownIndex) != msg.sender, "Not the holder");
        
        // If the price is higher than last purchase price and inscription price, holder cannot refuse.
        if (msg.value <= lastPrices[crownIndex] || msg.value < inscriptionThreshold[crownIndex]) {
            Offer memory offer = crownsOfferedForSale[crownIndex];
			require(offer.isForSale, "Not for sale");
			require(offer.onlySellTo == address(0) || offer.onlySellTo == msg.sender, "Not for sale to the sender");
			require(msg.value >= offer.minValue, "Too cheap");
			require(offer.seller == ownerOf(crownIndex), "Already sold");
        }

        address seller = ownerOf(crownIndex);

		uint crownType;
		if (crownIndex < 4) {
			crownType = 4;
		} else if (crownIndex < 8) {
			crownType = 8;
		} else {
			crownType = 12;
		}

		// Joker cut.
		uint jokerShare = msg.value * jokerSharePct / 100;
		pendingWithdrawals[owner()] += jokerShare;
		uint remaining = msg.value - jokerShare;
		
		// Crown cut.
		uint crownShare = msg.value * crownSharePct / 100;
		for (uint i = crownType - 4; i < crownType; i++) {
			pendingWithdrawals[ownerOf(i)] += crownShare;
			remaining -= crownShare;
		}
		pendingWithdrawals[seller] += remaining;

		lastPrices[crownIndex] = msg.value;

		_transfer(seller, msg.sender, crownIndex);

        crownNoLongerForSale(crownIndex);

        emit CrownBought(crownIndex, msg.value, seller, msg.sender);

        // Check for the case where there is a bid from the new owner and refund it.
        // Any other bid can stay in place.
        Bid memory bid = crownBids[crownIndex];
        if (bid.bidder == msg.sender) {
            // Kill bid and refund value
            pendingWithdrawals[msg.sender] += bid.value;
            crownBids[crownIndex] = Bid(false, crownIndex, address(0), 0);
        }
    }

    function withdraw() public {
        uint amount = pendingWithdrawals[msg.sender];
        // Remember to zero the pending refund before
        // sending to prevent re-entrancy attacks
        pendingWithdrawals[msg.sender] = 0;
		_withdraw(msg.sender, amount);
    }

	function _withdraw(address _address, uint256 _amount) private {
		(bool success, ) = _address.call{value: _amount}("");
		require(success, "Transfer failed.");
	}

    function enterBidForCrown(uint crownIndex) payable public {
        require(crownIndex < totalSupply(), "Invalid index");
        require(ownerOf(crownIndex) != msg.sender, "Holder can't bid");
		require(msg.value > 0, "Zero bid");
        Bid memory existing = crownBids[crownIndex];
		require(msg.value > existing.value, "Lower bid than existing");
        if (existing.value > 0) {
            // Refund the failing bid
            pendingWithdrawals[existing.bidder] += existing.value;
        }
        crownBids[crownIndex] = Bid(true, crownIndex, msg.sender, msg.value);
        emit CrownBidEntered(crownIndex, msg.value, msg.sender);
    }

    function acceptBidForCrown(uint crownIndex, uint minPrice) public {
        require(crownIndex < totalSupply(), "Invalid index");
        require(ownerOf(crownIndex) == msg.sender, "Not the holder");
        address seller = msg.sender;
        Bid memory bid = crownBids[crownIndex];
		require(bid.value > 0, "Zero bid");
		// In case the top bidder withdrew.
		require(bid.value >= minPrice, "Low bid");

		uint crownType;
		if (crownIndex < 4) {
			crownType = 4;
		} else if (crownIndex < 8) {
			crownType = 8;
		} else {
			crownType = 12;
		}

		// Joker cut.
		uint jokerShare = bid.value * jokerSharePct / 100;
		pendingWithdrawals[owner()] += jokerShare;
		uint remaining = bid.value - jokerShare;
		
		// Crown cut.
		uint crownShare = bid.value * crownSharePct / 100;
		for (uint i = crownType - 4; i < crownType; i++) {
			pendingWithdrawals[ownerOf(i)] += crownShare;
			remaining -= crownShare;
		}
		pendingWithdrawals[seller] += remaining;

		lastPrices[crownIndex] = bid.value;

		_transfer(seller, bid.bidder, crownIndex);

        crownsOfferedForSale[crownIndex] = Offer(false, crownIndex, bid.bidder, 0, address(0));

        crownBids[crownIndex] = Bid(false, crownIndex, address(0), 0);
        emit CrownBought(crownIndex, bid.value, seller, bid.bidder);
    }

    function withdrawBidForCrown(uint crownIndex) public {
        require(crownIndex < totalSupply(), "Invalid index");
        require(ownerOf(crownIndex) != msg.sender, "Holder can't bid");
        require(ownerOf(crownIndex) != address(0), "Unassigned crown");
        Bid memory bid = crownBids[crownIndex];
		require(bid.bidder == msg.sender, "Only bidder can withdraw bid");
        emit CrownBidWithdrawn(crownIndex, bid.value, msg.sender);
        uint amount = bid.value;
        crownBids[crownIndex] = Bid(false, crownIndex, address(0), 0);
        // Refund the bid money
		_withdraw(msg.sender, amount);
    }
}

