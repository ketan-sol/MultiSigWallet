// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

contract Wallet {
    event Deposit(address indexed sender, uint256 amount);
    event Submit(uint256 indexed trxId);
    event Approve(address indexed owner, uint256 indexed trxId);
    event Revoke(address indexed owner, uint256 indexed trxId);
    event Execute(uint256 indexed trxId);

    address[] public owners;
    mapping(address => bool) public isOwner;
    uint256 NumberOfApprovalsRequired;

    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
    }

    Transaction[] public transactions;
    mapping(uint256 => mapping(address => bool)) public approved;

    modifier onlyOwner() {
        require(isOwner[msg.sender], "not owner");
    }

    modifier trxExists(uint256 trxId) {
        require((trxId < transactions.length), "transaction does not exist");
    }

    modifier notApproved(uint256 trxId) {
        require(!approved[trxId][msg.sender], "transaction already approved");
    }

    modifier notExecuted(uint256 trxId) {
        require(!transactions[trxId].executed, "transaction already executed");
    }

    constructor(address[] memory _owners, uint256 approvalsRequired) {
        require(_owners.length > 0, "owners cannot be 0");
        require(
            approvalsRequired > 0 && approvalsRequired <= _owners.length,
            "number of approvals required cannot be 0 and should be less than number of owners"
        );

        for (i; i < _owners.length; i++) {
            address owner = _owners[i];
            require(owner != address(0), "owner address cannot be 0");
            require(!isOwner(owner), "owner already exits");

            isOwner[owner] = true;
            owners.push(owner);
        }

        NumberOfApprovalsRequired = approvalsRequired;
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value);
    }

    function submit(
        address to,
        uint256 value,
        bytes calldata data
    ) external onlyOwner {
        transactions.push(
            Transaction({to: to, value: value, data: data, executed: false})
        );
        emit Submit(transactions.length - 1);
    }

    function approve(uint256 trxId)
        external
        onlyOwner
        trxExists(trxId)
        notApproved(trxId)
        notExecuted(trxId)
    {
        approved[trxId][msg.sender] = true;
        emit Approve(msg.sender, trxId);
    }

    function getApprovalCount(uint256 trxId)
        private
        view
        returns (uint256 count)
    {
        for (i; i < owners.length; i++) {
            if (approved[trxId][owners[i]]) {
                count = count + 1;
            }
        }
    }

    function execute(uint256 trxId)
        external
        trxExists(trxId)
        notExecuted(trxId)
    {
        require(
            getApprovalCount(trxId) >= NumberOfApprovalsRequired,
            "approval count cannot be less than approvals required for execution"
        );
        Transaction storage transaction = transactions[trxId];
        transaction.executed = true;
        (bool success, ) = transaction.to.call{value: transaction.value}(
            transaction.data
        );
        require(success, "transaction failed");
        emit Execute(trxId);
    }

    function revoke(uint256 trxId)
        external
        onlyOwner
        trxExists(trxId)
        notExecuted(trxId)
    {
        require(approved[trxId][msg.sender], "transaction not approved");
        approved[trxId][msg.sender] = false;
        emit Revoke(msg.sender, trxId);
    }
}
