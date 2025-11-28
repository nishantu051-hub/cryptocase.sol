// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title CryptoCase
 * @dev A secure digital asset escrow and case management system for freelance/crypto disputes
 * @author Grok
 */
contract CryptoCase {
    address public owner;

    enum CaseStatus { Created, Funded, InProgress, Resolved, Closed, Disputed }

    struct Case {
        uint256 caseId;
        address client;
        address freelancer;
        uint256 amount;
        string title;
        string description;
        CaseStatus status;
        uint256 createdAt;
        address arbitrator; // optional trusted arbitrator
    }

    mapping(uint256 => Case) public cases;
    uint256 public nextCaseId;

    // Escrow balance per case
    mapping(uint256 => uint256) public escrowBalance;

    event CaseCreated(uint256 indexed caseId, address indexed client, address indexed freelancer, uint256 amount);
    event FundsDeposited(uint256 indexed caseId, uint256 amount);
    event WorkStarted(uint256 indexed caseId);
    event CaseResolved(uint256 indexed caseId, address winner);
    event FundsReleased(uint256 indexed caseId, address indexed recipient, uint256 amount);

    modifier onlyClient(uint256 _caseId) {
        require(cases[_caseId].client == msg.sender, "Only client can call");
        _;
    }

    modifier onlyParticipants(uint256 _caseId) {
        require(
            msg.sender == cases[_caseId].client ||
            msg.sender == cases[_caseId].freelancer ||
            msg.sender == cases[_caseId].arbitrator,
            "Not authorized"
        );
        _;
    }

    constructor() {
        owner = msg.sender;
        nextCaseId = 1;
    }

    /**
     * @dev Client creates a new case and optionally deposits funds
     */
    function createCase(
        address _freelancer,
        string memory _title,
        string memory _description
    ) external payable returns (uint256) {
        require(_freelancer != address(0), "Invalid freelancer address");
        require(msg.value >= 0, "Amount can be zero for now");

        uint256 caseId = nextCaseId++;
        Case memory newCase = Case({
            caseId: caseId,
            client: msg.sender,
            freelancer: _freelancer,
            amount: msg.value,
            title: _title,
            description: _description,
            status: msg.value > 0 ? CaseStatus.Funded : CaseStatus.Created,
            createdAt: block.timestamp,
            arbitrator: address(0)
        });

        cases[caseId] = newCase;
        escrowBalance[caseId] = msg.value;

        emit CaseCreated(caseId, msg.sender, _freelancer, msg.value);
        if (msg.value > 0) emit FundsDeposited(caseId, msg.value);

        return caseId;
    }

    /**
     * @dev Client or third party deposits funds into an existing case escrow
     */
    function depositFunds(uint256 _caseId) external payable onlyParticipants(_caseId) {
        require(cases[_caseId].status == CaseStatus.Created || cases[_caseId].status == CaseStatus.Funded, "Case not accepting funds");
        escrowBalance[_caseId] += msg.value;
        cases[_caseId].amount += msg.value;

        emit FundsDeposited(_caseId, msg.value);
    }

    /**
     * @dev Freelancer marks work as started (optional milestone)
     */
    function startWork(uint256 _caseId) external {
        require(msg.sender == cases[_caseId].freelancer, "Only freelancer");
        require(cases[_caseId].status == CaseStatus.Funded, "Funds required first");

        cases[_caseId].status = CaseStatus.InProgress;
        emit WorkStarted(_caseId);
    }

    /**
     * @dev Client releases funds to freelancer when satisfied
     */
    function releaseFunds(uint256 _caseId) external onlyClient(_caseId) {
        require(cases[_caseId].status == CaseStatus.InProgress || cases[_caseId].status == CaseStatus.Funded, "Invalid status");

        uint256 amount = escrowBalance[_caseId];
        require(amount > 0, "No funds to release");

        escrowBalance[_caseId] = 0;
        cases[_caseId].status = CaseStatus.Resolved;

        payable(cases[_caseId].freelancer).transfer(amount);
        emit CaseResolved(_caseId, cases[_caseId].freelancer);
        emit FundsReleased(_caseId, cases[_caseId].freelancer, amount);
    }
}
