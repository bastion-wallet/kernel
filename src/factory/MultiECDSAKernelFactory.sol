// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "./KernelFactory.sol";
import "src/validator/MultiECDSAValidator.sol";
import "src/interfaces/IAddressBook.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MultiECDSAKernelFactory is IAddressBook, Ownable {
    KernelFactory public immutable singletonFactory;
    MultiECDSAValidator public immutable validator;
    IEntryPoint public immutable entryPoint;

    address[] public owners;
    uint8 public requiredSignatures = 2;
    uint8 public numSignatories;
    uint8 public numApprovals;

    mapping(address => bool) public isSignatory;
    mapping(address => bool) public approvals;

    constructor(KernelFactory _singletonFactory, MultiECDSAValidator _validator, IEntryPoint _entryPoint, address[] memory _initialOwners) {
        singletonFactory = _singletonFactory;
        validator = _validator;
        entryPoint = _entryPoint;
        
        for (uint8 i = 0; i < _initialOwners.length; i++) {
            owners.push(_initialOwners[i]);
            isSignatory[_initialOwners[i]] = true;
        }

        numSignatories = uint8(_initialOwners.length);
    }

    modifier onlySignatory() {
        require(isSignatory[msg.sender], "Not a signatory");
        _;
    }

    function addSignatory(address _signatory) external onlyOwner {
        require(!isSignatory[_signatory], "Already a signatory");
        isSignatory[_signatory] = true;
        numSignatories++;
    }

    function removeSignatory(address _signatory) external onlyOwner {
        require(isSignatory[_signatory], "Not a signatory");
        require(numSignatories > requiredSignatures, "Cannot remove the last signatory");
        isSignatory[_signatory] = false;
        numSignatories--;
    }

    function approveChange() external onlySignatory {
        require(approvals[msg.sender] == false, "Already approved");
        approvals[msg.sender] = true;
        numApprovals++;
    }

    function revokeApproval() external onlySignatory {
        require(approvals[msg.sender] == true, "Not approved");
        approvals[msg.sender] = false;
        numApprovals--;
    }

    /**
    * @dev Updates the owners of the contract. Requires complete array of new owners.
    * The entire array will be replaced with the provided one.
    * @param _owners Array of new owners
    */
    function setOwners(address[] calldata _owners) external onlySignatory {
        require(numApprovals >= requiredSignatures, "Insufficient approvals");
        for(uint8 i = 0; i < owners.length; i++){
            isSignatory[owners[i]] = false;
        }
        owners = _owners;
        numApprovals = 0;
        for (uint8 i = 0; i < owners.length; i++) {
            approvals[owners[i]] = false;
            isSignatory[owners[i]] = true;
        }
    }

    function getOwners() external view override returns(address[] memory) {
        return owners;
    }

    function createAccount(uint256 _index) external returns (EIP1967Proxy proxy) {
        bytes memory data = abi.encodePacked(address(this));
        proxy = singletonFactory.createAccount(validator, data, _index);
    }

    function getAccountAddress(uint256 _index) external view returns (address) {
        bytes memory data = abi.encodePacked(address(this));
        return singletonFactory.getAccountAddress(validator, data, _index);
    }

    /**
     * add a deposit for this factory, used for paying for transaction fees
     */
    function deposit() public payable {
        entryPoint.depositTo{value : msg.value}(address(this));
    }

    /**
     * withdraw value from the deposit
     * @param withdrawAddress target to send to
     * @param amount to withdraw
     */
    function withdrawTo(address payable withdrawAddress, uint256 amount) public onlyOwner {
        entryPoint.withdrawTo(withdrawAddress, amount);
    }
    /**
     * add stake for this factory.
     * This method can also carry eth value to add to the current stake.
     * @param unstakeDelaySec - the unstake delay for this factory. Can only be increased.
     */
    function addStake(uint32 unstakeDelaySec) external payable onlyOwner {
        entryPoint.addStake{value : msg.value}(unstakeDelaySec);
    }

    /**
     * return current factory's deposit on the entryPoint.
     */
    function getDeposit() public view returns (uint256) {
        return entryPoint.balanceOf(address(this));
    }

    /**
     * unlock the stake, in order to withdraw it.
     * The factory can't serve requests once unlocked, until it calls addStake again
     */
    function unlockStake() external onlyOwner {
        entryPoint.unlockStake();
    }

    /**
     * withdraw the entire factory's stake.
     * stake must be unlocked first (and then wait for the unstakeDelay to be over)
     * @param withdrawAddress the address to send withdrawn value.
     */
    function withdrawStake(address payable withdrawAddress) external onlyOwner {
        entryPoint.withdrawStake(withdrawAddress);
    }
}
