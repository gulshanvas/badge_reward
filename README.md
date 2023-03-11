## Badge Reward

### Contracts

1. **BadgeReward** <br/>
   a. It allows user to mint 3 badge NFTs. <br/>
   b.  Waiting period to claim badge NFT is dependent into which bucket the staked amount falls. It considers 3-buckets for the time being. <br/>
   c. Once user claims a badge which is less than 2, it reconfigues the time after which bagde NFT can be claimed again. <br/>
   d. If user entire withdraws LP tokens then it is not eligible to get badge. If partial amount is withdraw, NFT claim time is reset based on remaining amount. 
2. **Badge** <br/>
   a. Badge NFT can be deployed by deploying **Badge.sol** with 3 different metadata. <br/>
   b. It is **ERC721PresetMinterPauserAutoId** contract from OpenZeppelin.

### Compilation
1. Install dependencies by running command **npm i**
2. Run command **npm run compile** to compile contracts


