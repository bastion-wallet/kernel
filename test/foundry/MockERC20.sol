pragma solidity ^0.8.0;
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {

    constructor() ERC20("Mock Token", "MTK") {}

    function mint(address account, uint256 amount) public {
        // require(msg.sender == owner(), "Only the owner can mint");
        _mint(account, amount);
    }
}
